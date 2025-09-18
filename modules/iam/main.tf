# IAM Module
# Creates centralized IAM roles and policies for all ECS tasks

# Service-specific policy definitions
locals {
  # Base policies loaded from JSON file
  base_policies = jsondecode(file("${path.module}/policies/base-policies.json"))

  # Execution role policy - secrets access for container startup
  execution_role_policy = templatefile("${path.module}/policies/execution-role-policy.json.tftpl", {
    secret_arns = compact([
      var.snowflake_credentials_secret_arn,
      var.app_config_secret_arn,
      var.api_keys_secret_arn
    ])
  })

  # Service-specific policies loaded from template files
  dbt_policies = jsondecode(templatefile("${path.module}/policies/dbt-policies.json.tftpl", {
    service_name              = var.service_name
    data_lake_bucket_arn      = var.data_lake_bucket_arn
    processed_data_bucket_arn = var.processed_data_bucket_arn
    artifacts_bucket_arn      = var.artifacts_bucket_arn
  }))

  airflow_policies = jsondecode(templatefile("${path.module}/policies/airflow-policies.json.tftpl", {
    project_name = var.project_name
    environment  = var.environment
  }))

  metabase_policies = jsondecode(templatefile("${path.module}/policies/metabase-policies.json.tftpl", {
    project_name = var.project_name
    environment  = var.environment
  }))

  # Task role policy - application runtime permissions
  task_role_policy = {
    Version   = "2012-10-17"
    Statement = local.service_policies
  }

  # Combine base policies with service-specific policies
  service_policies = concat(
    local.base_policies,
    lookup({
      dbt      = local.dbt_policies
      airflow  = local.airflow_policies
      metabase = local.metabase_policies
    }, var.service_type, []),
    var.additional_policy_statements
  )
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.service_name}-${var.environment}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.service_name}-${var.environment}-execution-role"
    Module      = "iam"
    Environment = var.environment
  })
}

# ECS Task Role (for application permissions)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.service_name}-${var.environment}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.service_name}-${var.environment}-task-role"
    Module      = "iam"
    Environment = var.environment
  })
}

# Data source for AWS managed ECS task execution policy
data "aws_iam_policy" "ecs_task_execution_role_policy" {
  name = "AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Execution Role Policy Attachment
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_role_policy.arn
}


# Execution role policy for secrets access during container startup
resource "aws_iam_policy" "ecs_execution_policy" {
  count       = var.service_type == "dbt" ? 1 : 0
  name        = "${var.service_name}-${var.environment}-execution-policy"
  description = "Execution policy for ${var.service_name} ECS tasks - secrets access"

  policy = local.execution_role_policy

  tags = merge(var.common_tags, {
    Name        = "${var.service_name}-${var.environment}-execution-policy"
    Module      = "iam"
    Environment = var.environment
  })
}

# Task role policy for application runtime permissions
resource "aws_iam_policy" "ecs_task_policy" {
  name        = "${var.service_name}-${var.environment}-task-policy"
  description = "Task policy for ${var.service_name} ECS tasks - runtime permissions"

  policy = jsonencode(local.task_role_policy)

  tags = merge(var.common_tags, {
    Name        = "${var.service_name}-${var.environment}-task-policy"
    Module      = "iam"
    Environment = var.environment
  })
}

# Attach execution policy to execution role (only for dbt service)
resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  count      = var.service_type == "dbt" ? 1 : 0
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_policy[0].arn
}

# Attach task policy to task role
resource "aws_iam_role_policy_attachment" "ecs_task_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}
