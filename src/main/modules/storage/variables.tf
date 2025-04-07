variable "project_name" {
  description = "Project name to use as prefix for all resources"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the database"
  type        = list(string)
}

variable "postgres_sg_id" {
  description = "Security group ID for PostgreSQL"
  type        = string
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

variable "min_capacity" {
  description = "Minimum capacity for Aurora Serverless v2 (in ACU - Aurora Capacity Units)"
  type        = number
  default     = 0
}

variable "max_capacity" {
  description = "Maximum capacity for Aurora Serverless v2 (in ACU - Aurora Capacity Units)"
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
  description = "Days to retain backups"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Daily time range during which backups happen"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Weekly time range during which maintenance can occur"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying the cluster"
  type        = bool
  default     = true
}

variable "enable_http_endpoint" {
  description = "Enable Data API for Aurora Serverless"
  type        = bool
  default     = true
}

variable "auto_minor_version_upgrade" {
  description = "Automatically apply minor engine upgrades during maintenance window"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "bucket_suffix" {
  description = "Suffix appended to the S3 bucket name for uniqueness"
  type        = string
  default     = "001"
}

variable "db_svc_user" {
  description = "Username for the database service account"
  type        = string
  default     = "db_svc_user"
}