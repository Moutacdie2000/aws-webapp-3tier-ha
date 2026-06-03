variable "name_prefix" {
  description = "Préfixe appliqué au nom des ressources de l'ALB."
  type        = string
}

variable "vpc_id" {
  description = "Identifiant du VPC hébergeant l'ALB."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC (utilisé pour restreindre l'egress de l'ALB vers les tâches)."
  type        = string
}

variable "public_subnet_ids" {
  description = "Sous-réseaux publics où placer l'ALB (un par AZ)."
  type        = list(string)
}

variable "certificate_arn" {
  description = "ARN du certificat ACM pour le listener HTTPS (région de l'ALB)."
  type        = string
}

variable "app_port" {
  description = "Port d'écoute des tâches applicatives ciblées par le target group."
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "Chemin HTTP interrogé par le health check de l'ALB."
  type        = string
  default     = "/health"
}

variable "ingress_cidr" {
  description = "Plage source autorisée à atteindre l'ALB (0.0.0.0/0 = public)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_deletion_protection" {
  description = "Active la protection contre la suppression de l'ALB."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags communs appliqués aux ressources."
  type        = map(string)
  default     = {}
}
