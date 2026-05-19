output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for the Cluster Autoscaler service account"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "cluster_autoscaler_policy_arn" {
  description = "IAM policy ARN attached to the Cluster Autoscaler role"
  value       = aws_iam_policy.cluster_autoscaler.arn
}
