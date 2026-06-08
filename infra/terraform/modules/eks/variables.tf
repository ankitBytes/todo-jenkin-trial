variable "project_name" { type = string }
variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "kubernetes_version" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "node_instance_types" { type = list(string) }
variable "node_desired_size" { type = number }
variable "node_min_size" { type = number }
variable "node_max_size" { type = number }
variable "node_security_group_id" { type = string }

variable "public_access_cidrs" {
  description = "CIDR blocks permitted to reach the public EKS API endpoint. Restrict to office/VPN CIDRs in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
