import os
import logging
import boto3
import requests
from datetime import datetime
import json

log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger = logging.getLogger()
logger.setLevel(getattr(logging, log_level))

def get_secret(secret_name):
    try:
        logger.info(f"Attempting to retrieve secret: {secret_name}")
        secrets_client = boto3.client('secretsmanager')
        secret_response = secrets_client.get_secret_value(SecretId=secret_name)
        logger.info(f"Secret retrieved successfully: {secret_name}")
        if 'SecretString' in secret_response:
            return secret_response['SecretString']
        else:
            logger.error("Secret does not contain SecretString")
            return None
    except Exception as e:
        logger.error(f"Error retrieving secret {secret_name}: {str(e)}")
        return None

def get_weather_data():
    try:
        api_key_secret_name = os.environ.get('WEATHER_API_KEY_SECRET')
        logger.info(f"Secret name for API key: {api_key_secret_name}")

        if not api_key_secret_name:
            logger.error("WEATHER_API_KEY_SECRET is not set")
            api_key = "YOUR_API_KEY"
        else:
            secret_value = get_secret(api_key_secret_name)
            if not secret_value:
                logger.error(f"Unable to retrieve API key from secret: {api_key_secret_name}")
                api_key = "YOUR_API_KEY"
            else:
                try:
                    secret_data = json.loads(secret_value)
                    api_key = secret_data.get('api-key')
                    if not api_key:
                        logger.error("Key 'api-key' not found in secret JSON")
                        api_key = "YOUR_API_KEY"
                    else:
                        logger.info("API key retrieved successfully from secret")
                except json.JSONDecodeError:
                    api_key = secret_value.strip('"\'')
                    logger.info("API key retrieved as text value")

        api_url = os.environ.get('WEATHER_API_URL', 'https://api.openweathermap.org/data/2.5/weather')
        params = {
            'q': 'Rome,IT',
            'units': 'metric',
            'appid': api_key
        }
        logger.info(f"API call to: {api_url}")
        response = requests.get(api_url, params=params)
        logger.info(f"API response: status_code={response.status_code}")

        if response.status_code == 200:
            return response.json()
        else:
            logger.error(f"Error in API call: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        logger.error(f"Exception during API call: {str(e)}")
        return None

def store_weather_data(weather_data):
    if not weather_data:
        return False
    try:
        rds_client = boto3.client('rds-data')
        cluster_arn = os.environ.get('DB_CLUSTER_ARN')
        secret_arn = os.environ.get('DB_SECRET_ARN')
        db_name = os.environ.get('DB_NAME', 'jirametrics')

        logger.info(f"DB_CLUSTER_ARN: {cluster_arn}")
        logger.info(f"DB_SECRET_ARN: {secret_arn}")

        if not cluster_arn or not secret_arn:
            logger.error("Missing DB_CLUSTER_ARN or DB_SECRET_ARN")
            return False

        sql = """
        INSERT INTO weather_data (
            city, temperature, humidity, pressure, wind_speed,
            description, timestamp
        ) VALUES (:city, :temp, :humidity, :pressure, :wind, :desc, :ts::timestamp)
        ON CONFLICT (city, timestamp) DO NOTHING;
        """
        timestamp = datetime.now().isoformat()
        parameters = [
            {'name': 'city', 'value': {'stringValue': 'Rome'}},
            {'name': 'temp', 'value': {'doubleValue': weather_data['main']['temp']}},
            {'name': 'humidity', 'value': {'longValue': weather_data['main']['humidity']}},
            {'name': 'pressure', 'value': {'longValue': weather_data['main']['pressure']}},
            {'name': 'wind', 'value': {'doubleValue': weather_data['wind']['speed']}},
            {'name': 'desc', 'value': {'stringValue': weather_data['weather'][0]['description']}},
            {'name': 'ts', 'value': {'stringValue': timestamp}}
        ]

        logger.info(f"Executing SQL query on DB {db_name}: {sql}")
        response = rds_client.execute_statement(
            resourceArn=cluster_arn,
            secretArn=secret_arn,
            database=db_name,
            sql=sql,
            parameters=parameters
        )
        logger.info(f"Data insertion attempt completed, records updated: {response.get('numberOfRecordsUpdated', 0)}")
        return True
    except Exception as e:
        logger.error(f"Error inserting data into database: {str(e)}")
        return False

def handler(event, context):
    logger.info("Sync Lambda execution started")
    try:
        ext_data = get_weather_data()
        if not ext_data:
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Unable to retrieve external data'})
            }
        logger.info(f"External data retrieved: temp={ext_data['main']['temp']}°C, conditions={ext_data['weather'][0]['description']}")

        db_success = store_weather_data(ext_data)

        if db_success:
            logger.info("Data successfully saved to database")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Data synced successfully to database'})
            }
        else:
            logger.error("Failed to save data to database")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Failed to save data to database'})
            }
    except Exception as e:
        logger.error(f"Error executing Sync Lambda: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
