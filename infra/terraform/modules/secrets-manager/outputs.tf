output "secret_arn" { value = aws_secretsmanager_secret.app_credentials.arn }
output "secret_name" { value = aws_secretsmanager_secret.app_credentials.name }
output "backend_role_arn" { value = aws_iam_role.todo_backend.arn }