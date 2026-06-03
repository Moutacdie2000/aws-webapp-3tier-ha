variable "name_prefix" {
  description = "Préfixe appliqué au nom des ressources CDN."
  type        = string
}

variable "account_id" {
  description = "Identifiant du compte AWS (rend le nom de bucket unique globalement)."
  type        = string
}

variable "aliases" {
  description = "Noms de domaine alternatifs (CNAMEs) servis par CloudFront."
  type        = list(string)
  default     = []
}

variable "certificate_arn" {
  description = "ARN du certificat ACM (us-east-1) pour CloudFront ; vide = certificat par défaut."
  type        = string
  default     = ""
}

variable "price_class" {
  description = "Classe de prix CloudFront (limite les emplacements périphériques)."
  type        = string
  default     = "PriceClass_100"
}

variable "force_destroy" {
  description = "Autorise la suppression du bucket même s'il contient des objets (teardown de démo)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags communs appliqués aux ressources."
  type        = map(string)
  default     = {}
}
