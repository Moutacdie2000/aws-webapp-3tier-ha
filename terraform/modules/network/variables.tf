variable "name_prefix" {
  description = "Préfixe appliqué au nom de toutes les ressources réseau."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC (doit laisser de la place pour des /24 par AZ et par tier)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Liste des zones de disponibilité à utiliser (2 minimum pour la HA)."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Crée des NAT Gateways pour la sortie Internet des sous-réseaux applicatifs."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "N'utilise qu'une seule NAT Gateway (économie de coût en dev ; perd la HA inter-AZ)."
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Durée de rétention des VPC Flow Logs dans CloudWatch (en jours)."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags communs appliqués à toutes les ressources."
  type        = map(string)
  default     = {}
}
