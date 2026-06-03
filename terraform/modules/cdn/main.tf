# =============================================================================
# Module : cdn
# Distribution des assets statiques : bucket S3 privé (OAC) + CloudFront.
#
#   - Bucket S3 privé, chiffré, versionné, sans accès public ;
#   - Origin Access Control (OAC) : seul CloudFront peut lire le bucket ;
#   - Distribution CloudFront HTTPS-only avec compression et cache géré.
#
# Remarque : le certificat ACM d'une distribution CloudFront DOIT résider dans
# la région us-east-1. Il est passé via var.certificate_arn (peut être vide
# pour utiliser le certificat *.cloudfront.net par défaut).
# =============================================================================

# -----------------------------------------------------------------------------
# Bucket S3 des assets statiques.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "assets" {
  bucket        = "${var.name_prefix}-assets-${var.account_id}"
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-assets"
  })
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# -----------------------------------------------------------------------------
# Origin Access Control (OAC) — remplace l'ancienne OAI, signe les requêtes
# de CloudFront vers S3 en SigV4.
# -----------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "assets" {
  name                              = "${var.name_prefix}-oac"
  description                       = "OAC pour le bucket d'assets ${var.name_prefix}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# -----------------------------------------------------------------------------
# Politique de cache gérée par AWS (CachingOptimized) référencée par son ID.
# -----------------------------------------------------------------------------
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

# -----------------------------------------------------------------------------
# Distribution CloudFront.
# -----------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = "Distribution d'assets statiques ${var.name_prefix}"
  default_root_object = "index.html"
  price_class         = var.price_class
  aliases             = var.aliases

  origin {
    domain_name              = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id                = "s3-assets"
    origin_access_control_id = aws_cloudfront_origin_access_control.assets.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-assets"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Certificat : ACM (us-east-1) si fourni, sinon certificat CloudFront par défaut.
  viewer_certificate {
    cloudfront_default_certificate = var.certificate_arn == "" ? true : false
    acm_certificate_arn            = var.certificate_arn == "" ? null : var.certificate_arn
    ssl_support_method             = var.certificate_arn == "" ? null : "sni-only"
    minimum_protocol_version       = var.certificate_arn == "" ? "TLSv1" : "TLSv1.2_2021"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cdn"
  })
}

# -----------------------------------------------------------------------------
# Politique de bucket — autorise UNIQUEMENT cette distribution CloudFront
# (condition sur l'ARN de la distribution) à lire les objets.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "assets" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.assets.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id
  policy = data.aws_iam_policy_document.assets.json

  depends_on = [aws_s3_bucket_public_access_block.assets]
}
