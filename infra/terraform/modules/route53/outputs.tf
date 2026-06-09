output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

output "app_fqdn" {
  description = "Fully qualified domain name of the application"
  value       = "${var.subdomain}.${var.domain_name}"
}

output "apex_record_fqdn" {
  description = "FQDN of the created apex Route53 A record"
  value       = length(aws_route53_record.apex) > 0 ? aws_route53_record.apex[0].fqdn : var.domain_name
}

output "record_fqdn" {
  description = "FQDN of the created Route53 A record"
  value       = aws_route53_record.app.fqdn
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "https://${var.jenkins_subdomain}.${var.domain_name}"
}
