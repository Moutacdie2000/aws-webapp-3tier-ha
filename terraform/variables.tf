# =============================================================================
# Variables racine
# =============================================================================

variable "project_name" {
  description = "Nom du projet (sert de base au préfixe des ressources)."
  type        = string
  default     = "webapp-3tier"
}

variable "environment" {
  description = "Environnement cible (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Région AWS de déploiement."
  type        = string
  default     = "eu-west-3"
}

variable "availability_zones" {
  description = "Zones de disponibilité (2 minimum pour la haute disponibilité)."
  type        = list(string)
  default     = ["eu-west-3a", "eu-west-3b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Au moins deux zones de disponibilité sont requises pour la HA."
  }
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC."
  type        = string
  default     = "10.20.0.0/16"
}

# --- Réseau / coût ---
variable "single_nat_gateway" {
  description = "N'utilise qu'une NAT Gateway (économie de coût en dev ; sacrifie la HA inter-AZ)."
  type        = bool
  default     = false
}

# --- Certificats & DNS ---
variable "alb_certificate_arn" {
  description = "ARN du certificat ACM (région de l'ALB) pour le listener HTTPS."
  type        = string
}

variable "cloudfront_certificate_arn" {
  description = "ARN du certificat ACM (us-east-1) pour CloudFront ; vide = certificat par défaut."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Nom de domaine principal de l'application (ex. app.example.com) ; vide pour ne pas créer d'enregistrement Route 53."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Identifiant de la zone hébergée Route 53 ; vide pour ne pas créer d'enregistrement."
  type        = string
  default     = ""
}

variable "cloudfront_aliases" {
  description = "Noms de domaine alternatifs servis par CloudFront pour les assets."
  type        = list(string)
  default     = []
}

# --- Tier applicatif ---
variable "app_port" {
  description = "Port d'écoute du conteneur applicatif."
  type        = number
  default     = 8000
}

variable "image_tag" {
  description = "Tag de l'image applicative à déployer (SHA de commit en CI/CD)."
  type        = string
  default     = "latest"
}

variable "task_cpu" {
  description = "Unités CPU de la tâche Fargate."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Mémoire de la tâche Fargate (Mo)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Nombre de tâches souhaité au démarrage."
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Capacité minimale d'autoscaling du service ECS."
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Capacité maximale d'autoscaling du service ECS."
  type        = number
  default     = 6
}

# --- Tier données ---
variable "db_name" {
  description = "Nom de la base de données applicative."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Nom d'utilisateur maître PostgreSQL."
  type        = string
  default     = "appuser"
}

variable "db_instance_class" {
  description = "Classe d'instance RDS."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "Active le mode Multi-AZ sur RDS."
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Protège l'instance RDS contre la suppression."
  type        = bool
  default     = false
}

# --- Observabilité ---
variable "alarm_email" {
  description = "Adresse e-mail abonnée au topic SNS d'alertes ; vide pour ne pas créer d'abonnement."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Rétention par défaut des logs CloudWatch (en jours)."
  type        = number
  default     = 30
}
