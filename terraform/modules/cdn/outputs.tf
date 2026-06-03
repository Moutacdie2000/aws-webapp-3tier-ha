output "bucket_name" {
  description = "Nom du bucket S3 des assets statiques."
  value       = aws_s3_bucket.assets.bucket
}

output "bucket_arn" {
  description = "ARN du bucket S3 des assets."
  value       = aws_s3_bucket.assets.arn
}

output "distribution_id" {
  description = "Identifiant de la distribution CloudFront (utile pour les invalidations)."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "ARN de la distribution CloudFront."
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "Nom de domaine de la distribution CloudFront (*.cloudfront.net)."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_hosted_zone_id" {
  description = "Hosted Zone ID de CloudFront (constant, pour les alias Route 53)."
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}
