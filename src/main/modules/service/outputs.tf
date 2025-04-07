# Outputs for SYNC Lambda
output "sync_function_name" {
  description = "Sync Lambda function name"
  value       = aws_lambda_function.jira_metrics_sync.function_name
}
output "sync_function_arn" {
  description = "Sync Lambda function ARN"
  value       = aws_lambda_function.jira_metrics_sync.arn
}
output "sync_role_arn" {
  description = "Sync Lambda IAM role ARN"
  value       = aws_iam_role.sync_lambda_role.arn
}
output "sync_cloudwatch_log_group" {
  description = "Sync Lambda CloudWatch log group name"
  value       = aws_cloudwatch_log_group.sync_lambda_logs.name
}
output "sync_scheduler_schedule_arn" {
  description = "Sync Lambda EventBridge Scheduler schedule ARN"
  value       = aws_scheduler_schedule.sync_schedule.arn
}

# Outputs for EXPORT Lambda
output "export_function_name" {
  description = "Export Lambda function name"
  value       = aws_lambda_function.jira_metrics_export.function_name
}
output "export_function_arn" {
  description = "Export Lambda function ARN"
  value       = aws_lambda_function.jira_metrics_export.arn
}
output "export_role_arn" {
  description = "Export Lambda IAM role ARN"
  value       = aws_iam_role.export_lambda_role.arn
}
output "export_cloudwatch_log_group" {
  description = "Export Lambda CloudWatch log group name"
  value       = aws_cloudwatch_log_group.export_lambda_logs.name
}
output "export_scheduler_schedule_arn" {
  description = "Export Lambda EventBridge Scheduler schedule ARN"
  value       = aws_scheduler_schedule.export_schedule.arn
}

output "sync_lambda_invoke_url" {
  description = "URL for manual Sync Lambda invocation (AWS Lambda Console)"
  value       = "https://${var.region}.console.aws.amazon.com/lambda/home?region=${var.region}#/functions/${aws_lambda_function.jira_metrics_sync.function_name}?tab=testing"
}
output "export_lambda_invoke_url" {
  description = "URL for manual Export Lambda invocation (AWS Lambda Console)"
  value       = "https://${var.region}.console.aws.amazon.com/lambda/home?region=${var.region}#/functions/${aws_lambda_function.jira_metrics_export.function_name}?tab=testing"
}


