variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ID of the ECS security group"
  type        = string
}

variable "superset_image" {
  description = "Docker image for Superset"
  type        = string
  default     = "apache/superset:latest"
}

variable "cpu" {
  description = "CPU units for Superset container"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory (MB) for Superset container"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of Superset instances"
  type        = number
  default     = 1
}

variable "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  type        = string
  default     = ""
}

variable "app_config_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Superset app configuration (SECRET_KEY, etc.)"
  type        = string
  default     = ""
}

variable "enable_load_balancer" {
  description = "Whether to create an Application Load Balancer (disable for cost savings in dev)"
  type        = bool
  default     = true
}

variable "execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task role"
  type        = string
}

variable "redis_host" {
  description = "Redis endpoint hostname"
  type        = string
  default     = ""
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "redis_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Redis credentials"
  type        = string
  default     = ""
}

variable "snowflake_superset_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Snowflake credentials for Superset (key-pair auth)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
