output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.superset.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.superset.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.superset.name
}

output "service_name" {
  description = "Name of the Superset ECS service"
  value       = aws_ecs_service.superset.name
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer (empty if ALB disabled)"
  value       = var.enable_load_balancer ? aws_lb.superset[0].dns_name : ""
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer (empty if ALB disabled)"
  value       = var.enable_load_balancer ? aws_lb.superset[0].zone_id : ""
}

output "port_forward_instructions" {
  description = "Instructions for accessing Superset when ALB is disabled"
  value = var.enable_load_balancer ? "" : join("\n", [
    "To access Superset without ALB, use AWS CLI to port forward:",
    "1. List running tasks: aws ecs list-tasks --cluster ${aws_ecs_cluster.superset.name} --service-name ${aws_ecs_service.superset.name}",
    "2. Port forward: aws ecs execute-command --cluster ${aws_ecs_cluster.superset.name} --task <TASK_ARN> --container superset --interactive --command '/bin/sh'",
    "3. Or use AWS Systems Manager Session Manager to access the container",
    "4. Access Superset on http://localhost:8088 after port forwarding"
  ])
}
