# An AWS account can hold exactly ONE OIDC provider per URL. If your account
# already has a GitHub provider (check IAM > Identity providers), do not create
# a second one. Import the existing one instead:
#
#   terraform import aws_iam_openid_connect_provider.github \
#     arn:aws:iam::<your-account-id>:oidc-provider/token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS now validates this endpoint against its own trust store, so the
  # thumbprint is vestigial. The API still requires the field, and this dummy
  # value is what AWS's own documentation uses. Leave it alone.
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
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
      identifiers = [aws_iam_openid_connect_provider.github.arn]
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
  name               = "github-actions-deploy"
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
  name   = "github-actions-deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
