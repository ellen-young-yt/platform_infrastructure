#
# ===== SNOWFLAKE CROSS-ACCOUNT ACCESS =====
# Resources for allowing Snowflake to access AWS resources
#

# Generate a unique external ID for secure cross-account role assumption
resource "random_uuid" "snowflake_external_id" {}

# IAM role that Snowflake can assume to access AWS resources
resource "aws_iam_role" "snowflake" {
  name = "${var.project_name}-${var.environment}-snowflake-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.snowflake_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = random_uuid.snowflake_external_id.result
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Purpose = "Snowflake cross-account access"
  })
}

# S3 access policy for Snowflake role - allows reading from data lake and writing to staging area
resource "aws_iam_role_policy" "snowflake_s3_access" {
  name = "${var.project_name}-${var.environment}-snowflake-s3-policy"
  role = aws_iam_role.snowflake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          var.data_lake_bucket_arn,
          "${var.data_lake_bucket_arn}/*"
        ]
      },
      {
        # Allow KMS decryption for S3 objects
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "arn:aws:kms:*:*:key/*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "s3.*.amazonaws.com"
          }
        }
      },
      {
        # Allow Snowflake to write to staging area for data loading
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.data_lake_bucket_arn}/snowflake-stage/*"
        ]
      }
    ]
  })
}

#
# ===== S3 STAGING AREA SETUP =====
# Creates dedicated staging area for Snowflake data operations
#

# Create staging prefix in data lake bucket for Snowflake operations
resource "aws_s3_object" "snowflake_stage_prefix" {
  bucket  = var.data_lake_bucket_id
  key     = "snowflake-stage/"
  content = ""

  tags = merge(var.tags, {
    Purpose = "Snowflake stage prefix"
  })
}

# Optional KMS access policy for Snowflake role (when encryption is enabled)
resource "aws_iam_role_policy" "snowflake_kms_access" {
  count = var.enable_kms_encryption ? 1 : 0

  name = "${var.project_name}-${var.environment}-snowflake-kms-policy"
  role = aws_iam_role.snowflake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn != "" ? var.kms_key_arn : "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}

#
# ===== INTERNAL DATA LOADING INFRASTRUCTURE =====
# AWS services (Lambda/ECS) that load data into Snowflake
#

# IAM role for internal AWS services that need to load data into Snowflake
resource "aws_iam_role" "snowflake_loader" {
  name = "${var.project_name}-${var.environment}-snowflake-loader-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Purpose = "Snowflake data loader services"
  })
}

# Comprehensive access policy for data loading services
resource "aws_iam_role_policy" "snowflake_loader" {
  name = "${var.project_name}-${var.environment}-snowflake-loader-policy"
  role = aws_iam_role.snowflake_loader.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.data_lake_bucket_arn,
          "${var.data_lake_bucket_arn}/*"
        ]
      },
      {
        # Access to Snowflake credentials for authentication
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.snowflake_credentials_secret_arn
      },
      {
        # CloudWatch logging permissions for monitoring
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

#
# ===== EXTERNAL ID MANAGEMENT =====
# Manages the external ID used for secure cross-account access
#

# Snowflake credentials are managed by the secrets module
# This module receives the secret ARN via var.snowflake_credentials_secret_arn

# Secret to store the external ID for Snowflake cross-account role assumption
resource "aws_secretsmanager_secret" "snowflake_external_id" {
  name                    = "${var.project_name}/${var.environment}/snowflake/external-id"
  description             = "External ID for Snowflake IAM role assumption"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = merge(var.tags, {
    Purpose = "Snowflake external ID"
  })
}

# Store the generated external ID in the secret
resource "aws_secretsmanager_secret_version" "snowflake_external_id" {
  secret_id     = aws_secretsmanager_secret.snowflake_external_id.id
  secret_string = random_uuid.snowflake_external_id.result
}

data "aws_region" "current" {}
