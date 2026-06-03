output "vpc_id" {
  description = "Identifiant du VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Bloc CIDR du VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Identifiants des sous-réseaux publics (un par AZ)."
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "Identifiants des sous-réseaux applicatifs (un par AZ)."
  value       = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  description = "Identifiants des sous-réseaux données (un par AZ)."
  value       = aws_subnet.data[*].id
}

output "availability_zones" {
  description = "Zones de disponibilité utilisées."
  value       = var.availability_zones
}

output "nat_gateway_ids" {
  description = "Identifiants des NAT Gateways créées."
  value       = aws_nat_gateway.this[*].id
}
