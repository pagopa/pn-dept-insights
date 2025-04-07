#!/bin/bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT

}

calculate_hash() {
  local dir_path=$1
  if command -v sha256sum &>/dev/null; then

    find "$dir_path" -type f -print0 2>/dev/null | sort -z | xargs -0 sha256sum 2>/dev/null | awk '{print $1}' | sha256sum | cut -d' ' -f1
  else

    find "$dir_path" -type f -print0 2>/dev/null | sort -z | xargs -0 shasum -a 256 2>/dev/null | awk '{print $1}' | shasum -a 256 | cut -d' ' -f1
  fi
}

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <action> [aws-profile] [options]"
  echo "  action: init, plan, apply, destroy, output, etc."
  echo "  aws-profile: optional AWS profile (default: sandbox)"
  echo "  options: additional options to pass to Terraform"
  exit 1
fi

action=$1
shift

AWS_PROFILE="sandbox"
if [ "$#" -gt 0 ] && [[ ! "$1" == -* ]]; then
  AWS_PROFILE="$1"
  shift
fi

tf_options=$@

if [[ "$AWS_PROFILE" != "sandbox" && "$AWS_PROFILE" != "sso_pn-analytics" ]]; then
  echo "Error: Only sandbox or sso_pn-analytics profiles are supported"
  exit 1
fi

export AWS_PROFILE
echo "Using AWS profile: ${AWS_PROFILE}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKEND_VARS="$SCRIPT_DIR/backend.tfvars"
TERRAFORM_VARS="$SCRIPT_DIR/terraform.tfvars"

build_lambda_packages() {
  echo "Building Lambda packages"

  SRC_DIR="$(dirname "$SCRIPT_DIR")"
  LAMBDA_BASE_DIR="$SRC_DIR/lambda_functions"
  OUTPUT_DIR="$SCRIPT_DIR"

  if [ ! -d "$LAMBDA_BASE_DIR" ]; then
    echo "ERROR: Lambda functions directory not found: $LAMBDA_BASE_DIR"
    exit 1
  fi

  find "$LAMBDA_BASE_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r lambda_dir; do
    lambda_name=$(basename "$lambda_dir")
    echo "Processing Lambda function: $lambda_name"

    BUILD_DIR="$lambda_dir/build"
    OUTPUT_ZIP="$OUTPUT_DIR/${lambda_name}.zip"
    HASH_FILE="$lambda_dir/build/source_hash"

    if [ ! -d "$lambda_dir/src" ]; then
      echo "WARNING: Source directory not found in $lambda_dir, skipping Lambda build: $lambda_name"
      continue
    fi

    SOURCE_HASH=$(calculate_hash "$lambda_dir/src")

    if [ -f "$OUTPUT_ZIP" ] && [ -f "$HASH_FILE" ]; then
      SAVED_HASH=$(cat "$HASH_FILE")

      if [ "$SOURCE_HASH" = "$SAVED_HASH" ]; then
        echo "Lambda package for $lambda_name is up to date, skipping build"
        continue
      else
        echo "Source code changed for $lambda_name, rebuilding..."
      fi
    else
      echo "Package or hash file missing for $lambda_name, building..."
    fi

    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    cp -r "$lambda_dir/src"/* "$BUILD_DIR"

    if [ -f "$lambda_dir/requirements.txt" ]; then
      echo "Installing dependencies for $lambda_name..."
      pip install -r "$lambda_dir/requirements.txt" -t "$BUILD_DIR" --upgrade

      find "$BUILD_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
      find "$BUILD_DIR" -type f -name "*.pyc" -delete
      find "$BUILD_DIR" -type f -name "*.pyo" -delete
      find "$BUILD_DIR" -name "*.dist-info" -type d -exec rm -rf {} + 2>/dev/null || true
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then

      NEWEST_FILE=$(find "$lambda_dir/src" -type f -exec stat -f "%m %N" {} \; | sort -n | tail -1 | cut -f2- -d' ')
      TIMESTAMP=$(date -r "$(stat -f "%m" "$NEWEST_FILE")" "+%Y%m%d%H%M")
    else

      NEWEST_FILE=$(find "$lambda_dir/src" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d' ')
      TIMESTAMP=$(date -r "$NEWEST_FILE" "+%Y%m%d%H%M")
    fi

    echo "Creating deterministic ZIP package for $lambda_name..."

    find "$BUILD_DIR" -type f -exec chmod 644 {} \;
    find "$BUILD_DIR" -type d -exec chmod 755 {} \;

    if [[ "$OSTYPE" == "darwin"* ]]; then

      TOUCH_FORMAT="${TIMESTAMP:0:12}.00"
    else

      TOUCH_FORMAT="${TIMESTAMP:0:12}.00"
    fi

    find "$BUILD_DIR" -exec touch -t "$TOUCH_FORMAT" {} \; 2>/dev/null || \
      find "$BUILD_DIR" -exec touch -d "$(date -d "${TIMESTAMP:0:4}-${TIMESTAMP:4:2}-${TIMESTAMP:6:2} ${TIMESTAMP:8:2}:${TIMESTAMP:10:2}:00" '+%Y-%m-%d %H:%M:%S')" {} \; 2>/dev/null || \
      echo "WARNING: Could not set uniform timestamps on files"

    cd "$BUILD_DIR"
    rm -f "$OUTPUT_ZIP"

    find . -print | sort | zip -X -@ "$OUTPUT_ZIP"

    touch -t "$TOUCH_FORMAT" "$OUTPUT_ZIP" 2>/dev/null || \
      touch -d "$(date -d "${TIMESTAMP:0:4}-${TIMESTAMP:4:2}-${TIMESTAMP:6:2} ${TIMESTAMP:8:2}:${TIMESTAMP:10:2}:00" '+%Y-%m-%d %H:%M:%S')" "$OUTPUT_ZIP" 2>/dev/null || \
      echo "WARNING: Could not set timestamp on ZIP file"

    echo "$SOURCE_HASH" > "$HASH_FILE"

    echo "Lambda package created: $OUTPUT_ZIP"

    cd "$SCRIPT_DIR"
  done

  cd "$SCRIPT_DIR"
}

if [[ "$action" == "plan" || "$action" == "apply" ]]; then
  build_lambda_packages
fi

TF_FILES=$(ls -1 *.tf 2>/dev/null | wc -l)
if [ "$TF_FILES" -eq 0 ]; then
  echo "ERROR: No Terraform configuration files (*.tf) found in $SCRIPT_DIR"
  exit 1
fi

if [ "$action" == "output" ]; then

  terraform init -reconfigure -backend-config="$BACKEND_VARS" > /dev/null

  terraform output $tf_options
  exit 0
fi

if echo "init plan apply refresh import state taint destroy" | grep -w $action > /dev/null; then
  if [ $action = "init" ]; then
    terraform $action -backend-config="$BACKEND_VARS" $tf_options
  elif [ $action = "state" ] || [ $action = "taint" ]; then

    terraform init -reconfigure -backend-config="$BACKEND_VARS" > /dev/null
    terraform $action $tf_options
  else

    terraform init -reconfigure -backend-config="$BACKEND_VARS" > /dev/null
    terraform $action -var-file="$TERRAFORM_VARS" $tf_options
  fi
else
  echo "Action not allowed: $action"
  echo "Allowed actions: init, plan, apply, refresh, import, output, state, taint, destroy"
  exit 1
fi

