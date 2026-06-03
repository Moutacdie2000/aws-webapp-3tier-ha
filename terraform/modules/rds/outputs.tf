output "db_instance_id" {
  description = "Identifiant de l'instance RDS."
  value       = aws_db_instance.this.id
}

output "db_endpoint" {
  description = "Endpoint de connexion (host:port) de l'instance RDS."
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Nom DNS de l'instance RDS (host seul)."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Port d'écoute de la base."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Nom de la base de données applicative."
  value       = aws_db_instance.this.db_name
}

output "db_security_group_id" {
  description = "Identifiant du Security Group de la base."
  value       = aws_security_group.rds.id
}

output "db_secret_arn" {
  description = "ARN du secret Secrets Manager contenant les identifiants de la base."
  value       = aws_secretsmanager_secret.db.arn
}

output "kms_key_arn" {
  description = "ARN de la clé KMS chiffrant la base et le secret."
  value       = aws_kms_key.rds.arn
}
