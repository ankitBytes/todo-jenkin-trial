locals {
  name = "${var.project_name}-${var.environment}"
}

data "aws_autoscaling_groups" "eks_nodes" {
  filter {
    name   = "tag:eks:cluster-name"
    values = [var.cluster_name]
  }

  filter {
    name   = "tag:eks:nodegroup-name"
    values = [var.node_group_name]
  }
}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${local.name}-cpu-target-tracking"
  autoscaling_group_name = data.aws_autoscaling_groups.eks_nodes.names[0]
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}
