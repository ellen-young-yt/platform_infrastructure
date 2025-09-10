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

variable "private_subnet_ids" {
  description = "IDs of the private subnets"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets"
  type        = list(string)
  default     = []
}

variable "ecs_security_group_id" {
  description = "ID of the ECS security group"
  type        = string
}

variable "metabase_image" {
  description = "Docker image for Metabase"
  type        = string
  default     = "metabase/metabase:latest"
}

variable "cpu" {
  description = "CPU units for Metabase container"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory (MB) for Metabase container"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of Metabase instances"
  type        = number
  default     = 1
}

variable "database_type" {
  description = "Database type for Metabase metadata (h2, postgres, mysql, mariadb)"
  type        = string
  default     = "h2"
}

variable "database_connection_uri" {
  description = "Database connection URI for Metabase metadata"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_load_balancer" {
  description = "Whether to create an Application Load Balancer (disable for cost savings in dev)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
