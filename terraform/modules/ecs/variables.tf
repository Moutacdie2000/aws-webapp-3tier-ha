variable "name_prefix" {
  description = "Préfixe appliqué au nom des ressources ECS."
  type        = string
}

variable "vpc_id" {
  description = "Identifiant du VPC."
  type        = string
}

variable "app_subnet_ids" {
  description = "Sous-réseaux applicatifs (privés) où placer les tâches Fargate."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security Group de l'ALB, autorisé en source vers les tâches."
  type        = string
}

variable "target_group_arn" {
  description = "ARN du target group de l'ALB auquel enregistrer le service."
  type        = string
}

variable "app_port" {
  description = "Port d'écoute du conteneur applicatif."
  type        = number
  default     = 8000
}

variable "image_tag" {
  description = "Tag de l'image applicative à déployer (typiquement le SHA de commit)."
  type        = string
  default     = "latest"
}

variable "task_cpu" {
  description = "Unités CPU de la tâche Fargate (256 = 0,25 vCPU)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Mémoire de la tâche Fargate en Mo."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Nombre de tâches souhaité au démarrage (avant autoscaling)."
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Nombre minimal de tâches pour l'autoscaling (2 pour couvrir les 2 AZ)."
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Nombre maximal de tâches pour l'autoscaling."
  type        = number
  default     = 6
}

variable "cpu_target_value" {
  description = "Cible d'utilisation CPU moyenne (%) pour le suivi de cible."
  type        = number
  default     = 60
}

variable "log_retention_days" {
  description = "Rétention des logs applicatifs dans CloudWatch (en jours)."
  type        = number
  default     = 30
}

variable "db_host" {
  description = "Endpoint de la base de données (injecté en variable d'environnement)."
  type        = string
}

variable "db_port" {
  description = "Port de la base de données."
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Nom de la base de données applicative."
  type        = string
}

variable "db_secret_arn" {
  description = "ARN du secret Secrets Manager contenant username/password de la DB."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN de la clé KMS chiffrant le secret DB (pour l'autorisation kms:Decrypt)."
  type        = string
}

variable "force_delete_ecr" {
  description = "Autorise la suppression du dépôt ECR même s'il contient des images (pratique pour le teardown de démo)."
  type        = bool
  default     = true
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
