data "aws_region" "current" {}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-monitoring-role"
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Random password for RDS
resource "random_password" "db_password" {
  length  = 32
  special = true
  # Avoid characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# DB Subnet Group (RDS requires subnets in at least 2 AZs)
resource "aws_db_subnet_group" "airflow" {
  name       = "${var.project_name}-${var.environment}-airflow-db-subnet"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-airflow-db-subnet-group"
  })
}

# DB Parameter Group for PostgreSQL optimization
resource "aws_db_parameter_group" "airflow" {
  name   = "${var.project_name}-${var.environment}-airflow-params"
  family = var.db_parameter_group_family

  # Optimize for small instance performance
  # Note: shared_preload_libraries is a static parameter requiring DB restart
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries taking longer than 1 second
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  # Force SSL connections for encryption in transit
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Instance
resource "aws_db_instance" "airflow" {
  #checkov:skip=CKV_AWS_17:RDS in public subnet for cost optimization
  #checkov:skip=CKV_AWS_293:Deletion protection variable-based
  #checkov:skip=CKV_AWS_353:Performance Insights variable-based
  #checkov:skip=CKV_AWS_157:Multi-AZ variable-based
  #checkov:skip=CKV_AWS_118:Enhanced monitoring enabled (checkov false positive)
  #checkov:skip=CKV_AWS_161:IAM authentication enabled (checkov false positive)
  identifier = "${var.project_name}-${var.environment}-airflow-metadata"

  # Engine configuration
  engine         = "postgres"
  engine_version = var.engine_version

  # Instance configuration
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  max_allocated_storage = var.max_allocated_storage # Enable storage autoscaling

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 5432

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.airflow.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = var.publicly_accessible

  # IAM authentication
  iam_database_authentication_enabled = var.enable_iam_authentication

  # Backup configuration - production ready
  backup_retention_period         = var.backup_retention_period
  backup_window                   = var.backup_window
  maintenance_window              = var.maintenance_window
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # High availability
  multi_az                  = var.multi_az
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-airflow-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Performance and monitoring
  performance_insights_enabled = var.enable_performance_insights
  monitoring_interval          = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn          = var.enable_enhanced_monitoring ? aws_iam_role.rds_monitoring.arn : null
  parameter_group_name         = aws_db_parameter_group.airflow.name
  copy_tags_to_snapshot        = true
  auto_minor_version_upgrade   = true
  apply_immediately            = var.apply_immediately

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-airflow-rds"
  })

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier,
      engine_version, # Allow AWS auto-upgrades without Terraform interference
    ]
  }
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-airflow-db-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.airflow.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_storage" {
  alarm_name          = "${var.project_name}-${var.environment}-airflow-db-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000" # 2GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.airflow.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-airflow-db-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "100000000" # 100MB in bytes
  alarm_description   = "This metric monitors RDS freeable memory"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.airflow.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-airflow-db-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.airflow.id
  }

  tags = var.tags
}
