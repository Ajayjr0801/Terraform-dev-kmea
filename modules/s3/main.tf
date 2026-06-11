resource "aws_s3_bucket" "this" {
  for_each = var.buckets
  bucket   = each.key
  tags     = { Name = each.key }
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = each.value.versioning ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Static website hosting (for buckets flagged static_website = true)
resource "aws_s3_bucket_website_configuration" "this" {
  for_each = { for k, v in var.buckets : k => v if v.static_website }
  bucket   = aws_s3_bucket.this[each.key].id
  index_document { suffix = "index.html" }
  error_document { key = "error.html" }
}

# Block public access by default. CloudFront reaches the static bucket via OAC,
# not public ACLs — so we keep buckets private and add an OAC bucket policy below.
resource "aws_s3_bucket_public_access_block" "this" {
  for_each                = var.buckets
  bucket                  = aws_s3_bucket.this[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# NOTE: the CloudFront OAC bucket policy lives in the ROOT module
# (s3_cloudfront_policy.tf) to avoid an s3 <-> cloudfront module cycle.
