output "database_credentials_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.database_credentials.arn
}

output "database_credentials_secret_name" {
  description = "Name of the database credentials secret"
  value       = aws_secretsmanager_secret.database_credentials.name
}

output "redis_credentials_secret_arn" {
  description = "ARN of the Redis credentials secret"
  value       = aws_secretsmanager_secret.redis_credentials.arn
}

output "redis_credentials_secret_name" {
  description = "Name of the Redis credentials secret"
  value       = aws_secretsmanager_secret.redis_credentials.name
}

output "api_keys_secret_arn" {
  description = "ARN of the API keys secret"
  value       = aws_secretsmanager_secret.api_keys.arn
}

output "api_keys_secret_name" {
  description = "Name of the API keys secret"
  value       = aws_secretsmanager_secret.api_keys.name
}

output "app_config_secret_arn" {
  description = "ARN of the application config secret"
  value       = aws_secretsmanager_secret.app_config.arn
}

output "app_config_secret_name" {
  description = "Name of the application config secret"
  value       = aws_secretsmanager_secret.app_config.name
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
