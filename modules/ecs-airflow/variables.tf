variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

# tflint-ignore: terraform_unused_declarations
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

variable "airflow_image" {
  description = "Docker image for Airflow"
  type        = string
  default     = "apache/airflow:2.7.3"
}

variable "webserver_cpu" {
  description = "CPU units for Airflow webserver"
  type        = number
  default     = 512
}

variable "webserver_memory" {
  description = "Memory (MB) for Airflow webserver"
  type        = number
  default     = 1024
}

variable "scheduler_cpu" {
  description = "CPU units for Airflow scheduler"
  type        = number
  default     = 512
}

variable "scheduler_memory" {
  description = "Memory (MB) for Airflow scheduler"
  type        = number
  default     = 1024
}

variable "database_connection_string" {
  description = "Database connection string for Airflow metadata"
  type        = string
  default     = "sqlite:///tmp/airflow.db"
  sensitive   = true
}

variable "redis_connection_string" {
  description = "Redis connection string for Celery broker"
  type        = string
  default     = "redis://localhost:6379/0"
  sensitive   = true
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
