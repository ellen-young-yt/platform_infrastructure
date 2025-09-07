variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ellen-young-yt"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "snowflake_account_id" {
  description = "AWS account ID for Snowflake (official Snowflake AWS account)"
  type        = string
  default     = "179819430825"
}

variable "snowflake_account" {
  description = "Snowflake account identifier"
  type        = string
  default     = ""
}

variable "pagerduty_integration_key" {
  description = "PagerDuty integration key for alerts"
  type        = string
  default     = ""
  sensitive   = true
}

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
  default     = ""
}