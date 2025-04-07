#!/bin/bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT

}

show_help() {
    echo "Usage: $0 [options]"
    echo "Creates a secure tunnel via SSM to connect to the Aurora database."
    echo ""
    echo "Options:"
    echo "  -p, --profile PROFILE        Specifies the AWS profile (default: sandbox)"
    echo "  -r, --region REGION          Specifies the AWS region (default: eu-west-1)"
    echo "  -l, --local-port PORT        Specifies the local port (default: 5432)"
    echo "  -c, --credentials            Shows database credentials (master and application user)"
    echo "  -h, --help                   Shows this help message"
    echo ""
    echo "Example: $0 --local-port 5433 -c"
}

AWS_PROFILE="sandbox"
REGION="eu-west-1"
LOCAL_PORT="5432"
SHOW_CREDENTIALS=false

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -p|--profile)
            AWS_PROFILE="$2"
            shift 2 ;;
        -r|--region)
            REGION="$2"
            shift 2 ;;
        -l|--local-port)
            LOCAL_PORT="$2"
            shift 2 ;;
        -c|--credentials)
            SHOW_CREDENTIALS=true
            shift ;;
        -h|--help)
            show_help
            exit 0 ;;
        *)
            echo "Unrecognized option: $1"; show_help; exit 1 ;;
    esac
done

export AWS_PROFILE
echo "Using AWS profile: ${AWS_PROFILE}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Getting infrastructure information from Terraform state..."
cd "$PROJECT_ROOT/src/main" || exit 1

TF_OUTPUT_JSON=$(./terraform.sh output -json | sed -n '/^{/,$p')
cd "$SCRIPT_DIR" || exit 1

JUMPBOX_ID=$(echo "$TF_OUTPUT_JSON" | jq -r '.jumpbox_id.value // empty')
DB_MASTER_SECRET_ARN=$(echo "$TF_OUTPUT_JSON" | jq -r '.db_secret_arn.value // empty')
DB_APP_USER_SECRET_ARN=$(echo "$TF_OUTPUT_JSON" | jq -r '.db_svc_user_secret_arn.value // empty')
DB_ENDPOINT=$(echo "$TF_OUTPUT_JSON" | jq -r '.db_cluster_endpoint.value // empty')
DB_NAME=$(echo "$TF_OUTPUT_JSON" | jq -r '.db_name.value // empty')

if [ -z "$JUMPBOX_ID" ] || [ "$JUMPBOX_ID" == "null" ]; then
    echo "ERROR: Jumpbox ID not found in Terraform output."
    echo "Verify the infrastructure or run 'terraform apply' in 'src/main'."
    exit 1
fi
if [ -z "$DB_ENDPOINT" ] || [ "$DB_ENDPOINT" == "null" ] || [ -z "$DB_NAME" ] || [ "$DB_NAME" == "null" ]; then
     echo "ERROR: Database endpoint or name not found in Terraform output."
     exit 1
fi
if { [ -z "$DB_MASTER_SECRET_ARN" ] || [ "$DB_MASTER_SECRET_ARN" == "null" ]; } && { [ -z "$DB_APP_USER_SECRET_ARN" ] || [ "$DB_APP_USER_SECRET_ARN" == "null" ]; }; then
    echo "ERROR: Database secret ARNs not found in Terraform output."
    exit 1
fi


echo "=== Database connection information ==="
echo "- Jumpbox ID: $JUMPBOX_ID"
echo "- DB Endpoint: $DB_ENDPOINT"
echo "- DB Name: $DB_NAME"
echo "- Local port for tunnel: $LOCAL_PORT"

if [ "$SHOW_CREDENTIALS" = true ]; then
    echo ""
    echo "Retrieving database credentials..."
    echo "--- Master User Credentials ---"
    if [ -n "$DB_MASTER_SECRET_ARN" ] && [ "$DB_MASTER_SECRET_ARN" != "null" ]; then
        DB_MASTER_SECRET=$(aws secretsmanager get-secret-value --secret-id "$DB_MASTER_SECRET_ARN" --region "$REGION" --query SecretString --output text 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$DB_MASTER_SECRET" ]; then
            DB_MASTER_USERNAME=$(echo "$DB_MASTER_SECRET" | jq -r '.username // empty')
            DB_MASTER_PASSWORD=$(echo "$DB_MASTER_SECRET" | jq -r '.password // empty')
            echo "- Username: $DB_MASTER_USERNAME"
            echo "- Password: $DB_MASTER_PASSWORD"
        else
            echo "WARN: Could not retrieve or parse master secret from $DB_MASTER_SECRET_ARN"
        fi
    else
        echo "INFO: Master Secret ARN not found in Terraform output."
    fi

    echo ""
    echo "--- Application User Credentials (db_svc_user) ---"
     if [ -n "$DB_APP_USER_SECRET_ARN" ] && [ "$DB_APP_USER_SECRET_ARN" != "null" ]; then
        DB_APP_SECRET=$(aws secretsmanager get-secret-value --secret-id "$DB_APP_USER_SECRET_ARN" --region "$REGION" --query SecretString --output text 2>/dev/null)
         if [ $? -eq 0 ] && [ -n "$DB_APP_SECRET" ]; then
            DB_APP_USERNAME=$(echo "$DB_APP_SECRET" | jq -r '.username // "N/A"')
            DB_APP_PASSWORD=$(echo "$DB_APP_SECRET" | jq -r '.password // "N/A - Failed to parse password from secret"')
            echo "- Username: $DB_APP_USERNAME"
            echo "- Password: $DB_APP_PASSWORD"
            if [[ "$DB_APP_PASSWORD" == "N/A"* ]]; then
                 echo "  (Check the JSON structure and value in secret $DB_APP_USER_SECRET_ARN)"
            fi
        else
            echo "WARN: Could not retrieve or parse application user secret from $DB_APP_USER_SECRET_ARN"
            echo "      (Secret might be empty or does not contain expected JSON with 'username' and 'password')"
        fi
    else
        echo "INFO: Application User Secret ARN not found in Terraform output."
        echo "      (Run 'terraform apply' in 'src/main' to create the secret resource)"
    fi

    echo ""
    echo "=== Connection string for DBeaver/psql (use appropriate credentials) ==="
    echo "jdbc:postgresql://localhost:$LOCAL_PORT/$DB_NAME"
    echo "psql -h localhost -p $LOCAL_PORT -U <username> -d $DB_NAME"

fi

echo ""
echo "=== Connection instructions ==="
echo "1. A secure tunnel will be created to local port $LOCAL_PORT."
echo "2. Configure your SQL client (DBeaver, psql, etc.) with:"
echo "   - Host: localhost"
echo "   - Port: $LOCAL_PORT"
echo "   - Database: $DB_NAME"
echo "   - Username/Password: Use the master or application credentials shown above (with -c)."
echo "3. If application user (db_svc_user) doesn't exist or has wrong password in DB:"
echo "   a. Run this script with -c to get the password stored in Secrets Manager."
echo "   b. Connect to DB using MASTER credentials."
echo "   c. Edit 'scripts/create_app_user.sql', replace the placeholder with the correct password."
echo "   d. Run 'scripts/create_app_user.sql'."
echo "4. Press Ctrl+C in this terminal to close the tunnel when finished."
echo ""
echo "=== Starting SSM Tunnel (Press Ctrl+C to stop) ==="
echo "Creating tunnel to database $DB_ENDPOINT through instance $JUMPBOX_ID..."

aws ssm start-session \
    --target "$JUMPBOX_ID" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$DB_ENDPOINT\"],\"portNumber\":[\"5432\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
    --region "$REGION"

echo "Tunnel closed."