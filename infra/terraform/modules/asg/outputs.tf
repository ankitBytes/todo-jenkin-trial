output "asg_name" {
  description = "Name of the EKS node group ASG"
  value       = data.aws_autoscaling_groups.eks_nodes.names[0]
}

output "scaling_policy_arn" {
  description = "ARN of the CPU target tracking scaling policy"
  value       = aws_autoscaling_policy.cpu_target_tracking.arn
}
