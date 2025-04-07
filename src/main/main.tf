provider "aws" {
  region = var.region
}

terraform {
  required_version = "1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.81.0"
    }
  }
  backend "s3" {}
}

module "infra" {
  source = "./modules/infra"

  project_name    = var.project_name
  region          = var.region
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  create_jumpbox  = var.create_jumpbox
  tags            = var.tags
}

module "storage" {
  source = "./modules/storage"

  project_name            = var.project_name
  region                  = var.region
  vpc_id                  = module.infra.vpc_id
  private_subnet_ids      = module.infra.private_subnets
  postgres_sg_id          = module.infra.postgres_sg_id
  db_name                 = var.db_name
  db_username             = var.db_username
  db_svc_user             = var.db_svc_user
  min_capacity            = var.min_capacity
  max_capacity            = var.max_capacity
  seconds_until_auto_pause = var.seconds_until_auto_pause
  instance_count          = var.instance_count
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  log_retention_days      = var.log_retention_days_db
  bucket_suffix           = var.bucket_suffix
  tags                    = var.tags
}

module "service" {
  source = "./modules/service"

  project_name    = var.project_name
  region          = var.region

  # Networking & DB inputs
  private_subnet_ids    = module.infra.private_subnets
  security_group_id     = module.infra.lambda_sg_id
  db_svc_user_secret_arn = module.storage.db_svc_user_secret_arn
  db_cluster_arn        = module.storage.cluster_arn
  db_name               = module.storage.db_name

  # S3 bucket inputs
  metrics_bucket_name = module.storage.metrics_bucket_name
  metrics_bucket_arn  = module.storage.metrics_bucket_arn

  # Sync Lambda specific inputs
  sync_memory_size            = var.sync_memory_size
  sync_timeout                = var.sync_timeout
  sync_schedule_expression    = var.sync_schedule_expression
  sync_schedule_enabled       = var.sync_schedule_enabled
  sync_reserved_concurrency   = var.sync_reserved_concurrency
  api_key_secret_name         = var.api_key_secret_name
  api_key_secret_name_pattern = var.api_key_secret_name_pattern

  # Export Lambda specific inputs
  export_memory_size          = var.export_memory_size
  export_timeout              = var.export_timeout
  export_schedule_expression  = var.export_schedule_expression
  export_schedule_enabled     = var.export_schedule_enabled
  export_reserved_concurrency = var.export_reserved_concurrency

  # Common inputs
  log_level             = var.log_level
  log_retention_days    = var.log_retention_days_lambda
  weather_api_url       = var.weather_api_url # Placeholder

  tags = var.tags
}