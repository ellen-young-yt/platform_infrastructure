# Common configuration shared across all environments
# These values are the same regardless of environment

# Project Configuration
project_name = "ellen-young-yt"
aws_region   = "us-east-2"

# Network Configuration
availability_zones = ["us-east-2a", "us-east-2b", "us-east-2c"]

# Snowflake Integration (shared account)
snowflake_account = "QHAQNPB-NO48574"

# Monitoring
notification_email        = "m.adamski3@gmail.com"
pagerduty_integration_key = ""

# ECS Service Configuration
service_name   = "dbt-service"
container_name = "dbt-container"

# Application Configuration
ecs_environment_variables = {
  DBT_PROFILES_DIR = "/var/task/profiles"
  DBT_PROJECT_DIR  = "/var/task"
}
