locals {
  name = "${var.project_name}-${var.environment}"
}

# Pre-created so EKS starts logging immediately on cluster creation.
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.eks_cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = { Name = "${local.name}-eks-cluster-logs" }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/${var.environment}/application"
  retention_in_days = var.log_retention_days

  tags = { Name = "${local.name}-app-logs" }
}

resource "aws_cloudwatch_log_group" "app_backend" {
  name              = "/${var.project_name}/${var.environment}/backend"
  retention_in_days = var.log_retention_days

  tags = { Name = "${local.name}-backend-logs" }
}

resource "aws_cloudwatch_log_group" "app_frontend" {
  name              = "/${var.project_name}/${var.environment}/frontend"
  retention_in_days = var.log_retention_days

  tags = { Name = "${local.name}-frontend-logs" }
}
