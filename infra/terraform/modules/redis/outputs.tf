output "primary_endpoint" {
  description = "Redis primary endpoint address"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
  sensitive   = true
}

output "reader_endpoint" {
  description = "Redis reader endpoint address (same as primary for single-node)"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
  sensitive   = true
}

output "port" {
  value = aws_elasticache_replication_group.main.port
}

output "replication_group_id" {
  value = aws_elasticache_replication_group.main.id
}
