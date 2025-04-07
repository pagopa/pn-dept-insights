terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "random_password" "db_svc_user_password" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "db_svc_user_secret" {
  name        = "${var.project_name}/${var.db_svc_user}-credentials"
  description = "Credentials for the ${var.db_svc_user} database user"
  tags        = merge(var.tags, { Name = "${var.project_name}-${var.db_svc_user}-secret" })
}

resource "aws_secretsmanager_secret_version" "db_svc_user_secret_value" {
  secret_id     = aws_secretsmanager_secret.db_svc_user_secret.id
  secret_string = jsonencode({
    username = var.db_svc_user
    password = random_password.db_svc_user_password.result
  })
}

resource "aws_db_subnet_group" "aurora_subnet_group" {
  name        = "${var.project_name}-aurora-subnet-group"
  description = "Aurora subnet group for ${var.project_name} project"
  subnet_ids  = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-subnet-group"
  })
}

resource "aws_rds_cluster_parameter_group" "aurora_cluster_parameter_group" {
  name        = "${var.project_name}-aurora-pg-cluster-params"
  family      = "aurora-postgresql14"
  description = "Aurora PostgreSQL cluster parameter group for ${var.project_name} project"

  parameter {
    name  = "log_statement"
    value = "none"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-pg-cluster-params"
  })
}

resource "aws_db_parameter_group" "aurora_db_parameter_group" {
  name        = "${var.project_name}-aurora-pg-instance-params"
  family      = "aurora-postgresql14"
  description = "Aurora PostgreSQL instance parameter group for ${var.project_name} project"

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "pg_stat_statements.track"
    value = "ALL"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-pg-instance-params"
  })
}

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier              = "${var.project_name}-aurora-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = "14.12"
  engine_mode                     = "provisioned"
  database_name                   = var.db_name
  master_username                 = var.db_username
  manage_master_user_password     = true

  db_subnet_group_name            = aws_db_subnet_group.aurora_subnet_group.name
  vpc_security_group_ids          = [var.postgres_sg_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_cluster_parameter_group.name

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
    seconds_until_auto_pause = var.seconds_until_auto_pause
  }

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : "${var.project_name}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  enable_http_endpoint = var.enable_http_endpoint

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-cluster"
  })

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier,
    ]
  }
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  count                 = var.instance_count
  identifier            = "${var.project_name}-aurora-instance-${count.index}"
  cluster_identifier    = aws_rds_cluster.aurora_cluster.id
  instance_class        = "db.serverless"
  engine                = "aurora-postgresql"
  engine_version        = "14.12"
  db_parameter_group_name = aws_db_parameter_group.aurora_db_parameter_group.name

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  publicly_accessible        = false

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.aurora_monitoring_role.arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-instance-${count.index}"
  })
}

resource "aws_cloudwatch_log_group" "aurora_logs" {
  name              = "/aws/rds/cluster/${aws_rds_cluster.aurora_cluster.id}/postgresql"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-logs"
  })
}

resource "aws_iam_role" "aurora_monitoring_role" {
  name = "${var.project_name}-aurora-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-monitoring-role"
  })
}

resource "aws_iam_role_policy_attachment" "aurora_monitoring_attachment" {
  role       = aws_iam_role.aurora_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_iam_role_policy" "aurora_cloudwatch_logs" {
  name   = "${var.project_name}-aurora-logs-policy"
  role   = aws_iam_role.aurora_monitoring_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
        ]
        Effect = "Allow"
        Resource = [
          "${aws_cloudwatch_log_group.aurora_logs.arn}:*",
        ]
      }
    ]
  })
}

resource "aws_s3_bucket" "metrics_bucket" {
  bucket = "${var.project_name}-metric-collector-${var.region}-${data.aws_caller_identity.current.account_id}-${var.bucket_suffix}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-metric-collector"
  })
}

resource "aws_s3_bucket_versioning" "metrics_bucket_versioning" {
  bucket = aws_s3_bucket.metrics_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "metrics_bucket_public_access" {
  bucket = aws_s3_bucket.metrics_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "metrics_bucket_encryption" {
  bucket = aws_s3_bucket.metrics_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
