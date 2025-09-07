output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.metabase.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.metabase.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.metabase.name
}

output "service_name" {
  description = "Name of the Metabase ECS service"
  value       = aws_ecs_service.metabase.name
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer (empty if ALB disabled)"
  value       = var.enable_load_balancer ? aws_lb.metabase[0].dns_name : ""
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer (empty if ALB disabled)"
  value       = var.enable_load_balancer ? aws_lb.metabase[0].zone_id : ""
}

output "port_forward_instructions" {
  description = "Instructions for accessing Metabase when ALB is disabled"
  value = var.enable_load_balancer ? "" : join("\n", [
    "To access Metabase without ALB, use AWS CLI to port forward:",
    "1. List running tasks: aws ecs list-tasks --cluster ${aws_ecs_cluster.metabase.name} --service-name ${aws_ecs_service.metabase.name}",
    "2. Port forward: aws ecs execute-command --cluster ${aws_ecs_cluster.metabase.name} --task <TASK_ARN> --container metabase --interactive --command '/bin/sh'",
    "3. Or use AWS Systems Manager Session Manager to access the container",
    "4. Access Metabase on http://localhost:3000 after port forwarding"
  ])
}

output "task_role_arn" {
  description = "ARN of the Metabase task IAM role"
  value       = aws_iam_role.metabase_task.arn
}

output "execution_role_arn" {
  description = "ARN of the Metabase execution IAM role"
  value       = aws_iam_role.metabase_execution.arn
}