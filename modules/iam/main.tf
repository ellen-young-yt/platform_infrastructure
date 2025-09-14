# IAM Module
# Creates centralized IAM roles and policies for all ECS tasks

# Service-specific policy definitions
locals {
  # Base policies needed by all services
  base_policies = [
    {
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = "arn:aws:logs:*:*:*"
    },
    {
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    }
  ]

  # Service-specific policies
  dbt_policies = [
    {
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ]
      Resource = "arn:aws:ssm:*:*:parameter/${var.service_name}/*"
    },
    {
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        "arn:aws:secretsmanager:*:*:secret:${var.environment}/*",
        "arn:aws:secretsmanager:*:*:secret:${var.service_name}/${var.environment}/*"
      ]
    },
    {
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        var.data_lake_bucket_arn,
        "${var.data_lake_bucket_arn}/*"
      ]
    },
    {
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        var.processed_data_bucket_arn,
        "${var.processed_data_bucket_arn}/*"
      ]
    },
    {
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        var.artifacts_bucket_arn,
        "${var.artifacts_bucket_arn}/*"
      ]
    }
  ]

  airflow_policies = [
    {
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::${var.project_name}-${var.environment}-*",
        "arn:aws:s3:::${var.project_name}-${var.environment}-*/*"
      ]
    },
    {
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      Resource = "arn:aws:kms:*:*:key/*"
      Condition = {
        StringLike = {
          "kms:ViaService" = "s3.*.amazonaws.com"
        }
      }
    },
    {
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/${var.environment}/*"
    }
  ]

  metabase_policies = [
    {
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/${var.environment}/*"
    }
  ]

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

# ECS Task Execution Role Policy Attachment
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for ECS tasks
resource "aws_iam_policy" "ecs_custom_policy" {
  name        = "${var.service_name}-${var.environment}-custom-policy"
  description = "Custom policy for ${var.service_name} ECS tasks"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.service_policies
  })

  tags = merge(var.common_tags, {
    Name        = "${var.service_name}-${var.environment}-custom-policy"
    Module      = "iam"
    Environment = var.environment
  })
}

# Attach custom policy to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_custom_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_custom_policy.arn
}
