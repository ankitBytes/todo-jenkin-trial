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

# ECR: push/pull images built by the pipeline
resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role       = aws_iam_role.jenkins.name
}

# EKS: aws eks update-kubeconfig + kubectl operations
resource "aws_iam_role_policy_attachment" "jenkins_eks_describe" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.jenkins.name
}

# Terraform: manage all infrastructure (PowerUser + IAM for role creation)
resource "aws_iam_role_policy_attachment" "jenkins_poweruser" {
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  role       = aws_iam_role.jenkins.name
}

resource "aws_iam_role_policy_attachment" "jenkins_iam" {
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
  role       = aws_iam_role.jenkins.name
}

output "jenkins_irsa_role_arn" {
  description = "Paste this ARN into jenkins-values.yaml serviceAccount.annotations"
  value       = aws_iam_role.jenkins.arn
}
