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
