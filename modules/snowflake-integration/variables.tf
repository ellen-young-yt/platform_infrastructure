#
# ===== CORE CONFIGURATION =====
#

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project (used in resource naming)"
  type        = string
}

variable "data_lake_bucket_id" {
  description = "ID of the data lake S3 bucket"
  type        = string
}

variable "data_lake_bucket_arn" {
  description = "ARN of the data lake S3 bucket"
  type        = string
}

#
# ===== SNOWFLAKE CROSS-ACCOUNT CONFIGURATION =====
#

# tflint-ignore: terraform_unused_declarations
variable "snowflake_account_id" {
  description = "AWS account ID for Snowflake"
  type        = string
  default     = "703671920640"
}

# tflint-ignore: terraform_unused_declarations
variable "snowflake_external_id" {
  description = "External ID for Snowflake role assumption"
  type        = string
  default     = ""
  sensitive   = true
}

# Snowflake connection credentials are managed by the secrets module
# This module only handles AWS infrastructure for Snowflake access

#
# ===== ENCRYPTION CONFIGURATION =====
#

variable "enable_kms_encryption" {
  description = "Enable KMS encryption for S3 objects accessed by Snowflake"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of KMS key for S3 encryption (if enable_kms_encryption is true)"
  type        = string
  default     = ""
}

#
# ===== COMMON CONFIGURATION =====
#

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

#
# ===== SECRETS INTEGRATION =====
#

variable "snowflake_credentials_secret_arn" {
  description = "ARN of the Snowflake credentials secret from secrets module (required)"
  type        = string
}
