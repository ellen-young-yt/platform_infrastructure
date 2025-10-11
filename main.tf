
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
  snowflake_credentials_secret_arn = module.secrets.snowflake_credentials_secret_arn

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
  snowflake_credentials_secret_arn = module.secrets.snowflake_credentials_secret_arn

  # Pass direct module references for S3 buckets
  data_lake_bucket_arn      = module.s3_data_lake.data_lake_bucket_arn
  processed_data_bucket_arn = module.s3_data_lake.processed_data_bucket_arn
  artifacts_bucket_arn      = module.s3_data_lake.artifacts_bucket_arn

  depends_on = [module.s3_data_lake, module.secrets]
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

  # Resource configuration from environment variables
  webserver_cpu    = var.task_cpu
  webserver_memory = var.task_memory
  scheduler_cpu    = var.task_cpu
  scheduler_memory = var.task_memory

  tags = local.common_tags
}

# IAM for Metabase
module "iam_metabase" {
  source = "./modules/iam"

  service_name = "metabase"
  service_type = "metabase"
  environment  = var.environment
  project_name = var.project_name
  common_tags  = local.common_tags

  # Pass direct module references for secrets
  snowflake_credentials_secret_arn = module.secrets.snowflake_credentials_secret_arn

  # Pass direct module references for S3 buckets
  data_lake_bucket_arn      = module.s3_data_lake.data_lake_bucket_arn
  processed_data_bucket_arn = module.s3_data_lake.processed_data_bucket_arn
  artifacts_bucket_arn      = module.s3_data_lake.artifacts_bucket_arn

  depends_on = [module.secrets]
}

module "ecs_metabase" {
  source = "./modules/ecs-metabase"

  environment           = var.environment
  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id

  # Use centralized IAM roles
  execution_role_arn = module.iam_metabase.ecs_execution_role_arn
  task_role_arn      = module.iam_metabase.ecs_task_role_arn

  # Configuration from environment variables
  enable_load_balancer = var.enable_deletion_protection # Use same logic as ALB protection

  # Resource configuration
  cpu           = var.task_cpu
  memory        = var.task_memory
  desired_count = var.desired_count

  tags = local.common_tags
}

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
  database_secret_name = module.secrets.snowflake_credentials_secret_name
}

module "monitoring" {
  source = "./modules/monitoring"

  environment  = var.environment
  project_name = var.project_name

  # ECS services to monitor
  ecs_service_names = [
    "${var.project_name}-${var.environment}-airflow-webserver",
    "${var.project_name}-${var.environment}-airflow-scheduler",
    "${var.project_name}-${var.environment}-metabase",
    "${var.service_name}-${var.environment}"
  ]

  # Log groups for centralized management
  log_group_names = [
    "/ecs/${var.project_name}-${var.environment}-airflow",
    "/ecs/${var.project_name}-${var.environment}-metabase",
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
  snowflake_credentials_secret_arn = module.secrets.snowflake_credentials_secret_arn

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
