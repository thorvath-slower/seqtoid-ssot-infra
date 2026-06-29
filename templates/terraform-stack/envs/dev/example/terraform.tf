# Backend + provider for this stack.
#
# State lives in the per-account foundation bucket. Each stack gets its own KEY
# (so state is isolated per env + component) but shares the account's bucket.
# Native S3 locking (use_lockfile) — no DynamoDB table needed (Terraform >= 1.10).
#
# Fill in <account_id>, <region>, and the key path, then:
#   terraform init   (CI validates with `terraform init -backend=false`)
terraform {
  backend "s3" {
    bucket       = "czid-tfstate-<account_id>-<region>" # the account's foundation bucket
    key          = "terraform/<env>/components/<component>.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
  # Credentials come from the per-account assume-role in CI (the named profile
  # the plan/apply workflow configures), or your local AWS profile.
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Environment = var.environment
      Stack       = "example"
    }
  }
}
