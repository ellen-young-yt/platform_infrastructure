output "redis_endpoint" {
  description = "Redis primary endpoint address"
  value       = var.num_cache_nodes > 1 ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : aws_elasticache_cluster.redis[0].cache_nodes[0].address
}

output "redis_port" {
  description = "Redis port"
  value       = var.port
}

output "redis_connection_string" {
  description = "Redis connection string (without auth token)"
  value       = var.transit_encryption_enabled ? "rediss://${var.num_cache_nodes > 1 ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : aws_elasticache_cluster.redis[0].cache_nodes[0].address}:${var.port}" : "redis://${var.num_cache_nodes > 1 ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : aws_elasticache_cluster.redis[0].cache_nodes[0].address}:${var.port}"
  sensitive   = false
}

output "redis_security_group_id" {
  description = "ID of the Redis security group"
  value       = aws_security_group.redis.id
}

output "redis_subnet_group_name" {
  description = "Name of the Redis subnet group"
  value       = aws_elasticache_subnet_group.redis.name
}

output "auth_token" {
  description = "Redis authentication token (password)"
  value       = var.auth_token_enabled ? random_password.redis_auth_token[0].result : null
  sensitive   = true
}

output "cluster_id" {
  description = "Redis cluster ID"
  value       = var.num_cache_nodes > 1 ? aws_elasticache_replication_group.redis[0].id : aws_elasticache_cluster.redis[0].id
}

output "cluster_arn" {
  description = "Redis cluster ARN"
  value       = var.num_cache_nodes > 1 ? aws_elasticache_replication_group.redis[0].arn : aws_elasticache_cluster.redis[0].arn
}
