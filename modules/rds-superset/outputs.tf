output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.superset.id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.superset.arn
}

output "db_instance_endpoint" {
  description = "Connection endpoint for the database"
  value       = aws_db_instance.superset.endpoint
}

output "db_instance_address" {
  description = "Address of the RDS instance"
  value       = aws_db_instance.superset.address
}

output "db_instance_port" {
  description = "Port the database is listening on"
  value       = aws_db_instance.superset.port
}

output "db_name" {
  description = "Name of the database"
  value       = aws_db_instance.superset.db_name
}

output "db_username" {
  description = "Master username for the database"
  value       = aws_db_instance.superset.username
  sensitive   = true
}

output "db_password" {
  description = "Master password for the database"
  value       = random_password.db_password.result
  sensitive   = true
}

output "db_connection_string" {
  description = "PostgreSQL connection string for Superset"
  value       = "postgresql://${aws_db_instance.superset.username}:${random_password.db_password.result}@${aws_db_instance.superset.endpoint}/${aws_db_instance.superset.db_name}"
  sensitive   = true
}
