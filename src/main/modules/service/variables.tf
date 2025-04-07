variable "project_name" {
  description = "Project name to use as prefix for all resources"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "private_subnet_ids" {
  description = "IDs of private subnets where Lambda will be executed"
  type        = list(string)
}

variable "security_group_id" {
  description = "ID of the security group for Lambda"
  type        = string
}

variable "db_svc_user_secret_arn" {
  description = "ARN of the Secrets Manager secret for database service user credentials (db_svc_user)"
  type        = string
  sensitive   = true
}

variable "db_cluster_arn" {
  description = "ARN of the Aurora RDS cluster for Data API access"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "jirametrics"
}

variable "sync_memory_size" {
  description = "Memory for Sync Lambda in MB"
  type        = number
  default     = 128
}
variable "sync_timeout" {
  description = "Timeout for Sync Lambda in seconds"
  type        = number
  default     = 60
}
variable "sync_schedule_expression" {
  description = "Cron expression for Sync Lambda scheduling"
  type        = string
  default     = "cron(0 * * * ? *)"
}
variable "sync_schedule_enabled" {
  description = "Enable or disable Sync scheduling"
  type        = bool
  default     = true
}
variable "sync_reserved_concurrency" {
  description = "Reserved concurrency for Sync Lambda"
  type        = number
  default     = -1
}

variable "export_memory_size" {
  description = "Memory for Export Lambda in MB"
  type        = number
  default     = 128
}
variable "export_timeout" {
  description = "Timeout for Export Lambda in seconds"
  type        = number
  default     = 60
}
variable "export_schedule_expression" {
  description = "Cron expression for Export Lambda scheduling"
  type        = string
  default     = "cron(0 2 * * ? *)"
}
variable "export_schedule_enabled" {
  description = "Enable or disable Export scheduling"
  type        = bool
  default     = true
}
variable "export_reserved_concurrency" {
  description = "Reserved concurrency for Export Lambda"
  type        = number
  default     = -1
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
}
variable "log_level" {
  description = "Log level (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"
}
variable "weather_api_url" {
  description = "URL of the weather API (placeholder for Jira API)"
  type        = string
  default     = "https://api.openweathermap.org/data/2.5/weather"
}
variable "api_key_secret_name" {
  description = "Name of the secret holding the external API key (placeholder for Jira key)"
  type        = string
  default     = "openweathermap/api-key"
}
variable "api_key_secret_name_pattern" {
  description = "Pattern for the API key secret name used in IAM policy"
  type        = string
  default     = "openweathermap/api-key"
}
variable "metrics_bucket_name" {
  description = "Name of the S3 bucket provided by the storage module"
  type        = string
}
variable "metrics_bucket_arn" {
  description = "ARN of the S3 bucket provided by the storage module"
  type        = string
}
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}