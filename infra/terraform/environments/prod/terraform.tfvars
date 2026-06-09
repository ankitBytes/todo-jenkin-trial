# ── Global ────────────────────────────────────────────────────────────────────
aws_region   = "us-east-1"
project_name = "todo"
environment  = "prod"

# ── VPC ───────────────────────────────────────────────────────────────────────
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# ── EKS ───────────────────────────────────────────────────────────────────────
eks_cluster_name        = "todo-tf-cluster-prod"
eks_kubernetes_version  = "1.30"
eks_node_instance_types = ["t3.large"]
eks_node_desired_size   = 2
eks_node_min_size       = 2
eks_node_max_size       = 6

# ── ECR ───────────────────────────────────────────────────────────────────────
ecr_frontend_repo_name    = "todo-frontend-prod"
ecr_backend_repo_name     = "todo-backend-prod"
ecr_image_retention_count = 10

# ── RDS ───────────────────────────────────────────────────────────────────────
rds_identifier            = "todo-db"
rds_instance_class        = "db.t3.small"
rds_db_name               = "todo_db"
rds_username              = "todo_user"
rds_allocated_storage     = 50
rds_backup_retention_days = 7
rds_multi_az              = true
rds_deletion_protection   = true
rds_skip_final_snapshot   = false

# ── Redis ─────────────────────────────────────────────────────────────────────
redis_cluster_id      = "todo-redis"
redis_node_type       = "cache.t3.micro"
redis_engine_version  = "7.1"
redis_num_cache_nodes = 1

# ── Route53 ───────────────────────────────────────────────────────────────────
domain_name = "ankit.services"
subdomain   = "www"

# ── S3 ────────────────────────────────────────────────────────────────────────
s3_bucket_name = "todo-assets-prod-668076964228"

# ── CloudWatch ────────────────────────────────────────────────────────────────
cloudwatch_log_retention_days = 30

# ── ALB ───────────────────────────────────────────────────────────────────────
certificate_arn = "arn:aws:acm:us-east-1:668076964228:certificate/e4a2f397-c129-4501-b3bd-b4ab9d6f22d7"

# ── EKS API endpoint access ───────────────────────────────────────────────────
# IMPORTANT: Replace with your office/VPN CIDR before going live.
# Leaving as 0.0.0.0/0 exposes the Kubernetes API server to the internet.
eks_public_access_cidrs = ["0.0.0.0/0"]

# ── Jenkins (shared, same as dev) ─────────────────────────────────────────────
jenkins_alb_dns_name = "k8s-jenkins-jenkins-8be750d9ed-1656756647.us-east-1.elb.amazonaws.com"
jenkins_alb_zone_id  = "Z35SXDOTRQ7X7K"

# ── Monitoring ────────────────────────────────────────────────────────────────
# Set via: export TF_VAR_grafana_admin_password=...
grafana_subdomain  = "grafana"
create_apex_record    = false
create_grafana_record = true
