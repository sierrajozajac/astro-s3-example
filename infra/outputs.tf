# These three become GitHub repository variables. See the README.

output "deploy_role_arn" {
  description = "Set as the AWS_DEPLOY_ROLE_ARN repository variable."
  value       = aws_iam_role.deploy.arn
}

output "bucket_name" {
  description = "Set as the S3_BUCKET repository variable."
  value       = aws_s3_bucket.site.id
}

output "distribution_id" {
  description = "Set as the CLOUDFRONT_DISTRIBUTION_ID repository variable."
  value       = aws_cloudfront_distribution.site.id
}

output "distribution_domain_name" {
  description = "The CloudFront hostname, useful for testing before DNS propagates."
  value       = aws_cloudfront_distribution.site.domain_name
}
