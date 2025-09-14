
variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "container_name" {
  description = "Name of the container"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "image_uri" {
  description = "URI of the container image"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for the task"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Memory for the task"
  type        = string
  default     = "1024"
}

variable "execution_role_arn" {
  description = "ARN of the task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the task role"
  type        = string
}




variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "database_secret_name" {
  description = "Name of the database credentials secret in Secrets Manager"
  type        = string
}

variable "app_config_secret_name" {
  description = "Name of the app config secret in Secrets Manager"
  type        = string
}

variable "api_keys_secret_name" {
  description = "Name of the API keys secret in Secrets Manager"
  type        = string
}
