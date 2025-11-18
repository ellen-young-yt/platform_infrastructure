output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.airflow.id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.airflow.arn
}

output "db_instance_endpoint" {
  description = "Connection endpoint for the database"
  value       = aws_db_instance.airflow.endpoint
}

output "db_instance_address" {
  description = "Address of the RDS instance"
  value       = aws_db_instance.airflow.address
}

output "db_instance_port" {
  description = "Port the database is listening on"
  value       = aws_db_instance.airflow.port
}

output "db_name" {
  description = "Name of the database"
  value       = aws_db_instance.airflow.db_name
}

output "db_username" {
  description = "Master username for the database"
  value       = aws_db_instance.airflow.username
  sensitive   = true
}

output "db_password" {
  description = "Master password for the database"
  value       = random_password.db_password.result
  sensitive   = true
}

output "db_connection_string" {
  description = "PostgreSQL connection string for Airflow"
  value       = "postgresql://${aws_db_instance.airflow.username}:${random_password.db_password.result}@${aws_db_instance.airflow.endpoint}/${aws_db_instance.airflow.db_name}"
  sensitive   = true
}
