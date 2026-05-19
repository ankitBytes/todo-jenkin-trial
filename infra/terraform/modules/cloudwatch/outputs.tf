output "eks_log_group_name" {
  value = aws_cloudwatch_log_group.eks_cluster.name
}

output "eks_log_group_arn" {
  value = aws_cloudwatch_log_group.eks_cluster.arn
}

output "app_log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}

output "backend_log_group_name" {
  value = aws_cloudwatch_log_group.app_backend.name
}

output "frontend_log_group_name" {
  value = aws_cloudwatch_log_group.app_frontend.name
}
