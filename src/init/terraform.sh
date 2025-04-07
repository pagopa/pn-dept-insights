#!/bin/bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
}

# Get arguments
ACTION=$1
AWS_PROFILE=${2:-sandbox}  # Default to 'sandbox'

# Validate AWS profile
if [[ "$AWS_PROFILE" != "sandbox" && "$AWS_PROFILE" != "sso_pn-analytics" ]]; then
  echo "Error: Only sandbox or sso_pn-analytics profiles are supported"
  echo "You provided: $AWS_PROFILE"
  exit 1
fi

# Export AWS profile
export AWS_PROFILE
echo "Using AWS profile: ${AWS_PROFILE}"

# Check if backend exists before initializing with remote backend
check_backend_exists() {
  local bucket=$(grep "bucket" backend.tfvars 2>/dev/null | cut -d '=' -f2 | tr -d ' "' | tr -d "'")
  if [ -z "$bucket" ]; then
    return 1  # No bucket configured yet
  fi

  if aws s3api head-bucket --bucket "${bucket}" 2>/dev/null; then
    return 0  # Bucket exists
  else
    return 1  # Bucket doesn't exist
  fi
}

# Initialize terraform with appropriate backend based on bucket existence
initialize_terraform() {
  if check_backend_exists; then
    echo "Backend resources exist, initializing with remote backend"
    terraform init -reconfigure -backend-config="backend.tfvars"
  else
    echo "Backend resources don't exist yet, initializing with local backend"
    terraform init -backend=false
  fi
}

# Create backend.tfvars if needed
setup_backend_config() {
  local bucket_name=$(terraform output -raw s3_bucket_name 2>/dev/null)
  local table_name=$(terraform output -raw dynamodb_table_name 2>/dev/null)

  if [ -n "$bucket_name" ] && [ -n "$table_name" ]; then
    echo "Configuring backend.tfvars with bucket: $bucket_name and table: $table_name"
    cat > backend.tfvars << EOF
bucket         = "${bucket_name}"
key            = "init/terraform.tfstate"
region         = "eu-west-1"
dynamodb_table = "${table_name}"
encrypt        = true
EOF
    echo "Backend configuration created"
  else
    echo "Could not determine backend resources, skipping backend.tfvars creation"
  fi
}

# Execute action based on input
case $ACTION in
  init)
    echo "Initializing Terraform"
    initialize_terraform
    ;;
  plan)
    echo "Planning Terraform"
    initialize_terraform
    terraform plan -var-file="terraform.tfvars"
    ;;
  apply)
    echo "Applying Terraform"
    initialize_terraform
    terraform apply -var-file="terraform.tfvars"
    setup_backend_config
    ;;
  destroy)
    echo "Destroying Terraform"
    initialize_terraform
    terraform destroy -var-file="terraform.tfvars"
    ;;
  migrate-state)
    echo "Migrating state to remote backend"
    if check_backend_exists; then
      terraform init -migrate-state -backend-config="backend.tfvars"
    else
      echo "ERROR: Cannot migrate state - backend bucket does not exist!"
      echo "Run './terraform.sh apply' first to create the backend resources"
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 <action> [aws-profile]"
    echo "  action: init, plan, apply, destroy, migrate-state"
    echo "  aws-profile: optional AWS profile (default: sandbox)"
    exit 1
    ;;
esac

