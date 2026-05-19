output "alb_arn" {
    description = "ARN of the load balancer"
    value = aws_lb.main.arn
}

output "alb_dns_name" {
    description = "DNS name of the load balancer"
    value = aws_lb.main.dns_name
}

output "alb_zone_id" {
    description = "Canonical hosted zone ID of the ALB"
    value = aws_lb.main.zone_id
}

output "frontend_tg_arn" {
    description = "ARN of the frontend target group"
    value = aws_lb_target_group.frontend.arn
}

output "backend_tg_arn" {
    description = "ARN of the backend target group"
    value = aws_lb_target_group.backend.arn
}