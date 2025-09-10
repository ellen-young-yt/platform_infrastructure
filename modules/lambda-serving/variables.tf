variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC (optional, leave empty for Lambda outside VPC)"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets (optional, for Lambda in VPC)"
  type        = list(string)
  default     = []
}

variable "lambda_timeout" {
  description = "Timeout for Lambda function in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda function in MB"
  type        = number
  default     = 512
}

variable "enable_api_key" {
  description = "Enable API key authentication"
  type        = bool
  default     = false
}

variable "api_quota_limit" {
  description = "Monthly quota limit for API calls"
  type        = number
  default     = 10000
}

variable "api_rate_limit" {
  description = "Rate limit for API calls per second"
  type        = number
  default     = 100
}

variable "api_burst_limit" {
  description = "Burst limit for API calls"
  type        = number
  default     = 200
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
