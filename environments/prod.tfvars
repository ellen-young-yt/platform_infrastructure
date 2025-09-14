# Production environment specific configuration
environment = "prod"

# Network Configuration - Production
vpc_cidr = "10.2.0.0/16"

# Snowflake Integration - Production Account
snowflake_account_id = "703671920640"

# ECS Resource Configuration - Higher performance for production
task_cpu      = "1024"
task_memory   = "2048"
desired_count = 2

# ALB Configuration - Protection enabled
enable_deletion_protection = true

# Environment-specific application variables
ecs_environment_variables = {
  DBT_PROFILES_DIR = "/var/task/profiles"
  DBT_PROJECT_DIR  = "/var/task"
  DBT_TARGET       = "prod"
  ENVIRONMENT      = "prod"
  LOG_LEVEL        = "INFO"
}
