# =============================================================================
# Module : alb
# Application Load Balancer public, point d'entrée du tier applicatif.
#
#   - Security Group dédié (80/443 depuis Internet) ;
#   - Listener HTTP :80 → redirection 301 vers HTTPS ;
#   - Listener HTTPS :443 (certificat ACM) → target group ;
#   - Target group de type "ip" (compatible Fargate awsvpc) + health check.
# =============================================================================

# -----------------------------------------------------------------------------
# Security Group de l'ALB — accepte le trafic web depuis l'extérieur.
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Autorise le trafic HTTP/HTTPS entrant vers l'ALB"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP entrant (redirigé vers HTTPS)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.ingress_cidr
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS entrant"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.ingress_cidr
}

# L'ALB doit pouvoir joindre les tâches sur le port applicatif. On limite la
# sortie au CIDR du VPC plutôt que d'ouvrir vers le monde entier.
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id = aws_security_group.alb.id
  description       = "Vers les tâches applicatives dans le VPC"
  ip_protocol       = "tcp"
  from_port         = var.app_port
  to_port           = var.app_port
  cidr_ipv4         = var.vpc_cidr
}

# -----------------------------------------------------------------------------
# Application Load Balancer
# -----------------------------------------------------------------------------
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true
  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb"
  })
}

# -----------------------------------------------------------------------------
# Target group — cible de type "ip" (obligatoire avec le mode réseau awsvpc
# de Fargate). Le health check interroge la route /health de l'application.
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "this" {
  name        = "${var.name_prefix}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  # Drainage rapide pour des déploiements fluides.
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # Affinité de session désactivée : l'application est sans état.
  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Listener HTTP :80 — redirection permanente vers HTTPS.
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Listener HTTPS :443 — terminaison TLS via certificat ACM.
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  # Politique TLS moderne (TLS 1.2/1.3 uniquement).
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = var.tags
}
