variable "project_name" { type = string }
variable "environment" { type = string }
variable "domain_name" { type = string }
variable "subdomain" { type = string }
variable "alb_dns_name" { type = string }
variable "alb_zone_id" { type = string }
variable "jenkins_subdomain" { type = string }
variable "jenkins_alb_dns_name" { type = string }
variable "jenkins_alb_zone_id" { type = string }
variable "grafana_subdomain" {
  type    = string
  default = "grafana"
}
variable "grafana_alb_dns_name" { type = string }
variable "grafana_alb_zone_id" { type = string }
