# =============================================================================
# Sorties racine
# =============================================================================

# --- Réseau ---
output "vpc_id" {
  description = "Identifiant du VPC."
  value       = module.network.vpc_id
}

output "availability_zones" {
  description = "Zones de disponibilité utilisées."
  value       = module.network.availability_zones
}

# --- Point d'entrée applicatif ---
output "alb_dns_name" {
  description = "Nom DNS de l'ALB (point d'entrée HTTP/HTTPS du tier applicatif)."
  value       = module.alb.alb_dns_name
}

output "application_url" {
  description = "URL d'accès à l'application (domaine personnalisé si défini, sinon DNS de l'ALB)."
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "https://${module.alb.alb_dns_name}"
}

# --- Tier applicatif ---
output "ecs_cluster_name" {
  description = "Nom du cluster ECS."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Nom du service ECS (utilisé par la CI/CD pour forcer un déploiement)."
  value       = module.ecs.service_name
}

output "ecr_repository_url" {
  description = "URL du dépôt ECR pour pousser l'image applicative."
  value       = module.ecs.ecr_repository_url
}

# --- Tier données ---
output "rds_endpoint" {
  description = "Endpoint de l'instance RDS PostgreSQL."
  value       = module.rds.db_endpoint
}

output "db_secret_arn" {
  description = "ARN du secret Secrets Manager contenant les identifiants de la base."
  value       = module.rds.db_secret_arn
}

# --- CDN ---
output "cloudfront_domain_name" {
  description = "Nom de domaine de la distribution CloudFront des assets."
  value       = module.cdn.distribution_domain_name
}

output "assets_bucket_name" {
  description = "Nom du bucket S3 des assets statiques."
  value       = module.cdn.bucket_name
}
