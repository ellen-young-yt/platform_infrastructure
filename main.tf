
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
  tags                 = local.common_tags
}

module "ecs_airflow" {
  source = "./modules/ecs-airflow"

  environment           = var.environment
  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id

  # Use smaller resources for dev
  webserver_cpu    = var.environment == "dev" ? 256 : 512
  webserver_memory = var.environment == "dev" ? 512 : 1024
  scheduler_cpu    = var.environment == "dev" ? 256 : 512
  scheduler_memory = var.environment == "dev" ? 512 : 1024

  tags = local.common_tags
}

module "ecs_metabase" {
  source = "./modules/ecs-metabase"

  environment           = var.environment
  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  public_subnet_ids     = module.networking.public_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id

  # Disable ALB for dev environment to save costs
  enable_load_balancer = var.environment == "prod" ? true : false

  # Use smaller resources for dev
  cpu           = var.environment == "dev" ? 256 : 512
  memory        = var.environment == "dev" ? 512 : 1024
  desired_count = var.environment == "dev" ? 1 : 1

  tags = local.common_tags
}

module "lambda_serving" {
  source = "./modules/lambda-serving"

  environment        = var.environment
  project_name       = var.project_name
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  tags = local.common_tags
}

module "monitoring" {
  source = "./modules/monitoring"

  environment  = var.environment
  project_name = var.project_name

  tags = local.common_tags
}
