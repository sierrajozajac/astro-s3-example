terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # UPDATE ME (recommended, but optional for a first run):
  # Local state is fine while you are the only person applying this. Once the
  # site is real, move state to a versioned S3 bucket so it is not sitting in a
  # single .tfstate file on your laptop. Create the bucket first, then uncomment.
  #
  # backend "s3" {
  #   bucket = "your-tfstate-bucket"
  #   key    = "astro-s3-example/terraform.tfstate"
  #   region = "us-west-2"
  # }
}

provider "aws" {
  region = var.region
}

# CloudFront only reads certificates from us-east-1, so ACM gets its own
# aliased provider regardless of where the rest of your resources live.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}
