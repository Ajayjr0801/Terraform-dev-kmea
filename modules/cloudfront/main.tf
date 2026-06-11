locals {
  name = "${var.project}-${var.environment}-${var.name_suffix}"
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${local.name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "${local.name} static site"
  price_class         = var.price_class

  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = "s3-${var.name_suffix}"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${var.name_suffix}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # SPA-style fallback: serve index.html for 403/404 so client-side routing works.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  tags = { Name = "${local.name}-cdn" }
}

output "distribution_arn" { value = aws_cloudfront_distribution.this.arn }
output "distribution_domain_name" { value = aws_cloudfront_distribution.this.domain_name }
output "distribution_id" { value = aws_cloudfront_distribution.this.id }

variable "project" { type = string }
variable "environment" { type = string }
variable "name_suffix" {
  description = "Distinguishes multiple CDN instances (e.g. doc-library, maindashboard)"
  type        = string
}
variable "price_class" {
  description = "CloudFront price class. PriceClass_All = pay-as-you-go (all edges); PriceClass_200 = US/EU/Asia."
  type        = string
  default     = "PriceClass_200"
}
variable "s3_bucket_regional_domain_name" { type = string }
