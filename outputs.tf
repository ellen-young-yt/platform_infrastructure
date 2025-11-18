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

output "superset_cluster_arn" {
  description = "ARN of the Superset ECS cluster"
  value       = module.ecs_superset.cluster_arn
}

output "superset_alb_dns_name" {
  description = "DNS name of the Superset Application Load Balancer"
  value       = module.ecs_superset.load_balancer_dns_name
}

output "superset_url" {
  description = "URL to access Superset UI"
  value       = module.ecs_superset.load_balancer_dns_name != "" ? "http://${module.ecs_superset.load_balancer_dns_name}" : "ALB not enabled"
}

output "superset_rds_endpoint" {
  description = "Endpoint of the Superset RDS database"
  value       = module.rds_superset.db_instance_endpoint
  sensitive   = true
}

output "superset_rds_instance_id" {
  description = "ID of the Superset RDS instance"
  value       = module.rds_superset.db_instance_id
}

output "superset_init_task_arn" {
  description = "ARN of the Superset initialization task definition"
  value       = module.ecs_superset.init_task_definition_arn
}

output "superset_ecr_repository_url" {
  description = "URL of the Superset ECR repository"
  value       = module.ecr.superset_repository_url
}

output "superset_ecr_repository_name" {
  description = "Name of the Superset ECR repository"
  value       = module.ecr.superset_repository_name
}

output "superset_init_instructions" {
  description = "Instructions for initializing Superset database"
  value       = <<-EOT
    To initialize the Superset database, run the following command:

    aws ecs run-task \
      --cluster ${module.ecs_superset.cluster_name} \
      --task-definition ${module.ecs_superset.init_task_definition_family} \
      --launch-type FARGATE \
      --network-configuration "awsvpcConfiguration={subnets=[${join(",", module.networking.public_subnet_ids)}],securityGroups=[${module.networking.ecs_security_group_id}],assignPublicIp=ENABLED}"

    Then monitor the logs:
    aws logs tail /ecs/${var.project_name}-${var.environment}-superset --follow --filter-pattern "superset-init"

    Default admin credentials:
    - Username: admin
    - Password: admin
    - URL: ${module.ecs_superset.load_balancer_dns_name != "" ? "http://${module.ecs_superset.load_balancer_dns_name}" : "See port_forward_instructions output"}

    IMPORTANT: Change the admin password after first login!
  EOT
}

output "superset_docker_build_instructions" {
  description = "Instructions for building and pushing custom Superset Docker image"
  value       = <<-EOT
    To build and push the custom Superset Docker image:

    1. Authenticate to ECR:
       aws ecr get-login-password --region ${var.aws_region} | \
         docker login --username AWS --password-stdin ${module.ecr.superset_repository_url}

    2. Build the image:
       cd docker
       docker build -t ${module.ecr.superset_repository_name}:latest .

    3. Tag the image:
       docker tag ${module.ecr.superset_repository_name}:latest ${module.ecr.superset_repository_url}:latest

    4. Push to ECR:
       docker push ${module.ecr.superset_repository_url}:latest

    5. Update ECS service to use new image (if task definition references :latest):
       aws ecs update-service \
         --cluster ${module.ecs_superset.cluster_name} \
         --service ${var.project_name}-${var.environment}-superset \
         --force-new-deployment
  EOT
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

# Redis Outputs
output "redis_endpoint" {
  description = "Redis primary endpoint address"
  value       = module.elasticache_redis.redis_endpoint
}

output "redis_port" {
  description = "Redis port"
  value       = module.elasticache_redis.redis_port
}

output "redis_cluster_id" {
  description = "Redis cluster ID"
  value       = module.elasticache_redis.cluster_id
}

output "redis_connection_info" {
  description = "Redis connection information"
  value = {
    endpoint          = module.elasticache_redis.redis_endpoint
    port              = module.elasticache_redis.redis_port
    ssl_enabled       = true
    connection_string = module.elasticache_redis.redis_connection_string
  }
  sensitive = true
}
