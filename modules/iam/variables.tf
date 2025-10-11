# IAM Module Variables

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "service_type" {
  description = "Type of service (dbt, airflow, superset) to determine permissions"
  type        = string
  validation {
    condition     = contains(["dbt", "airflow", "superset"], var.service_type)
    error_message = "Service type must be one of: dbt, airflow, superset."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "additional_policy_statements" {
  description = "Additional policy statements to add to the ECS task role"
  type        = list(any)
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Secret ARN references - passed from root module
variable "snowflake_credentials_secret_arn" {
  description = "ARN of the Snowflake credentials secret"
  type        = string
  default     = null
}

# S3 bucket ARN references - passed from root module
variable "data_lake_bucket_arn" {
  description = "ARN of the data lake S3 bucket"
  type        = string
  default     = null
}

variable "processed_data_bucket_arn" {
  description = "ARN of the processed data S3 bucket"
  type        = string
  default     = null
}

variable "artifacts_bucket_arn" {
  description = "ARN of the artifacts S3 bucket"
  type        = string
  default     = null
}
