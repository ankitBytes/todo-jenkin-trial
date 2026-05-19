output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — use to create additional IRSA roles"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_issuer_url" {
  value = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "alb_controller_role_arn" { 
  description = "Annotate the aws-load-balancer-controller ServiceAccount with this ARN"
  value       = aws_iam_role.alb_controller.arn
}

output "node_group_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "node_group_name" {
  value = aws_eks_node_group.main.node_group_name
}

output "cluster_security_group_id" {
  description = "Auto-created EKS cluster security group ID"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "oidc_issuer_host" {
  description = "OIDC issuer hostname — used to build IRSA trust policy conditions"
  value       = local.oidc_issuer_host
}
