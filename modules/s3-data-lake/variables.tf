variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "data_retention_days" {
  description = "Number of days to retain data in the data lake"
  type        = number
  default     = 2555 # ~7 years
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}