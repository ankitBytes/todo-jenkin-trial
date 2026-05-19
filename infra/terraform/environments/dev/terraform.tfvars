#Global
aws_region   = "us-east-1"
project_name = "todo"
environment  = "dev"

#VPC
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

#EKS
eks_cluster_name        = "todo-tf-cluster-dev"
eks_kubernetes_version  = "1.30"
eks_node_instance_types = ["t3.medium"]
eks_node_desired_size   = 2
eks_node_min_size       = 1
eks_node_max_size       = 3

#ECR
ecr_frontend_repo_name = "todo-frontend"
ecr_backend_repo_name  = "todo-backend"
ecr_image_retention_count = 5

#RDS
rds_identifier            = "todo-db-dev"
rds_instance_class        = "db.t3.micro"
rds_db_name               = "todo_db"
rds_username              = "todo_user"
rds_password              = "CHANGE_ME_before_apply"   # use: export TF_VAR_rds_password=...
rds_allocated_storage     = 20
rds_backup_retention_days = 3
rds_multi_az              = false
rds_deletion_protection   = false
rds_skip_final_snapshot   = true

#Redis 
redis_cluster_id      = "todo-redis-dev"
redis_node_type       = "cache.t3.micro"
redis_engine_version  = "7.1"
redis_num_cache_nodes = 1

#Route53
domain_name = "ankit.services"
subdomain   = "www"

#S3
s3_bucket_name = "todo-assets-dev-668076964228"

#CloudWatch
cloudwatch_log_retention_days = 14

#ALB
certificate_arn = "arn:aws:acm:us-east-1:668076964228:certificate/e4a2f397-c129-4501-b3bd-b4ab9d6f22d7"
