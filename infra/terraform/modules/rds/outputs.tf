output "endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "address" {
  description = "RDS instance hostname"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

output "instance_id" {
  value = aws_db_instance.main.id
}
 