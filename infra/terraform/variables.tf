# ── Global ────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as a prefix for all resource names"
  type        = string
  default     = "todo"
}

variable "environment" {
  description = "Deployment environment (dev | prod)"
  type        = string
}

# ── VPC ───────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — one per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets — one per AZ"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "AZs to distribute subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ── EKS ───────────────────────────────────────────────────────────────────────

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "todo-tf-cluster-dev"
}

variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  type    = number
  default = 2
}

variable "eks_node_min_size" {
  type    = number
  default = 2
}

variable "eks_node_max_size" {
  type    = number
  default = 4
}

# ── ECR ───────────────────────────────────────────────────────────────────────

variable "ecr_frontend_repo_name" {
  description = "ECR frontend repository name"
  type        = string
  default     = "todo-frontend"
}

variable "ecr_backend_repo_name" {
  description = "ECR backend repository name"
  type        = string
  default     = "todo-backend"
}

variable "ecr_image_retention_count" {
  description = "Number of tagged images to retain"
  type        = number
  default     = 10
}

# ── RDS ───────────────────────────────────────────────────────────────────────

variable "rds_identifier" {
  description = "RDS instance identifier"
  type        = string
  default     = "todo-db"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_db_name" {
  description = "MySQL database name"
  type        = string
  default     = "todo_db"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "todo_user"
}

variable "rds_password" {
  description = "RDS master password — use a secrets manager in production"
  type        = string
  sensitive   = true
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20
}

variable "rds_backup_retention_days" {
  description = "Automated backup retention period"
  type        = number
  default     = 7
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Prevent accidental deletion of the RDS instance"
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot on destroy (set false for prod)"
  type        = bool
  default     = true
}

# ── Redis ─────────────────────────────────────────────────────────────────────

variable "redis_cluster_id" {
  description = "ElastiCache replication group ID"
  type        = string
  default     = "todo-redis"
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes (1 = single-node, >1 enables automatic failover)"
  type        = number
  default     = 1
}

# ── Route53 ───────────────────────────────────────────────────────────────────

variable "domain_name" {
  description = "Root domain name managed in Route53"
  type        = string
  default     = "ankit.services"
}

variable "subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = "www"
}

# ── S3 ────────────────────────────────────────────────────────────────────────

variable "s3_bucket_name" {
  description = "S3 bucket name for application assets (must be globally unique)"
  type        = string
}

# ── CloudWatch ────────────────────────────────────────────────────────────────

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 30
}

# ALB

variable "certificate_arn" {
  description = "ARN of the certificate generated but SSL"
  type = string
  default = ""
}

# ── ASG ───────────────────────────────────────────────────────────────────────

variable "asg_target_cpu_utilization" {
  description = "Target CPU utilization % for the node group ASG scaling policy"
  type        = number
  default     = 60
}

#Route53-Jenkins

variable "jenkins_subdomain" {
  description = "Subdomain for Jenkins"
  type        = string
  default     = "jenkins"
}

variable "jenkins_alb_name" {
  description = "Name of the Jenkins ALB created by AWS Load Balancer Controller"
  type        = string
}