output "dbt_repository_url" {
  description = "The URL of the DBT ECR repository"
  value       = aws_ecr_repository.dbt_project.repository_url
}

output "dbt_repository_arn" {
  description = "The ARN of the DBT ECR repository"
  value       = aws_ecr_repository.dbt_project.arn
}

output "dbt_repository_name" {
  description = "The name of the DBT ECR repository"
  value       = aws_ecr_repository.dbt_project.name
}

output "superset_repository_url" {
  description = "The URL of the Superset ECR repository"
  value       = aws_ecr_repository.superset.repository_url
}

output "superset_repository_arn" {
  description = "The ARN of the Superset ECR repository"
  value       = aws_ecr_repository.superset.arn
}

output "superset_repository_name" {
  description = "The name of the Superset ECR repository"
  value       = aws_ecr_repository.superset.name
}

output "airflow_repository_url" {
  description = "The URL of the Airflow ECR repository"
  value       = aws_ecr_repository.airflow.repository_url
}

output "airflow_repository_arn" {
  description = "The ARN of the Airflow ECR repository"
  value       = aws_ecr_repository.airflow.arn
}

output "airflow_repository_name" {
  description = "The name of the Airflow ECR repository"
  value       = aws_ecr_repository.airflow.name
}
