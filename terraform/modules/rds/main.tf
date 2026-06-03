# =============================================================================
# Module : rds
# Tier données : instance RDS PostgreSQL Multi-AZ chiffrée.
#
#   - Clé KMS dédiée pour le chiffrement au repos et le secret ;
#   - Mot de passe généré aléatoirement, stocké dans Secrets Manager ;
#   - Subnet group sur les sous-réseaux "data" des 2 AZ ;
#   - Security Group n'acceptant que le SG des tâches ECS ;
#   - Multi-AZ, sauvegardes automatiques, suppression protégée (optionnelle).
# =============================================================================

# -----------------------------------------------------------------------------
# Clé KMS — chiffre l'instance RDS et le secret de connexion.
# -----------------------------------------------------------------------------
resource "aws_kms_key" "rds" {
  description             = "Chiffrement RDS et secret DB pour ${var.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-kms"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# -----------------------------------------------------------------------------
# Mot de passe maître — généré aléatoirement et jamais exposé en clair dans l'état.
# -----------------------------------------------------------------------------
resource "random_password" "db" {
  length = 24
  # Caractères spéciaux compatibles avec PostgreSQL et les URI de connexion.
  special          = true
  override_special = "!#$%*-_=+"
}

# -----------------------------------------------------------------------------
# Secret Secrets Manager — JSON { username, password, host, port, dbname }.
# Consommé par la task definition ECS (clés username/password).
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name_prefix}/db/credentials"
  description = "Identifiants PostgreSQL pour ${var.name_prefix}"
  kms_key_id  = aws_kms_key.rds.arn

  # Suppression immédiate possible (pratique pour les démos jetables).
  recovery_window_in_days = var.secret_recovery_window_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = var.db_port
    dbname   = var.db_name
  })
}

# -----------------------------------------------------------------------------
# Subnet group — répartit l'instance sur les sous-réseaux "data" des 2 AZ.
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.data_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

# -----------------------------------------------------------------------------
# Security Group de la base — n'autorise QUE le SG des tâches ECS sur 5432.
#
# La règle d'ingress qui référence le SG des tâches ECS est définie à la racine
# (et non ici) afin d'éviter un cycle de dépendances entre les modules ecs et
# rds : le module ecs consomme les sorties de rds (endpoint, secret, KMS), donc
# rds ne peut pas, en retour, dépendre d'une sortie d'ecs.
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Accès PostgreSQL depuis les tâches ECS uniquement"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-sg"
  })
}

# -----------------------------------------------------------------------------
# Groupe de paramètres — force le SSL en transit côté serveur.
# -----------------------------------------------------------------------------
resource "aws_db_parameter_group" "this" {
  name        = "${var.name_prefix}-pg"
  family      = var.parameter_group_family
  description = "Paramètres PostgreSQL pour ${var.name_prefix} (SSL obligatoire)"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Instance RDS PostgreSQL — Multi-AZ pour la haute disponibilité.
# -----------------------------------------------------------------------------
resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = var.db_port

  # --- Haute disponibilité ---
  # Multi-AZ provisionne une instance de secours dans une autre AZ et bascule
  # automatiquement (DNS) en cas de panne de l'instance primaire.
  multi_az = var.multi_az

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  # --- Sauvegardes & maintenance ---
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot   = true

  # --- Observabilité ---
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.rds.arn
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn

  # --- Cycle de vie ---
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-final-snapshot"
  apply_immediately         = var.apply_immediately
  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres"
    Tier = "data"
  })

  lifecycle {
    # Le mot de passe est piloté hors cycle Terraform après le bootstrap initial.
    ignore_changes = [password]
  }
}

# -----------------------------------------------------------------------------
# Rôle IAM pour Enhanced Monitoring (métriques OS de l'instance RDS).
# -----------------------------------------------------------------------------
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.name_prefix}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# -----------------------------------------------------------------------------
# Alarme CloudWatch — espace disque libre faible.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "low_storage" {
  alarm_name          = "${var.name_prefix}-rds-low-storage"
  alarm_description   = "Espace de stockage libre de l'instance RDS faible"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.low_storage_threshold_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns

  tags = var.tags
}
