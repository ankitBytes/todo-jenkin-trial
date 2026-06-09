resource "random_password" "rds" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "grafana" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "infra_passwords" {
  name                    = "${var.project_name}-${var.environment}-infra-passwords"
  description             = "Auto-generated admin passwords for ${var.project_name}-${var.environment}"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.project_name}-${var.environment}-infra-passwords" }
}

resource "aws_secretsmanager_secret_version" "infra_passwords" {
  secret_id = aws_secretsmanager_secret.infra_passwords.id
  secret_string = jsonencode({
    rds_password           = random_password.rds.result
    grafana_admin_password = random_password.grafana.result
  })
}

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  eks_cluster_name     = var.eks_cluster_name
}

module "security_groups" {
  source = "./modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name       = var.project_name
  environment        = var.environment
  eks_cluster_name   = var.eks_cluster_name
  log_retention_days = var.cloudwatch_log_retention_days
}

module "ecr_frontend" {
  source = "./modules/ecr"

  project_name          = var.project_name
  environment           = var.environment
  repo_name             = var.ecr_frontend_repo_name
  image_retention_count = var.ecr_image_retention_count
}

module "ecr_backend" {
  source = "./modules/ecr"

  project_name          = var.project_name
  environment           = var.environment
  repo_name             = var.ecr_backend_repo_name
  image_retention_count = var.ecr_image_retention_count
}

module "eks" {
  source = "./modules/eks"

  project_name           = var.project_name
  environment            = var.environment
  cluster_name           = var.eks_cluster_name
  kubernetes_version     = var.eks_kubernetes_version
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  node_instance_types    = var.eks_node_instance_types
  node_desired_size      = var.eks_node_desired_size
  node_min_size          = var.eks_node_min_size
  node_max_size          = var.eks_node_max_size
  node_security_group_id = module.security_groups.eks_node_sg_id
  public_access_cidrs    = var.eks_public_access_cidrs

  depends_on = [module.cloudwatch]
}

resource "helm_release" "secrets_store_csi_driver" {
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.4.4"
  set {
    name  = "syncSecret.enabled"
    value = "true"
  }
  set {
    name  = "enableSecretRotation"
    value = "true"
  }
  depends_on = [module.eks]
}

resource "helm_release" "aws_secrets_manager_csi_provider" {
  name       = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "0.3.9"
  depends_on = [helm_release.secrets_store_csi_driver]
}

module "rds" {
  source = "./modules/rds"

  project_name        = var.project_name
  environment         = var.environment
  identifier          = var.rds_identifier
  instance_class      = var.rds_instance_class
  db_name             = var.rds_db_name
  username            = var.rds_username
  password            = random_password.rds.result
  allocated_storage   = var.rds_allocated_storage
  backup_retention    = var.rds_backup_retention_days
  multi_az            = var.rds_multi_az
  deletion_protection = var.rds_deletion_protection
  skip_final_snapshot = var.rds_skip_final_snapshot
  private_subnet_ids  = module.vpc.private_subnet_ids
  security_group_id   = module.security_groups.rds_sg_id
}

module "redis" {
  source = "./modules/redis"

  project_name       = var.project_name
  environment        = var.environment
  cluster_id         = var.redis_cluster_id
  node_type          = var.redis_node_type
  engine_version     = var.redis_engine_version
  num_cache_nodes    = var.redis_num_cache_nodes
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id  = module.security_groups.redis_sg_id
}

module "secrets_manager" {
  source = "./modules/secrets-manager"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  account_id        = data.aws_caller_identity.current.account_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_host  = module.eks.oidc_issuer_host

  db_host     = module.rds.address
  db_port     = "3306"
  db_user     = var.rds_username
  db_password = random_password.rds.result
  db_name     = var.rds_db_name
  redis_host  = module.redis.primary_endpoint
  redis_port  = "6379"

  depends_on = [module.rds, module.redis, module.eks]
}

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
  bucket_name  = var.s3_bucket_name
}

module "route53" {
  source = "./modules/route53"

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name
  subdomain    = var.subdomain
  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id

  jenkins_subdomain    = var.jenkins_subdomain
  jenkins_alb_dns_name = var.jenkins_alb_dns_name
  jenkins_alb_zone_id  = var.jenkins_alb_zone_id

  grafana_subdomain    = var.grafana_subdomain
  grafana_alb_dns_name = try(data.kubernetes_ingress_v1.grafana.status[0].load_balancer[0].ingress[0].hostname, "")
  grafana_alb_zone_id  = "Z35SXDOTRQ7X7K"

  create_apex_record = var.create_apex_record
}

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  vpc_id            = module.vpc.vpc_id
  certificate_arn   = var.certificate_arn

  depends_on = [module.security_groups, module.vpc]
}

module "asg" {
  source = "./modules/asg"

  project_name           = var.project_name
  environment            = var.environment
  cluster_name           = var.eks_cluster_name
  node_group_name        = module.eks.node_group_name
  target_cpu_utilization = var.asg_target_cpu_utilization

  depends_on = [module.eks]
}

module "autoscalling" {
  source = "./modules/autoscalling"

  project_name      = var.project_name
  environment       = var.environment
  cluster_name      = var.eks_cluster_name
  aws_region        = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_host  = module.eks.oidc_issuer_host

  depends_on = [module.eks]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "58.7.2"

  disable_openapi_validation = true
  wait                       = false

  set {
    name  = "grafana.adminPassword"
    value = random_password.grafana.result
  }
  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }
  set {
    name  = "grafana.ingress.ingressClassName"
    value = "alb"
  }
  set {
    name  = "grafana.ingress.hosts[0]"
    value = "${var.grafana_subdomain}.${var.domain_name}"
  }
  set {
    name  = "grafana.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }
  values = [<<-EOT
    grafana:
      ingress:
        annotations:
          alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
          alb.ingress.kubernetes.io/certificate-arn: "${var.certificate_arn}"
          alb.ingress.kubernetes.io/ssl-redirect: "443"
  EOT
  ]
  set {
    name  = "grafana.sidecar.dashboards.enabled"
    value = "true"
  }
  set {
    name  = "grafana.sidecar.dashboards.label"
    value = "grafana_dashboard"
  }
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }
  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  depends_on = [module.eks]
}

resource "time_sleep" "wait_for_grafana_alb" {
  depends_on      = [helm_release.kube_prometheus_stack]
  create_duration = "300s"
}

data "kubernetes_ingress_v1" "grafana" {
  depends_on = [time_sleep.wait_for_grafana_alb]
  metadata {
    name      = "kube-prometheus-stack-grafana"
    namespace = "monitoring"
  }
}
