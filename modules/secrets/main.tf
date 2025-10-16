
resource "aws_secretsmanager_secret" "snowflake_dbt_credentials" {
  name                    = "${var.project_name}/${var.environment}/snowflake/dbt-credentials"
  description             = "Snowflake credentials for dbt in ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  kms_key_id              = var.enable_kms_encryption ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, {
    Purpose = "Snowflake dbt credentials"
  })
}

resource "aws_secretsmanager_secret" "snowflake_superset_credentials" {
  name                    = "${var.project_name}/${var.environment}/snowflake/superset-credentials"
  description             = "Snowflake credentials for Superset (key-pair auth) in ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  kms_key_id              = var.enable_kms_encryption ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, {
    Purpose = "Snowflake Superset credentials"
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

resource "aws_secretsmanager_secret" "superset_rds_credentials" {
  name                    = "${var.project_name}/${var.environment}/superset/rds-credentials"
  description             = "RDS database credentials for Superset metadata in ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  kms_key_id              = var.enable_kms_encryption ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, {
    Purpose = "Superset RDS credentials"
  })
}

resource "aws_secretsmanager_secret" "superset_app_config" {
  name                    = "${var.project_name}/${var.environment}/superset/app-config"
  description             = "Superset application configuration including SECRET_KEY for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  kms_key_id              = var.enable_kms_encryption ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, {
    Purpose = "Superset application configuration"
  })
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
          aws_secretsmanager_secret.snowflake_dbt_credentials.arn,
          aws_secretsmanager_secret.snowflake_superset_credentials.arn,
          aws_secretsmanager_secret.redis_credentials.arn,
          aws_secretsmanager_secret.superset_rds_credentials.arn,
          aws_secretsmanager_secret.superset_app_config.arn
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
          aws_secretsmanager_secret.snowflake_dbt_credentials.arn,
          aws_secretsmanager_secret.snowflake_superset_credentials.arn,
          aws_secretsmanager_secret.redis_credentials.arn,
          aws_secretsmanager_secret.superset_rds_credentials.arn,
          aws_secretsmanager_secret.superset_app_config.arn
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
