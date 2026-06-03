# Looks up the hosted zone that must already exist in Route53.
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "apex" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.jenkins_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.jenkins_alb_dns_name
    zone_id                = var.jenkins_alb_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "grafana" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.grafana_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.grafana_alb_dns_name
    zone_id                = var.grafana_alb_zone_id
    evaluate_target_health = true
  }
}
