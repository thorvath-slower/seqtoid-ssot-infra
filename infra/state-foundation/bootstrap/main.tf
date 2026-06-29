# =============================================================================
# state-foundation/bootstrap/main.tf
# -----------------------------------------------------------------------------
# Creates the SHARED remote backend that every other stack (foundation + each
# repo) stores its state in. Run this ONCE, first, with a LOCAL backend — the
# bucket can't store its own creation state until it exists (chicken-and-egg).
# After apply, you may optionally migrate this stack's state into the bucket.
#
#   cd bootstrap
#   terraform init            # local backend
#   terraform apply           # creates bucket + lock table + KMS key
#   # (optional) add the backend "s3" block below and: terraform init -migrate-state
# =============================================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  # Globally-unique, deterministic name: czid-tfstate-<account>-<region>
  bucket_name = "czid-tfstate-${data.aws_caller_identity.current.account_id}-${var.region}"
  lock_table  = "czid-tfstate-locks"
}

# --- KMS key used to encrypt every state object ------------------------------
resource "aws_kms_key" "tfstate" {
  description             = "Encrypts CZ ID Terraform state"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  # Explicit key policy (CKV2_AWS_64): grant the account root full control so
  # IAM policies govern day-to-day use, instead of relying on the implicit
  # default policy. Without a root grant the key can become unmanageable.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableRootAccount"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/czid-tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}

# --- The shared state bucket --------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  # The backend bucket must never be destroyed by an errant plan.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning IS the backup: every state write retains the previous version,
# so any prior state can be recovered object-by-object or wholesale.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Keep a generous backup window of old state versions, then expire them.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    id     = "expire-noncurrent-state"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = var.state_backup_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Refuse any non-TLS access to state.
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.tfstate.arn, "${aws_s3_bucket.tfstate.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

# --- State locking ------------------------------------------------------------
# Classic, works on every Terraform/Terraform version.
# NOTE: Terraform >= 1.10 can lock natively in S3 (set `use_lockfile = true` in
# the backend and drop this table). Kept here for broad compatibility.
resource "aws_dynamodb_table" "tflock" {
  name         = local.lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }

  # Encrypt the lock table with the state CMK (CKV_AWS_119).
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tfstate.arn
  }

  # Recover the lock table from accidental corruption/deletion (CKV_AWS_28).
  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Emit S3 events to EventBridge so state mutations are observable/auditable
# (CKV2_AWS_62). EventBridge is the lightest target (no SNS/SQS to manage).
resource "aws_s3_bucket_notification" "tfstate" {
  bucket      = aws_s3_bucket.tfstate.id
  eventbridge = true
}

# --- Server access-log bucket for the state bucket (CKV_AWS_18) --------------
# Receives S3 server access logs from the state bucket. Hardened like the state
# bucket but SSE-S3 (AES256): the S3 log-delivery service writes to AES256
# targets natively, whereas an SSE-KMS target needs an extra key grant — and
# access logs carry no secrets, so AES256 is the pragmatic choice.
resource "aws_s3_bucket" "tfstate_logs" {
  #checkov:skip=CKV_AWS_18:This IS the access-log target; logging a log bucket to itself is circular.
  #checkov:skip=CKV_AWS_144:Access logs are non-critical and regenerated; cross-region replication is unwarranted.
  bucket = "${local.bucket_name}-logs"
}

# Dedicated CMK for the access-log bucket so it's encrypted with a customer-managed
# key (CKV_AWS_145 / trivy AVD-AWS-0132). The S3 server-access-log delivery service
# is granted use of the key so it can write encrypted logs.
resource "aws_kms_key" "tfstate_logs" {
  description         = "Encrypts S3 server-access logs for the state bucket"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccount"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowS3ServerAccessLogDelivery"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = ["kms:GenerateDataKey*", "kms:Encrypt", "kms:Decrypt", "kms:Describe*"]
        Resource  = "*"
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "tfstate_logs" {
  bucket                  = aws_s3_bucket.tfstate_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tfstate_logs" {
  bucket = aws_s3_bucket.tfstate_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_logs" {
  bucket = aws_s3_bucket.tfstate_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate_logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate_logs" {
  bucket = aws_s3_bucket.tfstate_logs.id
  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.state_backup_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_notification" "tfstate_logs" {
  bucket      = aws_s3_bucket.tfstate_logs.id
  eventbridge = true
}

# ACLs disabled (modern default) — log delivery is granted via the bucket policy.
resource "aws_s3_bucket_ownership_controls" "tfstate_logs" {
  bucket = aws_s3_bucket.tfstate_logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "tfstate_logs" {
  bucket = aws_s3_bucket.tfstate_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "S3ServerAccessLogsDelivery"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.tfstate_logs.arn}/*"
        Condition = {
          ArnLike      = { "aws:SourceArn" = aws_s3_bucket.tfstate.arn }
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.tfstate_logs.arn, "${aws_s3_bucket.tfstate_logs.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
}

resource "aws_s3_bucket_logging" "tfstate" {
  bucket        = aws_s3_bucket.tfstate.id
  target_bucket = aws_s3_bucket.tfstate_logs.id
  target_prefix = "s3-access/"
}
