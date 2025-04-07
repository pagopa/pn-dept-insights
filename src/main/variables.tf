variable "project_name" {
  description = "Project name to use as prefix for all resources"
  type        = string
  default     = "pn-dept-insights"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}
variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}
variable "create_jumpbox" {
  description = "Flag to enable/disable jumpbox instance creation"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Name of the database to create"
  type        = string
  default     = "jirametrics"
}
variable "db_username" {
  description = "Username for the database"
  type        = string
  default     = "dbadmin"
}
variable "db_svc_user" {
  description = "Username for the database service account"
  type        = string
  default     = "db_svc_user"
}
variable "min_capacity" {
  description = "Minimum capacity for Aurora Serverless v2 (in ACU)"
  type        = number
  default     = 0
}
variable "max_capacity" {
  description = "Maximum capacity for Aurora Serverless v2 (in ACU)"
  type        = number
  default     = 1.0
}
variable "seconds_until_auto_pause" {
  description = "Number of seconds to wait before automatically pausing the Aurora Serverless v2 instance"
  type        = number
  default     = 300
}
variable "instance_count" {
  description = "Number of DB instances in the cluster"
  type        = number
  default     = 1
}
variable "backup_retention_period" {
  description = "Days to retain DB backups"
  type        = number
  default     = 7
}
variable "skip_final_snapshot" {
  description = "Skip final DB snapshot when destroying the cluster"
  type        = bool
  default     = false
}
variable "log_retention_days_db" {
  description = "Number of days to retain DB CloudWatch logs"
  type        = number
  default     = 30
}

variable "bucket_suffix" {
  description = "Suffix for the S3 metrics bucket name"
  type        = string
  default     = "001"
}

variable "sync_memory_size" {
  description = "Memory for Sync Lambda in MB"
  type        = number
  default     = 256
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
variable "api_key_secret_name" {
  description = "Name of the secret holding the external API key (e.g., openweathermap/api-key or jira/api-token)"
  type        = string
  default     = "openweathermap/api-key"
}
variable "api_key_secret_name_pattern" {
  description = "Pattern for the API key secret name used in IAM policy (e.g., openweathermap/api-key or jira/api-token)"
  type        = string
  default     = "openweathermap/api-key"
}
variable "weather_api_url" {
  description = "URL of the external API to call (placeholder for Jira API)"
  type        = string
  default     = "https://api.openweathermap.org/data/2.5/weather"
}

variable "export_memory_size" {
  description = "Memory for Export Lambda in MB"
  type        = number
  default     = 256
}
variable "export_timeout" {
  description = "Timeout for Export Lambda in seconds"
  type        = number
  default     = 120
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

variable "log_level" {
  description = "Log level for Lambda functions (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"
}
variable "log_retention_days_lambda" {
  description = "Number of days to retain Lambda CloudWatch logs"
  type        = number
  default     = 14
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {
    "Project"    = "pn-dept-insights"
    "CostCenter" = "ts-640"
    "CreatedBy"  = "Terraform"
    "Owner"      = "PagoPA"
  }
}