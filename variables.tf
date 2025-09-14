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

# tflint-ignore: terraform_unused_declarations
variable "snowflake_account_id" {
  description = "AWS account ID for Snowflake (official Snowflake AWS account)"
  type        = string
  default     = "179819430825"
}

# tflint-ignore: terraform_unused_declarations
variable "snowflake_account" {
  description = "Snowflake account identifier"
  type        = string
  default     = ""
}

# tflint-ignore: terraform_unused_declarations
variable "pagerduty_integration_key" {
  description = "PagerDuty integration key for alerts"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "notification_email" {
  description = "Email address for notifications"
  type        = string
  default     = ""
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for the ECS task"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Memory for the ECS task"
  type        = string
  default     = "1024"
}

variable "ecs_environment_variables" {
  description = "Environment variables for the ECS container"
  type        = map(string)
  default     = {}
}

variable "container_name" {
  description = "Name of the ECS container"
  type        = string
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALBs"
  type        = bool
  default     = false
}
