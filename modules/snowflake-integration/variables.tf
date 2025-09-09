variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
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

# tflint-ignore: terraform_unused_declarations
variable "snowflake_account_id" {
  description = "AWS account ID for Snowflake (official Snowflake AWS account)"
  type        = string
  default     = "179819430825" # Official Snowflake AWS account ID for us-east-2
}

# tflint-ignore: terraform_unused_declarations
variable "snowflake_external_id" {
  description = "External ID for Snowflake role assumption"
  type        = string
  default     = ""
  sensitive   = true
}

variable "snowflake_account" {
  description = "Snowflake account identifier"
  type        = string
  default     = ""
}

variable "snowflake_username" {
  description = "Snowflake username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "snowflake_warehouse" {
  description = "Snowflake warehouse name"
  type        = string
  default     = "COMPUTE_WH"
}

variable "snowflake_database" {
  description = "Snowflake database name"
  type        = string
  default     = ""
}

variable "snowflake_schema" {
  description = "Snowflake schema name"
  type        = string
  default     = "PUBLIC"
}

variable "snowflake_role" {
  description = "Snowflake role name"
  type        = string
  default     = "ACCOUNTADMIN"
}

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

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
