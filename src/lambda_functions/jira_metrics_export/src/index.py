import os
import logging
import boto3
from datetime import datetime
import json
import csv
import io

log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger = logging.getLogger()
logger.setLevel(getattr(logging, log_level))

def read_weather_data_from_db():
    try:
        rds_client = boto3.client('rds-data')
        cluster_arn = os.environ.get('DB_CLUSTER_ARN')
        secret_arn = os.environ.get('DB_SECRET_ARN')
        db_name = os.environ.get('DB_NAME', 'jirametrics')

        logger.info(f"DB_CLUSTER_ARN: {cluster_arn}")
        logger.info(f"DB_SECRET_ARN: {secret_arn}")

        if not cluster_arn or not secret_arn:
            logger.error("Missing DB_CLUSTER_ARN or DB_SECRET_ARN")
            return None

        sql = "SELECT city, temperature, humidity, pressure, wind_speed, description, timestamp FROM weather_data WHERE timestamp >= NOW() - INTERVAL '1 day' ORDER BY timestamp DESC;"

        logger.info(f"Executing SQL query on DB {db_name}: {sql}")
        response = rds_client.execute_statement(
            resourceArn=cluster_arn,
            secretArn=secret_arn,
            database=db_name,
            sql=sql,
            includeResultMetadata=True
        )

        records = response.get('records', [])
        column_metadata = response.get('columnMetadata', [])

        if not records or not column_metadata:
            logger.info("No records found in the database for export.")
            return None

        processed_records = []
        column_names = [meta['label'] for meta in column_metadata]

        for record in records:
            row = {}
            for i, col in enumerate(record):
                key = column_names[i]
                if 'stringValue' in col:
                    row[key] = col['stringValue']
                elif 'longValue' in col:
                    row[key] = col['longValue']
                elif 'doubleValue' in col:
                    row[key] = col['doubleValue']
                elif 'booleanValue' in col:
                    row[key] = col['booleanValue']
                elif 'isNull' in col and col['isNull']:
                    row[key] = None

            processed_records.append(row)

        logger.info(f"Successfully read {len(processed_records)} records from database.")
        return processed_records

    except Exception as e:
        logger.error(f"Error reading data from database: {str(e)}")
        return None

def write_to_s3(records_to_export):
    if not records_to_export:
        logger.info("No records provided to write to S3.")
        return False
    try:
        bucket_name = os.environ.get('S3_BUCKET_NAME')
        if not bucket_name:
            logger.error("S3_BUCKET_NAME environment variable not set")
            return False

        s3_client = boto3.client('s3')
        timestamp = datetime.now()
        date_part = timestamp.strftime("%Y-%m-%d")
        time_part = timestamp.strftime("%H-%M-%S")

        if not records_to_export:
             return False
        header = records_to_export[0].keys()

        csv_file = io.StringIO()

        csv_writer = csv.DictWriter(csv_file, fieldnames=header)
        csv_writer.writeheader()
        csv_writer.writerows(records_to_export)

        filename = f"weather-data-export/{date_part}/export-{time_part}.csv"

        s3_client.put_object(
            Bucket=bucket_name,
            Key=filename,
            Body=csv_file.getvalue(),
            ContentType='text/csv'
        )
        logger.info(f"Data CSV uploaded to s3://{bucket_name}/{filename}")
        return True
    except Exception as e:
        logger.error(f"Error writing to S3: {str(e)}")
        return False

def handler(event, context):
    logger.info("Export Lambda execution started")
    try:
        db_data = read_weather_data_from_db()

        if db_data is None:
            logger.warning("No data retrieved from database or error occurred during read.")

            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No data to export or error during DB read.'})
             }

        s3_success = write_to_s3(db_data)

        if s3_success:
            logger.info("Data successfully exported to S3")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': f'Data exported successfully to S3. Records processed: {len(db_data)}'})
            }
        else:
            logger.error("Failed to export data to S3")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Failed to export data to S3'})
            }
    except Exception as e:
        logger.error(f"Error executing Export Lambda: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

