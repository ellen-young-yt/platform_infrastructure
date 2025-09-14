output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.dbt.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.dbt.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.dbt.name
}




output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.dbt.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = local.log_group_name
}
