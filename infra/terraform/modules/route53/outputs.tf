output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

output "app_fqdn" {
  description = "Fully qualified domain name of the application"
  value       = "${var.subdomain}.${var.domain_name}"
}

output "record_fqdn" {
  description = "FQDN of the created Route53 A record"
  value       = aws_route53_record.app.fqdn
}
