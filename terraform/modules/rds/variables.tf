variable "name_prefix" {
  description = "Préfixe appliqué au nom des ressources RDS."
  type        = string
}

variable "vpc_id" {
  description = "Identifiant du VPC."
  type        = string
}

variable "data_subnet_ids" {
  description = "Sous-réseaux 'data' (un par AZ) pour le subnet group RDS."
  type        = list(string)
}

variable "engine_version" {
  description = "Version majeure/mineure de PostgreSQL."
  type        = string
  default     = "16.4"
}

variable "parameter_group_family" {
  description = "Famille du parameter group (doit correspondre à la version majeure)."
  type        = string
  default     = "postgres16"
}

variable "instance_class" {
  description = "Classe d'instance RDS."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Stockage initial alloué (Go)."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Plafond de stockage pour l'autoscaling du stockage (Go)."
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Nom de la base de données applicative."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Nom d'utilisateur maître de la base."
  type        = string
  default     = "appuser"
}

variable "db_port" {
  description = "Port d'écoute PostgreSQL."
  type        = number
  default     = 5432
}

variable "multi_az" {
  description = "Active le déploiement Multi-AZ (instance de secours + bascule automatique)."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Durée de rétention des sauvegardes automatiques (en jours)."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Protège l'instance contre une suppression accidentelle."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Ignore le snapshot final à la destruction (true pour les démos jetables)."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Applique immédiatement les modifications (sinon à la fenêtre de maintenance)."
  type        = bool
  default     = false
}

variable "secret_recovery_window_days" {
  description = "Fenêtre de récupération du secret après suppression (0 = suppression immédiate)."
  type        = number
  default     = 0
}

variable "low_storage_threshold_bytes" {
  description = "Seuil d'alarme pour l'espace disque libre (en octets)."
  type        = number
  default     = 2147483648 # 2 Gio
}

variable "alarm_sns_topic_arns" {
  description = "ARNs des topics SNS notifiés par les alarmes CloudWatch."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags communs appliqués aux ressources."
  type        = map(string)
  default     = {}
}
