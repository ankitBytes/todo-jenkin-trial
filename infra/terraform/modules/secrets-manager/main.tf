locals {
  name        = "${var.project_name}-${var.environment}"
  secret_name = "${local.name}-app-credentials"
}

resource "aws_secretsmanager_secret" "app_credentials" {
  name                    = local.secret_name
  description             = "DB and Redis credentials for ${local.name}"
  recovery_window_in_days = 0
  tags = { Name = local.secret_name }
}

resource "aws_secretsmanager_secret_version" "app_credentials" {
  secret_id = aws_secretsmanager_secret.app_credentials.id
  secret_string = jsonencode({
    DB_HOST     = var.db_host
    DB_PORT     = var.db_port
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password
    DB_NAME     = var.db_name
    REDIS_HOST  = var.redis_host
    REDIS_PORT  = var.redis_port
  })
  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_iam_role" "todo_backend" {
  name = "${local.name}-todo-backend-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_issuer_host}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account}"
          "${var.oidc_issuer_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "secrets_reader" {
  name = "${local.name}-secrets-reader-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = aws_secretsmanager_secret.app_credentials.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "todo_backend_secrets" {
  policy_arn = aws_iam_policy.secrets_reader.arn
  role       = aws_iam_role.todo_backend.name
}