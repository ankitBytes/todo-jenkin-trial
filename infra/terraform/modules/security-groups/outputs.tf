output "eks_node_sg_id" {
  description = "Security group ID attached to EKS worker nodes"
  value       = aws_security_group.eks_node.id
}

output "rds_sg_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "redis_sg_id" {
  description = "Security group ID for ElastiCache Redis"
  value       = aws_security_group.redis.id
}

output "alb_sg_id" {
  description = "Security group ID for Load Balancer"
  value       = aws_security_group.alb.id
}