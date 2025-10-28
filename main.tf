
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket  = "terraform-state-madamski"
    key     = "terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

module "networking" {
  source = "./modules/networking"

  environment        = var.environment
  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  tags = local.common_tags
}

module "secrets" {
  source = "./modules/secrets"

  environment  = var.environment
  project_name = var.project_name

  tags = local.common_tags
}

module "s3_data_lake" {
  source = "./modules/s3-data-lake"

  environment  = var.environment
  project_name = var.project_name

  tags = local.common_tags
}

module "snowflake_integration" {
  source = "./modules/snowflake-integration"

  environment          = var.environment
  project_name         = var.project_name
  data_lake_bucket_id  = module.s3_data_lake.data_lake_bucket_id
  data_lake_bucket_arn = module.s3_data_lake.data_lake_bucket_arn

  # Pass direct module reference for secret ARN
  snowflake_credentials_secret_arn = module.secrets.snowflake_dbt_credentials_secret_arn

  tags = local.common_tags
}

# IAM for Airflow
module "iam_airflow" {
  source = "./modules/iam"

  service_name = "airflow"
  service_type = "airflow"
  environment  = var.environment
  project_name = var.project_name
  common_tags  = local.common_tags

  # Pass direct module references for secrets
  snowflake_credentials_secret_arn = module.secrets.snowflake_dbt_credentials_secret_arn

  # Pass direct module references for S3 buckets
  data_lake_bucket_arn      = module.s3_data_lake.data_lake_bucket_arn
  processed_data_bucket_arn = module.s3_data_lake.processed_data_bucket_arn
  artifacts_bucket_arn      = module.s3_data_lake.artifacts_bucket_arn

  depends_on = [module.s3_data_lake, module.secrets]
}

# RDS for Airflow metadata
# checkov:skip=CKV_AWS_17: RDS in public subnet (cost optimization - no NAT gateway)
# checkov:skip=CKV_AWS_293: Deletion protection variable-based (prod only)
# checkov:skip=CKV_AWS_353: Performance Insights variable-based (prod only)
# checkov:skip=CKV_AWS_157: Multi-AZ variable-based (prod only)
module "rds_airflow" {
  source = "./modules/rds-airflow"

  environment       = var.environment
  project_name      = var.project_name
  subnet_ids        = module.networking.public_subnet_ids
  security_group_id = module.networking.rds_security_group_id

  # Database configuration
  db_name                   = "airflow"
  db_username               = "airflow"
  instance_class            = var.environment == "prod" ? "db.t4g.small" : "db.t4g.micro"
  allocated_storage         = 20
  max_allocated_storage     = 100
  engine_version            = "16.8"
  db_parameter_group_family = "postgres16"

  # Backup configuration
  backup_retention_period     = var.environment == "prod" ? 30 : 7
  multi_az                    = var.environment == "prod" ? true : false
  deletion_protection         = var.environment == "prod" ? true : false
  skip_final_snapshot         = var.environment != "prod"
  enable_performance_insights = var.environment == "prod" ? true : false
  enable_enhanced_monitoring  = true # Minimal cost (~$1.17/month), enable in all environments
  enable_iam_authentication   = true # No cost, enable in all environments

  tags = local.common_tags

  depends_on = [module.networking]
}

# Store Airflow RDS credentials in Secrets Manager
resource "aws_secretsmanager_secret_version" "airflow_rds_credentials" {
  secret_id = module.secrets.airflow_rds_credentials_secret_arn
  secret_string = jsonencode({
    db_name              = module.rds_airflow.db_name
    db_username          = module.rds_airflow.db_username
    db_password          = module.rds_airflow.db_password
    db_host              = module.rds_airflow.db_instance_address
    db_port              = tostring(module.rds_airflow.db_instance_port)
    db_connection_string = module.rds_airflow.db_connection_string
  })
}

# Generate Airflow Fernet key for encrypting sensitive data
resource "random_password" "airflow_fernet_key" {
  length  = 32
  special = false # Fernet key must be URL-safe base64
}

# Store Airflow Fernet key in Secrets Manager
resource "aws_secretsmanager_secret_version" "airflow_fernet_key" {
  secret_id     = module.secrets.airflow_fernet_key_secret_arn
  secret_string = base64encode(random_password.airflow_fernet_key.result)
}

# Generate Airflow webserver secret key
resource "random_password" "airflow_webserver_secret_key" {
  length  = 32
  special = true
}

# Store Airflow webserver secret key in Secrets Manager
resource "aws_secretsmanager_secret_version" "airflow_webserver_secret_key" {
  secret_id     = module.secrets.airflow_webserver_secret_key_arn
  secret_string = random_password.airflow_webserver_secret_key.result
}

module "ecs_airflow" {
  source = "./modules/ecs-airflow"

  environment           = var.environment
  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id

