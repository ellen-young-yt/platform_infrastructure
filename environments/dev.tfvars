# Development environment specific configuration
environment = "dev"

# Network Configuration - Development
vpc_cidr = "10.0.0.0/16"

# Snowflake Integration - Development Account
snowflake_account_id = "891612547191"

# ECS Resource Configuration - Optimized for cost
service_name   = "dbt"
container_name = "dbt-container"
task_cpu       = "512"
task_memory    = "1024"
desired_count  = 1

# ALB Configuration - Disabled for cost savings
enable_deletion_protection = false

# Environment-specific application variables
ecs_environment_variables = {
  DBT_PROFILES_DIR = "/var/task/profiles"
  DBT_PROJECT_DIR  = "/var/task"
  DBT_TARGET       = "dev"
  ENVIRONMENT      = "dev"
  LOG_LEVEL        = "DEBUG"
}
