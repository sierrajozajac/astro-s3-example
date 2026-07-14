# astro-s3-example

Terraform for a private S3 + CloudFront static site with a keyless GitHub Actions deploy.

The bucket is never world-readable. CloudFront reaches it through an Origin Access Control, and GitHub Actions authenticates through OIDC, so no AWS keys are stored in the repo.

This is the `infra/` companion to the guide [How to Deploy a Static Astro Site to S3 + CloudFront with Keyless OIDC](https://github.com/sierrajozajac/astro-s3-example).

## What it creates

| Resource | Why |
| --- | --- |
| Private S3 bucket | Origin. No public access, no website hosting. |
| Origin Access Control | The only thing allowed to read the bucket. |
| CloudFront distribution | Serves the site, HTTPS enforced. |
| ACM certificate (`us-east-1`) | CloudFront reads certs from that region only. |
| Route 53 A/AAAA aliases | Apex and `www`, pointing at CloudFront. |
| GitHub OIDC provider + IAM role | Short-lived deploy credentials, no stored keys. |

The deploy role can do four things: `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` on this bucket, and `cloudfront:CreateInvalidation` on this distribution. It is assumable only by one repo, on one branch.

## Before you run it

- Terraform 1.6 or later.
- The AWS CLI authenticated with credentials that can create S3, CloudFront, ACM, Route 53, and IAM resources.
- A Route 53 **public hosted zone** that already exists for your domain. Terraform reads it; it does not create it.

## Run it

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars. Every value is marked UPDATE ME.

terraform init
terraform plan
terraform apply
```

Every value you need to change lives in `terraform.tfvars`. The `.tf` files themselves carry `UPDATE ME` comments only where an optional choice is worth revisiting (price class, 404 behavior, remote state).

The first apply takes roughly 5 to 15 minutes. Most of that is CloudFront propagating; the ACM validation step usually clears in under two minutes.

## Wire up the deploy

`terraform output` prints the three values GitHub Actions needs. Set them as **repository variables** (Settings > Secrets and variables > Actions > Variables), not secrets, since none of them are sensitive:

| Output | Repository variable |
| --- | --- |
| `deploy_role_arn` | `AWS_DEPLOY_ROLE_ARN` |
| `bucket_name` | `S3_BUCKET` |
| `distribution_id` | `CLOUDFRONT_DISTRIBUTION_ID` |

Your workflow then needs `permissions: id-token: write` and the `aws-actions/configure-aws-credentials` action pointed at `AWS_DEPLOY_ROLE_ARN`. No `AWS_SECRET_ACCESS_KEY` anywhere.

## Two things that trip people up

**One OIDC provider per account.** AWS allows exactly one identity provider per URL. If your account already has a GitHub one, importing it beats creating a second:

```bash
terraform import aws_iam_openid_connect_provider.github \
  arn:aws:iam::<your-account-id>:oidc-provider/token.actions.githubusercontent.com
```

**The OIDC thumbprint is a dummy value on purpose.** AWS validates the GitHub endpoint against its own trust store now. The API still requires the field, so the code passes the placeholder AWS's own docs use.

## Verify it is actually private

After a deploy, request the raw S3 object URL directly. It should return `AccessDenied`. The same path through your domain should return 200. If the S3 URL serves the file, the public access block is not doing its job and something is wrong.
