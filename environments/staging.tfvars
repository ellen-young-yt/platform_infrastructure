# Staging environment specific configuration
environment = "staging"

# Network Configuration - Staging
vpc_cidr = "10.1.0.0/16"

# Snowflake Integration - Use production account for staging
snowflake_account_id = "703671920640"

# ECS Resource Configuration - Balanced between dev and prod
task_cpu      = "512"
task_memory   = "1024"
desired_count = 1

# ALB Configuration - Enabled but deleteable
enable_deletion_protection = false

# Environment-specific application variables
ecs_environment_variables = {
  DBT_PROFILES_DIR = "/var/task/profiles"
  DBT_PROJECT_DIR  = "/var/task"
  DBT_TARGET       = "staging"
  ENVIRONMENT      = "staging"
  LOG_LEVEL        = "INFO"
}
