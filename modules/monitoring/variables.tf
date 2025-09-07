variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
  default     = ""
}

variable "pagerduty_integration_key" {
  description = "PagerDuty integration key for alerts"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ecs_service_names" {
  description = "List of ECS service names to monitor"
  type        = list(string)
  default     = []
}

variable "lambda_function_names" {
  description = "List of Lambda function names to monitor"
  type        = list(string)
  default     = []
}

variable "api_gateway_names" {
  description = "List of API Gateway names to monitor"
  type        = list(string)
  default     = []
}

variable "log_group_names" {
  description = "List of CloudWatch log group names to create"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}