  # Use centralized IAM roles
  execution_role_arn = module.iam_airflow.ecs_execution_role_arn
  task_role_arn      = module.iam_airflow.ecs_task_role_arn

  # Use custom Docker image from ECR
  airflow_image = "${module.ecr.airflow_repository_url}:latest"

  # Database configuration
  database_connection_string = module.rds_airflow.db_connection_string

  # Secrets configuration
  airflow_webserver_secret_key_arn = module.secrets.airflow_webserver_secret_key_arn

  # Resource configuration from environment variables
  webserver_cpu    = var.task_cpu
  webserver_memory = var.task_memory
  scheduler_cpu    = var.task_cpu
  scheduler_memory = var.task_memory

  tags = local.common_tags

  depends_on = [
    module.rds_airflow,
    aws_secretsmanager_secret_version.airflow_rds_credentials,
    aws_secretsmanager_secret_version.airflow_fernet_key,
    aws_secretsmanager_secret_version.airflow_webserver_secret_key
  ]
}

# RDS for Superset metadata
# checkov:skip=CKV_AWS_17: RDS in public subnet (cost optimization - no NAT gateway)
# checkov:skip=CKV_AWS_293: Deletion protection variable-based (prod only)
# checkov:skip=CKV_AWS_353: Performance Insights variable-based (prod only)
# checkov:skip=CKV_AWS_157: Multi-AZ variable-based (prod only)
module "rds_superset" {
  source = "./modules/rds-superset"

  environment       = var.environment
  project_name      = var.project_name
  subnet_ids        = module.networking.public_subnet_ids
  security_group_id = module.networking.rds_security_group_id

  # Database configuration
  db_name                   = "superset"
  db_username               = "superset"
  instance_class            = var.environment == "prod" ? "db.t4g.small" : "db.t4g.micro"
  allocated_storage         = 20
  max_allocated_storage     = 100
  engine_version            = "16.8"
  db_parameter_group_family = "postgres16"

  # Backup configuration
  backup_retention_period     = var.environment == "prod" ? 30 : 7
  multi_az                    = var.environment == "prod" ? true : false
  deletion_protection         = var.environment == "prod" ? true : false
  skip_final_snapshot         = var.environment != "prod"
  enable_performance_insights = var.environment == "prod" ? true : false
  enable_enhanced_monitoring  = true # Minimal cost (~$1.17/month), enable in all environments
  enable_iam_authentication   = true # No cost, enable in all environments

  tags = local.common_tags

  depends_on = [module.networking]
}

# Generate random SECRET_KEY for Superset
resource "random_password" "superset_secret_key" {
  length  = 42
  special = true
}

# Store RDS credentials in Secrets Manager
resource "aws_secretsmanager_secret_version" "superset_rds_credentials" {
  secret_id = module.secrets.superset_rds_credentials_secret_arn
  secret_string = jsonencode({
    db_name              = module.rds_superset.db_name
    db_username          = module.rds_superset.db_username
    db_password          = module.rds_superset.db_password
    db_host              = module.rds_superset.db_instance_address
    db_port              = tostring(module.rds_superset.db_instance_port)
    db_connection_string = module.rds_superset.db_connection_string
  })
}

# Store Superset app configuration in Secrets Manager
resource "aws_secretsmanager_secret_version" "superset_app_config" {
  secret_id = module.secrets.superset_app_config_secret_arn
  secret_string = jsonencode({
    secret_key = random_password.superset_secret_key.result
  })
}

# ElastiCache Redis for Superset caching
# checkov:skip=CKV2_AWS_50: Multi-AZ failover variable-based (prod only)
module "elasticache_redis" {
  source = "./modules/elasticache-redis"

  environment  = var.environment
  project_name = var.project_name
  vpc_id       = module.networking.vpc_id
  subnet_ids   = module.networking.public_subnet_ids

  # Allow access only from ECS security group
  allowed_security_group_ids = [module.networking.ecs_security_group_id]

  # Configuration from variables
  node_type                  = var.redis_node_type
  num_cache_nodes            = var.redis_num_cache_nodes
  automatic_failover_enabled = var.redis_automatic_failover_enabled
  multi_az_enabled           = var.redis_multi_az_enabled

  # Security settings
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token_enabled         = true

  # Backup settings
  snapshot_retention_limit = var.environment == "prod" ? 7 : 1

  tags = local.common_tags

  depends_on = [module.networking]
}

# Store Redis credentials in Secrets Manager
resource "aws_secretsmanager_secret_version" "redis_credentials" {
  secret_id = module.secrets.redis_credentials_secret_arn
  secret_string = jsonencode({
    auth_token        = module.elasticache_redis.auth_token
    endpoint          = module.elasticache_redis.redis_endpoint
    port              = module.elasticache_redis.redis_port
    connection_string = module.elasticache_redis.redis_connection_string
  })
}

