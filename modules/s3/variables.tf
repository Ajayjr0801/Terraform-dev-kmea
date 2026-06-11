variable "project" { type = string }
variable "environment" { type = string }
variable "buckets" {
  type = map(object({
    versioning     = bool
    static_website = bool
  }))
}

output "bucket_ids" {
  value = { for k, v in aws_s3_bucket.this : k => v.id }
}
output "bucket_arns" {
  value = { for k, v in aws_s3_bucket.this : k => v.arn }
}
output "bucket_regional_domain_names" {
  value = { for k, v in aws_s3_bucket.this : k => v.bucket_regional_domain_name }
}
