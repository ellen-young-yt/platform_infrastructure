variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "database_username" {
  description = "Database username"
  type        = string
  default     = "admin"
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "database_password" {
  description = "Database password"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "database_host" {
  description = "Database host"
  type        = string
  default     = "localhost"
}

# tflint-ignore: terraform_unused_declarations
variable "database_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

# tflint-ignore: terraform_unused_declarations
variable "database_name" {
  description = "Database name"
  type        = string
  default     = "main"
}

# tflint-ignore: terraform_unused_declarations
variable "database_engine" {
  description = "Database engine (postgres, mysql, etc.)"
  type        = string
  default     = "postgres"
}

# tflint-ignore: terraform_unused_declarations
variable "redis_host" {
  description = "Redis host"
  type        = string
  default     = "localhost"
}

# tflint-ignore: terraform_unused_declarations
variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

# tflint-ignore: terraform_unused_declarations
variable "redis_password" {
  description = "Redis password"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "custom_api_keys" {
  description = "Map of custom API keys"
  type        = map(string)
  default     = {}
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "app_secret_key" {
  description = "Application secret key"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "jwt_secret" {
  description = "JWT secret for token signing"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "encryption_key" {
  description = "Application encryption key"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "session_secret" {
  description = "Session secret for web applications"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "additional_app_config" {
  description = "Additional application configuration"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "enable_secret_rotation" {
  description = "Enable automatic secret rotation"
  type        = bool
  default     = false
}

variable "enable_kms_encryption" {
  description = "Enable KMS encryption for secrets"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
