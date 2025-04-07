output "cluster_id" {
  description = "The ID of the Aurora cluster"
  value       = aws_rds_cluster.aurora_cluster.id
}

output "cluster_arn" {
  description = "The ARN of the Aurora cluster"
  value       = aws_rds_cluster.aurora_cluster.arn
}

output "cluster_endpoint" {
  description = "The writer endpoint of the Aurora cluster"
  value       = aws_rds_cluster.aurora_cluster.endpoint
}

output "cluster_reader_endpoint" {
  description = "The reader endpoint of the Aurora cluster"
  value       = aws_rds_cluster.aurora_cluster.reader_endpoint
}

output "cluster_port" {
  description = "The port of the Aurora cluster"
  value       = aws_rds_cluster.aurora_cluster.port
}

output "db_name" {
  description = "The database name"
  value       = aws_rds_cluster.aurora_cluster.database_name
}

output "db_username" {
  description = "The master username for the database"
  value       = aws_rds_cluster.aurora_cluster.master_username
}

output "db_secret_arn" {
  description = "The ARN of the secret containing master database credentials"
  value       = aws_rds_cluster.aurora_cluster.master_user_secret[0].secret_arn
}

output "db_instances" {
  description = "List of DB instance identifiers"
  value       = aws_rds_cluster_instance.aurora_instance[*].identifier
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.aurora_logs.name
}

output "metrics_bucket_name" {
  description = "Name of the S3 bucket for metrics storage"
  value       = aws_s3_bucket.metrics_bucket.bucket
}

output "metrics_bucket_arn" {
  description = "ARN of the S3 bucket for metrics storage"
  value       = aws_s3_bucket.metrics_bucket.arn
}

output "db_svc_user_secret_arn" {
  description = "ARN of the Secrets Manager secret for the database service user (db_svc_user)"
  value       = aws_secretsmanager_secret.db_svc_user_secret.arn
}