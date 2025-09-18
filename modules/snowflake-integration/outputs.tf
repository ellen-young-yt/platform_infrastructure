#
# ===== CROSS-ACCOUNT ACCESS OUTPUTS =====
#

output "snowflake_role_arn" {
  description = "ARN of the IAM role for Snowflake to assume (configure this in Snowflake)"
  value       = aws_iam_role.snowflake.arn
}

output "snowflake_role_name" {
  description = "Name of the IAM role for Snowflake cross-account access"
  value       = aws_iam_role.snowflake.name
}

#
# ===== INTERNAL DATA LOADING OUTPUTS =====
#

output "snowflake_loader_role_arn" {
  description = "ARN of the IAM role for internal data loading services (Lambda/ECS)"
  value       = aws_iam_role.snowflake_loader.arn
}

output "snowflake_loader_role_name" {
  description = "Name of the IAM role for internal data loading services"
  value       = aws_iam_role.snowflake_loader.name
}

#
# ===== S3 STAGING OUTPUTS =====
#

output "snowflake_stage_s3_path" {
  description = "S3 path for Snowflake staging area (use in COPY commands)"
  value       = "s3://${var.data_lake_bucket_id}/snowflake-stage/"
}

#
# ===== EXTERNAL ID OUTPUTS =====
#

output "snowflake_external_id_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Snowflake external ID"
  value       = aws_secretsmanager_secret.snowflake_external_id.arn
}

output "snowflake_external_id_secret_name" {
  description = "Name of the Secrets Manager secret containing Snowflake external ID"
  value       = aws_secretsmanager_secret.snowflake_external_id.name
}

output "snowflake_external_id_value" {
  description = "The external ID value for Snowflake configuration (sensitive)"
  value       = random_uuid.snowflake_external_id.result
  sensitive   = true
}

#
# ===== INTEGRATION NOTES =====
#
# Snowflake credentials outputs are handled by the secrets module
# Use module.secrets.snowflake_credentials_secret_arn in main configuration