# IAM for Superset
module "iam_superset" {
  source = "./modules/iam"

  service_name = "superset"
  service_type = "superset"
  environment  = var.environment
  project_name = var.project_name
  common_tags  = local.common_tags

  # Pass direct module references for secrets
  snowflake_credentials_secret_arn    = module.secrets.snowflake_superset_credentials_secret_arn
  superset_rds_credentials_secret_arn = module.secrets.superset_rds_credentials_secret_arn
  superset_app_config_secret_arn      = module.secrets.superset_app_config_secret_arn
  redis_credentials_secret_arn        = module.secrets.redis_credentials_secret_arn

  # Pass direct module references for S3 buckets
  data_lake_bucket_arn      = module.s3_data_lake.data_lake_bucket_arn
  processed_data_bucket_arn = module.s3_data_lake.processed_data_bucket_arn
  artifacts_bucket_arn      = module.s3_data_lake.artifacts_bucket_arn

  depends_on = [module.secrets]
}

module "ecs_superset" {
  source = "./modules/ecs-superset"

  environment           = var.environment
  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id

  # Use centralized IAM roles
  execution_role_arn = module.iam_superset.ecs_execution_role_arn
  task_role_arn      = module.iam_superset.ecs_task_role_arn

  # Secrets configuration
  rds_secret_arn                = module.secrets.superset_rds_credentials_secret_arn
  app_config_secret_arn         = module.secrets.superset_app_config_secret_arn
  snowflake_superset_secret_arn = module.secrets.snowflake_superset_credentials_secret_arn

  # Redis configuration
  redis_host       = module.elasticache_redis.redis_endpoint
  redis_port       = module.elasticache_redis.redis_port
  redis_secret_arn = var.redis_num_cache_nodes > 1 ? module.secrets.redis_credentials_secret_arn : ""

  # Use custom Docker image from ECR
  superset_image = "${module.ecr.superset_repository_url}:latest"

  # Configuration from environment variables
  enable_load_balancer = var.enable_deletion_protection # Use same logic as ALB protection
  ssl_certificate_arn  = var.superset_ssl_certificate_arn

  # Resource configuration
  cpu           = var.task_cpu
  memory        = var.task_memory
  desired_count = var.desired_count

  tags = local.common_tags

  depends_on = [
    module.rds_superset,
    module.elasticache_redis,
    aws_secretsmanager_secret_version.superset_rds_credentials,
    aws_secretsmanager_secret_version.superset_app_config,
    aws_secretsmanager_secret_version.redis_credentials
  ]
}

# checkov:skip=CKV_AWS_51: Superset uses 'latest' tag (deployment workflow requirement)
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# ECS Cluster and Service
module "ecs_dbt" {
  source = "./modules/ecs-dbt"

  service_name          = var.service_name
  container_name        = var.container_name
  environment           = var.environment
  project_name          = var.project_name
  image_uri             = "${module.ecr.dbt_repository_url}:${var.image_tag}"
  task_cpu              = var.task_cpu
  task_memory           = var.task_memory
  execution_role_arn    = module.iam.ecs_execution_role_arn
  task_role_arn         = module.iam.ecs_task_role_arn
  environment_variables = var.ecs_environment_variables
  tags                  = local.common_tags

  # Secrets integration
  database_secret_name = module.secrets.snowflake_dbt_credentials_secret_name
}

module "monitoring" {
  source = "./modules/monitoring"

  environment  = var.environment
  project_name = var.project_name

  # ECS services to monitor
  ecs_service_names = [
    "${var.project_name}-${var.environment}-airflow-webserver",
    "${var.project_name}-${var.environment}-airflow-scheduler",
    "${var.project_name}-${var.environment}-superset",
    "${var.service_name}-${var.environment}"
  ]

  # Log groups for centralized management
  log_group_names = [
    "/ecs/${var.project_name}-${var.environment}-airflow",
    "/ecs/${var.project_name}-${var.environment}-superset",
    "/ecs/${var.project_name}-${var.environment}-${var.service_name}"
  ]

  # Pass direct module reference for S3 bucket
  data_lake_bucket_id = module.s3_data_lake.data_lake_bucket_id

  tags = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  service_name = var.service_name
  service_type = "dbt"
  environment  = var.environment
  project_name = var.project_name
  common_tags  = local.common_tags

  # Pass direct module references for secrets
  snowflake_credentials_secret_arn = module.secrets.snowflake_dbt_credentials_secret_arn

  # Pass direct module references for S3 buckets
  data_lake_bucket_arn      = module.s3_data_lake.data_lake_bucket_arn
  processed_data_bucket_arn = module.s3_data_lake.processed_data_bucket_arn
  artifacts_bucket_arn      = module.s3_data_lake.artifacts_bucket_arn

  # Dependencies - ensure other modules are created first
  depends_on = [
    module.s3_data_lake,
    module.secrets
  ]
}
