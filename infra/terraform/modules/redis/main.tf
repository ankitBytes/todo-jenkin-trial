locals {
  name = "${var.project_name}-${var.environment}"
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.name}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "${local.name}-redis-subnet-group" }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = var.cluster_id
  description          = "${var.project_name} ${var.environment} Redis cache"

  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_nodes
  engine_version       = var.engine_version
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.security_group_id]

  # Disable automatic failover for single-node setups (requires >= 2 nodes)
  automatic_failover_enabled = var.num_cache_nodes > 1

  at_rest_encryption_enabled = true
  # NOTE: Changing this on an existing cluster forces replacement (ElastiCache
  # does not support in-place encryption changes). Plan a maintenance window.
  transit_encryption_enabled = true

  apply_immediately = true

  tags = { Name = var.cluster_id }
}
