output "snowflake_dbt_credentials_secret_arn" {
  description = "ARN of the Snowflake dbt credentials secret"
  value       = aws_secretsmanager_secret.snowflake_dbt_credentials.arn
}

output "snowflake_dbt_credentials_secret_name" {
  description = "Name of the Snowflake dbt credentials secret"
  value       = aws_secretsmanager_secret.snowflake_dbt_credentials.name
}

output "snowflake_superset_credentials_secret_arn" {
  description = "ARN of the Snowflake Superset credentials secret"
  value       = aws_secretsmanager_secret.snowflake_superset_credentials.arn
}

output "snowflake_superset_credentials_secret_name" {
  description = "Name of the Snowflake Superset credentials secret"
  value       = aws_secretsmanager_secret.snowflake_superset_credentials.name
}

output "redis_credentials_secret_arn" {
  description = "ARN of the Redis credentials secret"
  value       = aws_secretsmanager_secret.redis_credentials.arn
}

output "redis_credentials_secret_name" {
  description = "Name of the Redis credentials secret"
  value       = aws_secretsmanager_secret.redis_credentials.name
}

output "secrets_access_role_arn" {
  description = "ARN of the secrets access IAM role"
  value       = aws_iam_role.secrets_access.arn
}

output "secrets_access_role_name" {
  description = "Name of the secrets access IAM role"
  value       = aws_iam_role.secrets_access.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key for secrets encryption"
  value       = var.enable_kms_encryption ? aws_kms_key.secrets[0].arn : null
}

output "kms_key_id" {
  description = "ID of the KMS key for secrets encryption"
  value       = var.enable_kms_encryption ? aws_kms_key.secrets[0].key_id : null
}

output "kms_alias_name" {
  description = "Alias name of the KMS key"
  value       = var.enable_kms_encryption ? aws_kms_alias.secrets[0].name : null
}

output "superset_rds_credentials_secret_arn" {
  description = "ARN of the Superset RDS credentials secret"
  value       = aws_secretsmanager_secret.superset_rds_credentials.arn
}

output "superset_rds_credentials_secret_name" {
  description = "Name of the Superset RDS credentials secret"
  value       = aws_secretsmanager_secret.superset_rds_credentials.name
}

output "superset_app_config_secret_arn" {
  description = "ARN of the Superset application configuration secret"
  value       = aws_secretsmanager_secret.superset_app_config.arn
}

output "superset_app_config_secret_name" {
  description = "Name of the Superset application configuration secret"
  value       = aws_secretsmanager_secret.superset_app_config.name
}
