data "aws_caller_identity" "current" {}

resource "aws_iam_role" "sync_lambda_role" {
  name = "${var.project_name}-sync-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = merge(var.tags, { Name = "${var.project_name}-sync-lambda-role" })
}

resource "aws_iam_policy" "lambda_vpc_policy" {
  name   = "${var.project_name}-lambda-vpc-policy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = ["ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface", "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses"], Resource = "*" }]
  })
}

resource "aws_iam_policy" "lambda_logging_policy" {
  name   = "${var.project_name}-lambda-logging-policy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup"], Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*" },
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-jira-metrics-sync:*", "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-jira-metrics-export:*"] }
    ]
  })
}

resource "aws_iam_policy" "db_secret_read_policy" {
  name        = "${var.project_name}-db-svc-user-secret-read-policy" 
  description = "Allow reading the DB service user secret (db_svc_user)"
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = ["secretsmanager:GetSecretValue"],
        Resource = [
          var.db_svc_user_secret_arn
         ]
      }
    ]
  })
}

resource "aws_iam_policy" "sync_lambda_policy" {
  name   = "${var.project_name}-sync-lambda-policy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = ["secretsmanager:GetSecretValue"],
        Resource = ["arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.api_key_secret_name_pattern}-*"] 
      },
      {
        Effect    = "Allow",
        Action    = ["rds-data:ExecuteStatement", "rds-data:BatchExecuteStatement", "rds-data:BeginTransaction", "rds-data:CommitTransaction", "rds-data:RollbackTransaction"],
        Resource = var.db_cluster_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sync_lambda_vpc" {
  role       = aws_iam_role.sync_lambda_role.name
  policy_arn = aws_iam_policy.lambda_vpc_policy.arn
}
resource "aws_iam_role_policy_attachment" "sync_lambda_logging" {
  role       = aws_iam_role.sync_lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}
resource "aws_iam_role_policy_attachment" "sync_lambda_specific" {
  role       = aws_iam_role.sync_lambda_role.name
  policy_arn = aws_iam_policy.sync_lambda_policy.arn
}
resource "aws_iam_role_policy_attachment" "sync_db_secret_read" {
  role       = aws_iam_role.sync_lambda_role.name
  policy_arn = aws_iam_policy.db_secret_read_policy.arn
}

resource "aws_iam_role" "export_lambda_role" {
  name = "${var.project_name}-export-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = merge(var.tags, { Name = "${var.project_name}-export-lambda-role" })
}

resource "aws_iam_policy" "export_lambda_policy" {
  name   = "${var.project_name}-export-lambda-policy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = ["rds-data:ExecuteStatement"],
        Resource = var.db_cluster_arn
      },
      {
        Effect    = "Allow",
        Action    = ["s3:PutObject"],
        Resource = "${var.metrics_bucket_arn}/*"
      },
      {
        Effect    = "Allow",
        Action    = ["s3:GetBucketLocation"],
        Resource = var.metrics_bucket_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "export_lambda_vpc" {
  role       = aws_iam_role.export_lambda_role.name
  policy_arn = aws_iam_policy.lambda_vpc_policy.arn
}
resource "aws_iam_role_policy_attachment" "export_lambda_logging" {
  role       = aws_iam_role.export_lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}
resource "aws_iam_role_policy_attachment" "export_lambda_specific" {
  role       = aws_iam_role.export_lambda_role.name
  policy_arn = aws_iam_policy.export_lambda_policy.arn
}
resource "aws_iam_role_policy_attachment" "export_db_secret_read" {
  role       = aws_iam_role.export_lambda_role.name
  policy_arn = aws_iam_policy.db_secret_read_policy.arn
}

resource "aws_cloudwatch_log_group" "sync_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-jira-metrics-sync"
  retention_in_days = var.log_retention_days
  tags              = merge(var.tags, { Name = "${var.project_name}-sync-lambda-logs" })
}
resource "aws_cloudwatch_log_group" "export_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-jira-metrics-export"
  retention_in_days = var.log_retention_days
  tags              = merge(var.tags, { Name = "${var.project_name}-export-lambda-logs" })
}

