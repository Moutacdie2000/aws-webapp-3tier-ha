output "alb_arn" {
  description = "ARN de l'Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "Nom DNS public de l'ALB (cible des enregistrements Route 53 / CloudFront)."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted Zone ID de l'ALB (pour les alias Route 53)."
  value       = aws_lb.this.zone_id
}

output "alb_security_group_id" {
  description = "Identifiant du Security Group de l'ALB."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN du target group (consommé par le service ECS)."
  value       = aws_lb_target_group.this.arn
}

output "https_listener_arn" {
  description = "ARN du listener HTTPS."
  value       = aws_lb_listener.https.arn
}
