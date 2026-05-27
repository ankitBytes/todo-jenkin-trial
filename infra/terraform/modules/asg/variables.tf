variable "project_name" { type = string }
variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "node_group_name" { type = string }
variable "target_cpu_utilization" {
  description = "Target CPU % to maintain across the node group"
  type        = number
  default     = 75
}