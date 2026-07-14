# Every variable here is set in terraform.tfvars. Copy terraform.tfvars.example
# to terraform.tfvars and fill it in; nothing in this file needs editing.

variable "region" {
  description = "Region for the S3 bucket and IAM resources. The ACM certificate is always created in us-east-1, whatever you set here."
  type        = string
  default     = "us-west-2"
}

variable "domain_name" {
  description = "Apex domain, e.g. example.com. A Route 53 public hosted zone for this domain must already exist."
  type        = string
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

locals {
  # The apex and www. Both go on the certificate and the distribution.
  aliases = [var.domain_name, "www.${var.domain_name}"]
}
