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

variable "database_type" {
  description = "Database type for Superset metadata (postgresql, mysql, sqlite)"
  type        = string
  default     = "sqlite"
}

variable "database_connection_uri" {
  description = "Database connection URI for Superset metadata"
  type        = string
  default     = ""
  sensitive   = true
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

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