resource "aws_lambda_function" "jira_metrics_sync" {
  function_name    = "${var.project_name}-jira-metrics-sync"
  role             = aws_iam_role.sync_lambda_role.arn
  filename         = "${path.root}/jira_metrics_sync.zip"
  source_code_hash = filebase64sha256("${path.root}/jira_metrics_sync.zip")
  runtime          = "python3.9"
  handler          = "index.handler"
  timeout          = var.sync_timeout
  memory_size      = var.sync_memory_size
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.security_group_id]
  }
  environment {
    variables = {
      DB_CLUSTER_ARN         = var.db_cluster_arn
      DB_SECRET_ARN          = var.db_svc_user_secret_arn
      DB_NAME                = var.db_name
      LOG_LEVEL              = var.log_level
      WEATHER_API_URL        = var.weather_api_url
      WEATHER_API_KEY_SECRET = var.api_key_secret_name
    }
  }
  reserved_concurrent_executions = var.sync_reserved_concurrency
  tags = merge(var.tags, { Name = "${var.project_name}-jira-metrics-sync" })
  depends_on = [
    aws_cloudwatch_log_group.sync_lambda_logs,
    aws_iam_role_policy_attachment.sync_lambda_vpc,
    aws_iam_role_policy_attachment.sync_lambda_logging,
    aws_iam_role_policy_attachment.sync_lambda_specific,
    aws_iam_role_policy_attachment.sync_db_secret_read
  ]
}
resource "aws_lambda_function" "jira_metrics_export" {
  function_name    = "${var.project_name}-jira-metrics-export"
  role             = aws_iam_role.export_lambda_role.arn
  filename         = "${path.root}/jira_metrics_export.zip"
  source_code_hash = filebase64sha256("${path.root}/jira_metrics_export.zip")
  runtime          = "python3.9"
  handler          = "index.handler"
  timeout          = var.export_timeout
  memory_size      = var.export_memory_size
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.security_group_id]
  }
  environment {
    variables = {
      DB_CLUSTER_ARN = var.db_cluster_arn
      DB_SECRET_ARN  = var.db_svc_user_secret_arn
      DB_NAME        = var.db_name
      LOG_LEVEL      = var.log_level
      S3_BUCKET_NAME = var.metrics_bucket_name
    }
  }
  reserved_concurrent_executions = var.export_reserved_concurrency
  tags = merge(var.tags, { Name = "${var.project_name}-jira-metrics-export" })
  depends_on = [
    aws_cloudwatch_log_group.export_lambda_logs,
    aws_iam_role_policy_attachment.export_lambda_vpc,
    aws_iam_role_policy_attachment.export_lambda_logging,
    aws_iam_role_policy_attachment.export_lambda_specific,
    aws_iam_role_policy_attachment.export_db_secret_read
  ]
}

resource "aws_iam_role" "sync_scheduler_role" {
  name                 = "${var.project_name}-sync-scheduler-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "scheduler.amazonaws.com" } }] })
  tags                 = merge(var.tags, { Name = "${var.project_name}-sync-scheduler-role" })
}
resource "aws_iam_policy" "sync_scheduler_policy" {
  name   = "${var.project_name}-sync-scheduler-policy"
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Action = "lambda:InvokeFunction", Effect = "Allow", Resource = aws_lambda_function.jira_metrics_sync.arn }] })
}
resource "aws_iam_role_policy_attachment" "sync_scheduler_attachment" {
  role       = aws_iam_role.sync_scheduler_role.name
  policy_arn = aws_iam_policy.sync_scheduler_policy.arn
}
resource "aws_scheduler_schedule" "sync_schedule" {
  name                     = "${var.project_name}-jira-metrics-sync-schedule"
  group_name               = "default"
  schedule_expression      = var.sync_schedule_expression
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_lambda_function.jira_metrics_sync.arn
    role_arn = aws_iam_role.sync_scheduler_role.arn
  }
  state      = var.sync_schedule_enabled ? "ENABLED" : "DISABLED"
  depends_on = [aws_iam_role_policy_attachment.sync_scheduler_attachment]
}
resource "aws_iam_role" "export_scheduler_role" {
  name                 = "${var.project_name}-export-scheduler-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "scheduler.amazonaws.com" } }] })
  tags                 = merge(var.tags, { Name = "${var.project_name}-export-scheduler-role" })
}
resource "aws_iam_policy" "export_scheduler_policy" {
  name   = "${var.project_name}-export-scheduler-policy"
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Action = "lambda:InvokeFunction", Effect = "Allow", Resource = aws_lambda_function.jira_metrics_export.arn }] })
}
resource "aws_iam_role_policy_attachment" "export_scheduler_attachment" {
  role       = aws_iam_role.export_scheduler_role.name
  policy_arn = aws_iam_policy.export_scheduler_policy.arn
}
resource "aws_scheduler_schedule" "export_schedule" {
  name                     = "${var.project_name}-jira-metrics-export-schedule"
  group_name               = "default"
  schedule_expression      = var.export_schedule_expression
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_lambda_function.jira_metrics_export.arn
    role_arn = aws_iam_role.export_scheduler_role.arn
  }
  state      = var.export_schedule_enabled ? "ENABLED" : "DISABLED"
  depends_on = [aws_iam_role_policy_attachment.export_scheduler_attachment]
}