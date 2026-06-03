# =============================================================================
# Racine, câblage des modules de l'application 3-tiers haute disponibilité.
#
# Chaîne de dépendances :
#   network → alb / rds → ecs (consomme l'ALB et la DB) ; cdn est indépendant.
# =============================================================================

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "02-webapp-3tier-ha"
  }

  # Liste des topics SNS d'alarme (vide si aucune adresse e-mail fournie).
  alarm_topic_arns = var.alarm_email == "" ? [] : [aws_sns_topic.alarms[0].arn]
}

# -----------------------------------------------------------------------------
# SNS, canal de notification des alarmes CloudWatch (optionnel).
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "alarms" {
  count = var.alarm_email == "" ? 0 : 1
  name  = "${local.name_prefix}-alarms"
  tags  = local.common_tags
}

resource "aws_sns_topic_subscription" "alarms_email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# -----------------------------------------------------------------------------
# Module réseau, fondation multi-AZ (VPC, subnets, IGW, NAT, routes).
# -----------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  name_prefix              = local.name_prefix
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = var.availability_zones
  enable_nat_gateway       = true
  single_nat_gateway       = var.single_nat_gateway
  flow_logs_retention_days = var.log_retention_days

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Module ALB, point d'entrée HTTPS du tier applicatif.
# -----------------------------------------------------------------------------
module "alb" {
  source = "./modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  public_subnet_ids = module.network.public_subnet_ids
  certificate_arn   = var.alb_certificate_arn
  app_port          = var.app_port
  health_check_path = "/health"

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Module RDS, tier données PostgreSQL Multi-AZ.
# La règle d'ingress reliant le SG des tâches ECS au SG de la base est définie
# plus bas (aws_vpc_security_group_ingress_rule.rds_from_ecs) pour éviter un
# cycle de modules : le module ecs dépend déjà des sorties de rds.
# -----------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  name_prefix          = local.name_prefix
  vpc_id               = module.network.vpc_id
  data_subnet_ids      = module.network.data_subnet_ids
  db_name              = var.db_name
  db_username          = var.db_username
  instance_class       = var.db_instance_class
  multi_az             = var.db_multi_az
  deletion_protection  = var.db_deletion_protection
  alarm_sns_topic_arns = local.alarm_topic_arns

  tags = local.common_tags
}

# Règle de moindre privilège reliant les deux tiers : seules les tâches ECS
# (référencées par leur Security Group) peuvent ouvrir une connexion PostgreSQL
# vers l'instance RDS. Définie à la racine pour briser le cycle de dépendances.
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = module.rds.db_security_group_id
  description                  = "PostgreSQL depuis les tâches ECS"
  ip_protocol                  = "tcp"
  from_port                    = module.rds.db_port
  to_port                      = module.rds.db_port
  referenced_security_group_id = module.ecs.task_security_group_id
}

# -----------------------------------------------------------------------------
# Module ECS, tier applicatif Fargate auto-scalé.
# Consomme l'ALB (target group + SG) et la DB (endpoint + secret + clé KMS).
# -----------------------------------------------------------------------------
module "ecs" {
  source = "./modules/ecs"

  name_prefix           = local.name_prefix
  vpc_id                = module.network.vpc_id
  app_subnet_ids        = module.network.app_subnet_ids
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_arn
  app_port              = var.app_port
  image_tag             = var.image_tag
  task_cpu              = var.task_cpu
  task_memory           = var.task_memory
  desired_count         = var.desired_count
  min_capacity          = var.min_capacity
  max_capacity          = var.max_capacity
  log_retention_days    = var.log_retention_days
  alarm_sns_topic_arns  = local.alarm_topic_arns

  # Liaison au tier données.
  db_host       = module.rds.db_address
  db_port       = module.rds.db_port
  db_name       = module.rds.db_name
  db_secret_arn = module.rds.db_secret_arn
  kms_key_arn   = module.rds.kms_key_arn

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Module CDN, bucket S3 (OAC) + CloudFront pour les assets statiques.
# -----------------------------------------------------------------------------
module "cdn" {
  source = "./modules/cdn"

  name_prefix     = local.name_prefix
  account_id      = data.aws_caller_identity.current.account_id
  aliases         = var.cloudfront_aliases
  certificate_arn = var.cloudfront_certificate_arn

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Route 53, alias du domaine applicatif vers l'ALB (optionnel).
# Créé uniquement si un domaine ET une zone hébergée sont fournis.
# -----------------------------------------------------------------------------
resource "aws_route53_record" "app" {
  count   = var.domain_name != "" && var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
