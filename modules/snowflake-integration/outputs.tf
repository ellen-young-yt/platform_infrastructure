output "snowflake_role_arn" {
  description = "ARN of the IAM role for Snowflake to assume"
  value       = aws_iam_role.snowflake.arn
}

output "snowflake_role_name" {
  description = "Name of the IAM role for Snowflake"
  value       = aws_iam_role.snowflake.name
}

output "snowflake_loader_role_arn" {
  description = "ARN of the IAM role for Snowflake data loading tasks"
  value       = aws_iam_role.snowflake_loader.arn
}

output "snowflake_loader_role_name" {
  description = "Name of the IAM role for Snowflake data loading tasks"
  value       = aws_iam_role.snowflake_loader.name
}

output "snowflake_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Snowflake credentials"
  value       = aws_secretsmanager_secret.snowflake_credentials.arn
}

output "snowflake_credentials_secret_name" {
  description = "Name of the Secrets Manager secret containing Snowflake credentials"
  value       = aws_secretsmanager_secret.snowflake_credentials.name
}

output "snowflake_stage_s3_path" {
  description = "S3 path for Snowflake stage"
  value       = "s3://${var.data_lake_bucket_id}/snowflake-stage/"
}