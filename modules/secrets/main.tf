
resource "aws_secretsmanager_secret" "snowflake_credentials" {
  name                    = "${var.project_name}/${var.environment}/snowflake/credentials"
  description             = "Snowflake credentials for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  kms_key_id              = var.enable_kms_encryption ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, {
    Purpose = "Snowflake credentials"
  })
}



resource "aws_secretsmanager_secret" "redis_credentials" {
  name                    = "${var.project_name}/${var.environment}/redis/credentials"
  description             = "Redis credentials for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  kms_key_id              = var.enable_kms_encryption ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, {
    Purpose = "Redis credentials"
  })
}

resource "aws_secretsmanager_secret" "api_keys" {
  name                    = "${var.project_name}/${var.environment}/api/keys"
  description             = "API keys and tokens for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  kms_key_id              = var.enable_kms_encryption ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, {
    Purpose = "API keys"
  })
}

resource "aws_secretsmanager_secret" "app_config" {
  name                    = "${var.project_name}/${var.environment}/app/config"
  description             = "Application configuration for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  kms_key_id              = var.enable_kms_encryption ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, {
    Purpose = "Application configuration"
  })
}

# Secret version will be managed outside of Terraform
# Use AWS CLI or Console to set the secret value after deployment
# Example structure for manual update:
# {
#   "secret_key": "your-secret-key-here",
#   "jwt_secret": "your-jwt-secret-here",
#   "encryption_key": "your-encryption-key-here",
#   "session_secret": "your-session-secret-here",
#   "additional_config": {}
# }

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
          aws_secretsmanager_secret.snowflake_credentials.arn,
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
          aws_secretsmanager_secret.snowflake_credentials.arn,
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
