# =============================================================================
# Module : ecs
# Tier applicatif : cluster ECS, service Fargate auto-scalé derrière l'ALB.
#
#   - Dépôt ECR pour l'image applicative ;
#   - Cluster ECS avec Container Insights ;
#   - Task definition Fargate (rôle d'exécution + rôle de tâche distincts) ;
#   - Injection des identifiants DB depuis Secrets Manager ;
#   - Service réparti sur 2 AZ, enregistré dans le target group de l'ALB ;
#   - Autoscaling par suivi de cible (CPU moyen).
# =============================================================================

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Dépôt ECR — héberge l'image Docker du tier applicatif.
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = "${var.name_prefix}-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete_ecr

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

# Politique de cycle de vie : ne conserve que les 10 images les plus récentes.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Ne conserver que les 10 images les plus récentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# -----------------------------------------------------------------------------
# Security Group des tâches — n'accepte le trafic QUE depuis l'ALB.
# -----------------------------------------------------------------------------
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name_prefix}-ecs-tasks-sg"
  description = "Trafic applicatif depuis l'ALB uniquement"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-tasks-sg"
  })
}

# Ingress restreint à la source = Security Group de l'ALB (moindre privilège).
resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "Trafic applicatif depuis l'ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = var.alb_security_group_id
}

# Egress complet : nécessaire pour tirer l'image ECR, joindre Secrets Manager
# et CloudWatch via la NAT Gateway.
resource "aws_vpc_security_group_egress_rule" "all_egress" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Sortie Internet (ECR, Secrets Manager, CloudWatch via NAT)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# -----------------------------------------------------------------------------
# Journalisation CloudWatch des conteneurs.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name_prefix}-app"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Rôle d'exécution ECS — utilisé par l'agent Fargate (pull ECR, logs, secrets).
# -----------------------------------------------------------------------------
resource "aws_iam_role" "execution" {
  name = "${var.name_prefix}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Autorise l'agent à lire le secret DB et à le déchiffrer avec la clé KMS.
resource "aws_iam_role_policy" "execution_secrets" {
  name = "${var.name_prefix}-ecs-execution-secrets"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.db_secret_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
    ]
  })
}

# -----------------------------------------------------------------------------
# Rôle de tâche — identité applicative à l'exécution (séparé du rôle d'exécution).
# Minimaliste ici : l'application n'appelle aucune API AWS au runtime.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "task" {
  name = "${var.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Cluster ECS — Container Insights activé pour l'observabilité.
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

# Utilise Fargate et Fargate Spot ; le poids privilégie Fargate à la demande.
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# -----------------------------------------------------------------------------
# Task definition Fargate.
# Les identifiants DB sont injectés via `secrets` (références Secrets Manager)
# et non via des variables d'environnement en clair.
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = var.app_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "APP_VERSION", value = var.image_tag },
      { name = "AWS_REGION", value = data.aws_region.current.name },
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = tostring(var.db_port) },
      { name = "DB_NAME", value = var.db_name },
    ]

    # Clés extraites du secret JSON géré par Secrets Manager.
    secrets = [
      { name = "DB_USER", valueFrom = "${var.db_secret_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "app"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "python -c \"import urllib.request,sys; sys.exit(0) if urllib.request.urlopen('http://127.0.0.1:${var.app_port}/health', timeout=2).status==200 else sys.exit(1)\""]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 15
    }
  }])

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Service ECS — réparti sur les sous-réseaux applicatifs des 2 AZ.
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "app" {
  name            = "${var.name_prefix}-app"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Tolère un dépassement transitoire pour des déploiements sans coupure.
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Détecte automatiquement les déploiements en échec et déclenche un rollback.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = var.app_port
  }

  # Laisse le temps aux tâches de démarrer avant d'évaluer le health check ALB.
  health_check_grace_period_seconds = 60

  # L'image (donc la révision de task definition) est gérée par la CI/CD :
  # on ignore les changements de task_definition et de desired_count
  # (ce dernier étant piloté par l'autoscaling).
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [aws_iam_role_policy.execution_secrets]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Autoscaling applicatif — suivi de cible sur l'utilisation CPU moyenne.
# -----------------------------------------------------------------------------
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name_prefix}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# -----------------------------------------------------------------------------
# Alarme CloudWatch — CPU élevé soutenu (complète l'autoscaling, alerte SRE).
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.name_prefix}-ecs-high-cpu"
  alarm_description   = "Utilisation CPU du service ECS élevée sur la durée"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns

  tags = var.tags
}
