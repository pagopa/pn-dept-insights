project_name = "pn-dept-insights"
region       = "eu-west-1"

vpc_cidr        = "10.0.0.0/16"
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
create_jumpbox  = true

db_name                 = "jirametrics"
db_username             = "dbadmin"
min_capacity            = 0
max_capacity            = 1.0
seconds_until_auto_pause = 300
instance_count          = 1
backup_retention_period = 7
skip_final_snapshot     = false
log_retention_days_db   = 30 

bucket_suffix = "001"

# Sync Lambda configuration
sync_memory_size            = 256
sync_timeout                = 60
sync_schedule_expression    = "cron(0 * * * ? *)"
sync_schedule_enabled       = true
sync_reserved_concurrency   = -1
api_key_secret_name         = "/pn-dept-insights/openweathermap/api-key" # Placeholder - CHANGE TO JIRA SECRET NAME
api_key_secret_name_pattern = "/pn-dept-insights/openweathermap/api-key" # Placeholder - CHANGE TO JIRA SECRET NAME PATTERN
weather_api_url             = "https://api.openweathermap.org/data/2.5/weather" # Placeholder - CHANGE TO JIRA API URL


# Export Lambda configuration
export_memory_size          = 256
export_timeout              = 120
export_schedule_expression  = "cron(0 2 * * ? *)" # Daily at 2 AM UTC
export_schedule_enabled     = true
export_reserved_concurrency = -1

# Common Lambda configuration
log_level                 = "INFO"
log_retention_days_lambda = 14 

# Common tags for all resources
tags = {
  "Project"    = "pn-dept-insights"
  "CostCenter" = "ts-640"
  "CreatedBy"  = "Terraform"
  "Owner"      = "PagoPA"
}