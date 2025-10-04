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


output "monitoring_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
}

output "ecs_dbt_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_dbt.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_dbt.cluster_arn
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = module.ecs_dbt.task_definition_arn
}

output "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.iam.ecs_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.iam.ecs_task_role_arn
}

output "ecs_dbt_task_definition_arn" {
  description = "ARN of the dbt task definition"
  value       = module.ecs_dbt.task_definition_arn
}

output "ecs_dbt_log_group_name" {
  description = "Name of the dbt CloudWatch log group"
  value       = module.ecs_dbt.log_group_name
}

output "ecs_dbt_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.networking.ecs_security_group_id
}
