# Every variable here is set in terraform.tfvars. Copy terraform.tfvars.example
# to terraform.tfvars and fill it in; nothing in this file needs editing.

variable "region" {
  description = "Region for the S3 bucket and IAM resources. The ACM certificate is always created in us-east-1, whatever you set here."
  type        = string
  default     = "us-west-2"
}

variable "domain_name" {
  description = "The domain the site is served on, e.g. example.com. Can be a subdomain (staging.example.com) as long as hosted_zone_name points at the zone that contains it."
  type        = string
}

variable "hosted_zone_name" {
  description = "The Route 53 public hosted zone to write records into. Leave empty to use domain_name, which is what you want when domain_name is an apex. Set it to the parent zone when domain_name is a subdomain, e.g. domain_name = staging.example.com with hosted_zone_name = example.com."
  type        = string
  default     = ""
}

variable "bucket_name" {
  description = "Name for the private origin bucket. S3 bucket names are globally unique across all AWS accounts, so pick something specific."
  type        = string
}

variable "github_repo" {
  description = "The GitHub repo allowed to assume the deploy role, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repo))
    error_message = "github_repo must be in owner/name form, e.g. sierrajozajac/my-site."
  }
}

variable "deploy_branch" {
  description = "The only branch allowed to assume the deploy role. Pushes from any other branch, or from a fork, are rejected by the trust policy."
  type        = string
  default     = "main"
}

variable "create_oidc_provider" {
  description = "Whether to create the GitHub OIDC identity provider. AWS allows exactly ONE per account, so set this to false if your account already has one (check IAM > Identity providers, or run: aws iam list-open-id-connect-providers). When false, the existing provider is looked up and reused."
  type        = bool
  default     = true
}

variable "role_name" {
  description = "Name of the deploy role. Change it if you run this more than once in a single account."
  type        = string
  default     = "github-actions-deploy"
}

locals {
  # The site domain and its www. Both go on the certificate and the distribution.
  aliases = [var.domain_name, "www.${var.domain_name}"]

  # Fall back to the domain itself when no separate zone is given.
  zone_name = var.hosted_zone_name != "" ? var.hosted_zone_name : var.domain_name
}
