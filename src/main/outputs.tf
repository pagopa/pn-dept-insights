# Networking outputs
output "vpc_id" {
  description = "The VPC ID"
  value       = module.infra.vpc_id
}
output "vpc_cidr" {
  description = "The VPC CIDR block"
  value       = module.infra.vpc_cidr_block
}
output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.infra.public_subnets
}
output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.infra.private_subnets
}
output "jumpbox_private_ip" {
  description = "Private IP of the jumpbox instance, if created"
  value       = module.infra.jumpbox_private_ip
}
output "jumpbox_id" {
  description = "ID of the jumpbox instance, if created"
  value       = module.infra.jumpbox_id
}

# Database outputs
output "db_cluster_endpoint" {
  description = "The Aurora cluster endpoint"
  value       = module.storage.cluster_endpoint
}
output "db_reader_endpoint" {
  description = "The Aurora cluster reader endpoint"
  value       = module.storage.cluster_reader_endpoint
}
output "db_name" {
  description = "Database name"
  value       = module.storage.db_name
}
output "db_secret_arn" {
  description = "ARN of the secret containing database credentials"
  value       = module.storage.db_secret_arn
  sensitive   = true
}

output "db_svc_user_secret_arn" {
  description = "ARN of the Secrets Manager secret for the database service user (db_svc_user)"
  value       = module.storage.db_svc_user_secret_arn
  sensitive   = true
}

# S3 bucket outputs
output "metrics_bucket_name" {
  description = "Name of the S3 bucket for metrics storage"
  value       = module.storage.metrics_bucket_name
}
output "metrics_bucket_arn" {
  description = "ARN of the S3 bucket for metrics storage"
  value       = module.storage.metrics_bucket_arn
}

# Sync Lambda outputs
output "sync_lambda_function_name" {
  description = "Sync Lambda function name"
  value       = module.service.sync_function_name
}
output "sync_lambda_invoke_url" {
  description = "URL for manual Sync Lambda invocation"
  value       = module.service.sync_lambda_invoke_url
}
output "sync_lambda_log_group" {
  description = "CloudWatch log group name for the Sync service"
  value       = module.service.sync_cloudwatch_log_group
}
output "sync_scheduler_schedule_arn" {
  description = "ARN of the Sync EventBridge Scheduler schedule"
  value       = module.service.sync_scheduler_schedule_arn
}

# Export Lambda outputs
output "export_lambda_function_name" {
  description = "Export Lambda function name"
  value       = module.service.export_function_name
}
output "export_lambda_invoke_url" {
  description = "URL for manual Export Lambda invocation"
  value       = module.service.export_lambda_invoke_url
}
output "export_lambda_log_group" {
  description = "CloudWatch log group name for the Export service"
  value       = module.service.export_cloudwatch_log_group
}
output "export_scheduler_schedule_arn" {
  description = "ARN of the Export EventBridge Scheduler schedule"
  value       = module.service.export_scheduler_schedule_arn
}

