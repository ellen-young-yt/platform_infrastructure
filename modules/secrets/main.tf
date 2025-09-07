resource "aws_secretsmanager_secret" "database_credentials" {
  name                    = "${var.project_name}/${var.environment}/database/credentials"
  description             = "Database credentials for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = merge(var.tags, {
    Purpose = "Database credentials"
  })
}

resource "aws_secretsmanager_secret_version" "database_credentials" {
  secret_id = aws_secretsmanager_secret.database_credentials.id
  secret_string = jsonencode({
    username = var.database_username
    password = var.database_password
    host     = var.database_host
    port     = var.database_port
    database = var.database_name
    engine   = var.database_engine
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "redis_credentials" {
  name                    = "${var.project_name}/${var.environment}/redis/credentials"
  description             = "Redis credentials for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = merge(var.tags, {
    Purpose = "Redis credentials"
  })
}

resource "aws_secretsmanager_secret_version" "redis_credentials" {
  secret_id = aws_secretsmanager_secret.redis_credentials.id
  secret_string = jsonencode({
    host     = var.redis_host
    port     = var.redis_port
    password = var.redis_password
    url      = "redis://${var.redis_password != "" ? ":${var.redis_password}@" : ""}${var.redis_host}:${var.redis_port}/0"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "api_keys" {
  name                    = "${var.project_name}/${var.environment}/api/keys"
  description             = "API keys and tokens for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = merge(var.tags, {
    Purpose = "API keys"
  })
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    openai_api_key    = var.openai_api_key
    github_token      = var.github_token
    slack_webhook_url = var.slack_webhook_url
    datadog_api_key   = var.datadog_api_key
    custom_api_keys   = var.custom_api_keys
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "app_config" {
  name                    = "${var.project_name}/${var.environment}/app/config"
  description             = "Application configuration for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = merge(var.tags, {
    Purpose = "Application configuration"
  })
}

resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id
  secret_string = jsonencode({
    secret_key        = var.app_secret_key
    jwt_secret        = var.jwt_secret
    encryption_key    = var.encryption_key
    session_secret    = var.session_secret
    additional_config = var.additional_app_config
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_iam_role" "secrets_access" {
  name = "${var.project_name}-${var.environment}-secrets-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "secrets_access" {
  name = "${var.project_name}-${var.environment}-secrets-access-policy"
  role = aws_iam_role.secrets_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.database_credentials.arn,
          aws_secretsmanager_secret.redis_credentials.arn,
          aws_secretsmanager_secret.api_keys.arn,
          aws_secretsmanager_secret.app_config.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "secrets_rotation" {
  count = var.enable_secret_rotation ? 1 : 0
  name  = "${var.project_name}-${var.environment}-secrets-rotation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "secrets_rotation" {
  count = var.enable_secret_rotation ? 1 : 0
  name  = "${var.project_name}-${var.environment}-secrets-rotation-policy"
  role  = aws_iam_role.secrets_rotation[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = [
          aws_secretsmanager_secret.database_credentials.arn,
          aws_secretsmanager_secret.redis_credentials.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_kms_key" "secrets" {
  count                   = var.enable_kms_encryption ? 1 : 0
  description             = "KMS key for ${var.project_name}-${var.environment} secrets encryption"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = var.environment == "prod" ? true : false

  tags = merge(var.tags, {
    Purpose = "Secrets encryption"
  })
}

resource "aws_kms_alias" "secrets" {
  count         = var.enable_kms_encryption ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets[0].key_id
}