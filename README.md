# astro-s3-example

Terraform for a private S3 + CloudFront static site with a keyless GitHub Actions deploy.

The bucket is never world-readable. CloudFront reaches it through an Origin Access Control, and GitHub Actions authenticates through OIDC, so no AWS keys are stored in the repo.

This is the companion code to the guide *How to Deploy a Static Astro Site to S3 + CloudFront with Keyless OIDC*.

## What it creates

| Resource | File | Why |
| --- | --- | --- |
| Private S3 bucket | [`infra/s3.tf`](infra/s3.tf) | Origin. No public access, no website hosting. |
| Origin Access Control | [`infra/cloudfront.tf`](infra/cloudfront.tf) | The only thing allowed to read the bucket. |
| CloudFront distribution | [`infra/cloudfront.tf`](infra/cloudfront.tf) | Serves the site, HTTPS enforced. |
| ACM certificate (`us-east-1`) | [`infra/acm.tf`](infra/acm.tf) | CloudFront reads certs from that region only. |
| Route 53 A/AAAA aliases | [`infra/route53.tf`](infra/route53.tf) | Apex and `www`, pointing at CloudFront. |
| GitHub OIDC provider + IAM role | [`infra/github-oidc.tf`](infra/github-oidc.tf) | Short-lived deploy credentials, no stored keys. |
| Deploy workflow | [`workflows/deploy.yml`](workflows/deploy.yml) | Scan, build, sync, invalidate. Copy into your site repo. |

The deploy role can do four things: `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` on this bucket, and `cloudfront:CreateInvalidation` on this distribution. It is assumable only by one repo, on one branch. That scoping already ships in [`infra/github-oidc.tf`](infra/github-oidc.tf); you do not have to add it yourself.

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

Then copy [`workflows/deploy.yml`](workflows/deploy.yml) into the repo that holds your Astro site, at `.github/workflows/deploy.yml`. It is not active here because this repo has no site to build. The values you may need to change in it are marked `UPDATE ME`.

No `AWS_SECRET_ACCESS_KEY` anywhere, in this repo or yours.

## Verify the deploy is private

After the workflow has run once, ask S3 directly for a file it is serving. Swap in your own bucket name and region:

```bash
curl -I https://your-bucket-name.s3.us-west-2.amazonaws.com/index.html
```

You want `HTTP/1.1 403 Forbidden`. That is the public access block doing its job. If it returns 200, the bucket is readable by the world and something is wrong.

Now ask for the same file through your domain:

```bash
curl -I https://example.com/index.html
```

You want `HTTP/2 200`. Same object, reachable only through the CDN.

## Two things that trip people up

**One OIDC provider per account.** AWS allows exactly one identity provider per URL. If your account already has a GitHub one, importing it beats creating a second:

```bash
terraform import aws_iam_openid_connect_provider.github \
  arn:aws:iam::<your-account-id>:oidc-provider/token.actions.githubusercontent.com
```

**The OIDC thumbprint is a dummy value on purpose.** AWS validates the GitHub endpoint against its own trust store now. The API still requires the field, so the code passes the placeholder AWS's own docs use.
