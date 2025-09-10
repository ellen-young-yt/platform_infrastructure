output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.airflow.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.airflow.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.airflow.name
}

output "webserver_service_name" {
  description = "Name of the Airflow webserver service"
  value       = aws_ecs_service.airflow_webserver.name
}

output "scheduler_service_name" {
  description = "Name of the Airflow scheduler service"
  value       = aws_ecs_service.airflow_scheduler.name
}

output "task_role_arn" {
  description = "ARN of the Airflow task IAM role"
  value       = aws_iam_role.airflow_task.arn
}

output "execution_role_arn" {
  description = "ARN of the Airflow execution IAM role"
  value       = aws_iam_role.airflow_execution.arn
}
