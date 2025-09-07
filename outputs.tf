output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "data_lake_bucket_id" {
  description = "ID of the data lake S3 bucket"
  value       = module.s3_data_lake.data_lake_bucket_id
}

output "data_lake_bucket_arn" {
  description = "ARN of the data lake S3 bucket"
  value       = module.s3_data_lake.data_lake_bucket_arn
}

output "snowflake_role_arn" {
  description = "ARN of the Snowflake IAM role"
  value       = module.snowflake_integration.snowflake_role_arn
}

output "airflow_cluster_arn" {
  description = "ARN of the Airflow ECS cluster"
  value       = module.ecs_airflow.cluster_arn
}

output "metabase_cluster_arn" {
  description = "ARN of the Metabase ECS cluster"
  value       = module.ecs_metabase.cluster_arn
}

output "api_gateway_url" {
  description = "URL of the API Gateway for ML model serving"
  value       = module.lambda_serving.api_gateway_url
}

output "monitoring_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
}