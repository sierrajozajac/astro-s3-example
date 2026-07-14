# An AWS account can hold exactly ONE OIDC provider per URL. If yours already
# has a GitHub one, creating a second fails with EntityAlreadyExists. Check:
#
#   aws iam list-open-id-connect-providers
#
# If it is already there, set create_oidc_provider = false in terraform.tfvars
# and the existing provider is looked up and reused below. Do NOT import it
# unless you own it: a later `terraform destroy` would delete it out from under
# whatever else in the account depends on it.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS now validates this endpoint against its own trust store, so the
  # thumbprint is vestigial. The API still requires the field, and this dummy
  # value is what AWS's own documentation uses. Leave it alone.
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1

  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_arn = var.create_oidc_provider ? one(aws_iam_openid_connect_provider.github[*].arn) : one(data.aws_iam_openid_connect_provider.github[*].arn)
}

# Who may assume the deploy role. The two conditions are the whole security
# story: `aud` proves the token was minted for STS, and `sub` pins it to one
# repo on one branch. A fork, a pull request, or any other repo gets refused.
data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/${var.deploy_branch}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = var.role_name
  description        = "Assumed by GitHub Actions via OIDC to publish the static site."
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
}

# Exactly what a deploy does, and nothing else: write objects, remove deleted
# ones, and bust the CDN cache. No wildcard resources.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid    = "SyncSiteObjects"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.site.arn}/*"]
  }

  statement {
    sid       = "ListSiteBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]
  }

  statement {
    sid       = "InvalidateCdnCache"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = var.role_name
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
