output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN — used to create additional IRSA roles"
  value       = module.eks.oidc_provider_arn
}

output "eks_alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller service account"
  value       = module.eks.alb_controller_role_arn
}

output "ecr_frontend_repository_url" {
  description = "ECR frontend repository URL"
  value       = module.ecr_frontend.repository_url
}

output "ecr_backend_repository_url" {
  description = "ECR backend repository URL"
  value       = module.ecr_backend.repository_url
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "redis_primary_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = module.redis.primary_endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.s3.bucket_name
}

output "cloudwatch_eks_log_group" {
  description = "CloudWatch log group for EKS cluster logs"
  value       = module.cloudwatch.eks_log_group_name
}

output "app_url" {
  description = "Application URL"
  value       = "https://${var.subdomain}.${var.domain_name}"
}

output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "ALB canonical hosted zone ID"
  value       = module.alb.alb_zone_id
}

output "frontend_tg_arn" {
  description = "Frontend target group ARN"
  value       = module.alb.frontend_tg_arn
}

output "backend_tg_arn" {
  description = "Backend target group ARN"
  value       = module.alb.backend_tg_arn
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for the Cluster Autoscaler service account"
  value       = module.autoscalling.cluster_autoscaler_role_arn
}

output "asg_name" {
  description = "EKS node group Auto Scaling Group name"
  value       = module.asg.asg_name
}