# ── Jenkins IRSA Role ─────────────────────────────────────────────────────────
resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-${var.environment}-jenkins-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_issuer_host}:sub" = "system:serviceaccount:jenkins:jenkins"
          "${module.eks.oidc_issuer_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-jenkins-irsa-role" }
}

resource "aws_iam_policy" "jenkins_aws_services" {
  name        = "${var.project_name}-${var.environment}-jenkins-aws-services-policy"
  description = "Jenkins pipeline: consolidated AWS service permissions for Terraform-managed infrastructure."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "rds:*",
          "elasticache:*",
          "secretsmanager:*",
          "logs:*",
          "cloudwatch:*",
          "route53:*",
          "elasticloadbalancing:*",
          "s3:*",
          "acm:*",
          "autoscaling:*",
          "ecr:*",
          "ecr-public:*",
          "iam:GetPolicy",
          "iam:ListPolicies",
          "iam:ListInstanceProfiles",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_aws_services" {
  policy_arn = aws_iam_policy.jenkins_aws_services.arn
  role       = aws_iam_role.jenkins.name
}

# ── Custom policy: EKS management + IAM scoped to project prefix ──────────────
# Replaces IAMFullAccess. Prevents creating users/access keys (the main
# account-takeover vector). Role/policy creation is limited to todo-* prefix.

resource "aws_iam_policy" "jenkins_eks_iam" {
  name        = "${var.project_name}-${var.environment}-jenkins-eks-iam-policy"
  description = "Jenkins pipeline: EKS management + IAM scoped to ${var.project_name}-* resources. No user/key creation."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EKS cluster and add-on management
      {
        Effect = "Allow"
        Action = [
          "eks:CreateCluster", "eks:DeleteCluster", "eks:DescribeCluster",
          "eks:ListClusters", "eks:UpdateClusterConfig", "eks:UpdateClusterVersion",
          "eks:CreateNodegroup", "eks:DeleteNodegroup", "eks:DescribeNodegroup",
          "eks:UpdateNodegroupConfig", "eks:UpdateNodegroupVersion", "eks:ListNodegroups",
          "eks:CreateAddon", "eks:DeleteAddon", "eks:DescribeAddon",
          "eks:DescribeAddonVersions", "eks:UpdateAddon", "eks:ListAddons",
          "eks:TagResource", "eks:UntagResource", "eks:ListTagsForResource",
          "eks:DescribeUpdate", "eks:ListUpdates",
          "eks:AssociateIdentityProviderConfig", "eks:DisassociateIdentityProviderConfig",
          "eks:DescribeIdentityProviderConfig", "eks:ListIdentityProviderConfigs"
        ]
        Resource = "*"
      },
      # IAM roles — scoped to project prefix
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
          "iam:ListRoles", "iam:TagRole", "iam:UntagRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:UpdateAssumeRolePolicy",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies"
        ]
        Resource = "arn:aws:iam::*:role/${var.project_name}-*"
      },
      # IAM policies — scoped to project prefix
      {
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy",
          "iam:GetPolicyVersion", "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
          "iam:TagPolicy", "iam:UntagPolicy", "iam:ListEntitiesForPolicy"
        ]
        Resource = "arn:aws:iam::*:policy/${var.project_name}-*"
      },
      # OIDC providers — required for IRSA configuration
      {
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider", "iam:ListOpenIDConnectProviders",
          "iam:TagOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint"
        ]
        Resource = "arn:aws:iam::*:oidc-provider/*"
      },
      # PassRole — restricted to project-prefix roles and specific services
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::*:role/${var.project_name}-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "eks.amazonaws.com",
              "ec2.amazonaws.com",
              "rds.amazonaws.com",
              "elasticache.amazonaws.com"
            ]
          }
        }
      },
      # Service-linked roles (needed by EC2/EKS/RDS to self-provision)
      {
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "arn:aws:iam::*:role/aws-service-role/*"
      },
      # Caller identity + Terraform state lock metadata
      {
        Effect   = "Allow"
        Action   = ["iam:GetUser", "sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_eks_iam" {
  policy_arn = aws_iam_policy.jenkins_eks_iam.arn
  role       = aws_iam_role.jenkins.name
}

output "jenkins_irsa_role_arn" {
  description = "Paste this ARN into jenkins-values.yaml serviceAccount.annotations"
  value       = aws_iam_role.jenkins.arn
}
