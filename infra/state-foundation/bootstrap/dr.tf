# =============================================================================
# state-foundation/bootstrap/dr.tf
# -----------------------------------------------------------------------------
# Cross-region replication of the state bucket for region-loss DR. Previously a
# README snippet; now committed code, gated behind `enable_dr` (default false)
# so the base bootstrap still plans clean with no destination required.
#
# When enabled, this creates — in `dr_region`:
#   - a destination bucket (versioned, encrypted, locked down, prevent_destroy),
#   - a DR KMS key for that bucket,
# and — in the primary region:
#   - an IAM role S3 assumes to replicate,
#   - a replication configuration on the primary state bucket.
#
# Enable with:  tofu apply -var enable_dr=true
# =============================================================================

# Second-region provider used only for the destination bucket + key.
provider "aws" {
  alias  = "dr"
  region = var.dr_region
}

locals {
  dr_count       = var.enable_dr ? 1 : 0
  dr_bucket_name = "czid-tfstate-${data.aws_caller_identity.current.account_id}-${var.dr_region}-dr"
}

# --- Destination KMS key (in the DR region) ----------------------------------
resource "aws_kms_key" "tfstate_dr" {
  count                   = local.dr_count
  provider                = aws.dr
  description             = "Encrypts replicated CZ ID state in the DR region"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  # Explicit root key policy (CKV2_AWS_64), as on the primary state key.
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

resource "aws_kms_alias" "tfstate_dr" {
  count         = local.dr_count
  provider      = aws.dr
  name          = "alias/czid-tfstate-dr"
  target_key_id = aws_kms_key.tfstate_dr[0].key_id
}

# --- Destination bucket (in the DR region) -----------------------------------
resource "aws_s3_bucket" "tfstate_dr" {
  count    = local.dr_count
  provider = aws.dr
  bucket   = local.dr_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate_dr" {
  count    = local.dr_count
  provider = aws.dr
  bucket   = aws_s3_bucket.tfstate_dr[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_dr" {
  count    = local.dr_count
  provider = aws.dr
  bucket   = aws_s3_bucket.tfstate_dr[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate_dr[0].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate_dr" {
  count                   = local.dr_count
  provider                = aws.dr
  bucket                  = aws_s3_bucket.tfstate_dr[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Expire old replicated state versions on the DR side too (CKV2_AWS_61);
# mirrors the primary bucket's lifecycle.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate_dr" {
  count    = local.dr_count
  provider = aws.dr
  bucket   = aws_s3_bucket.tfstate_dr[0].id
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

# Observe state mutations on the DR bucket via EventBridge (CKV2_AWS_62).
resource "aws_s3_bucket_notification" "tfstate_dr" {
  count       = local.dr_count
  provider    = aws.dr
  bucket      = aws_s3_bucket.tfstate_dr[0].id
  eventbridge = true
}

# --- Replication IAM role (S3 assumes this in the primary region) ------------
data "aws_iam_policy_document" "replication_assume" {
  count = local.dr_count
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  count              = local.dr_count
  name               = "czid-tfstate-replication"
  assume_role_policy = data.aws_iam_policy_document.replication_assume[0].json
}

data "aws_iam_policy_document" "replication" {
  count = local.dr_count

  # Read source bucket + object versions.
  statement {
    effect    = "Allow"
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }
  # Write replicas to the destination bucket.
  statement {
    effect    = "Allow"
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
    resources = ["${aws_s3_bucket.tfstate_dr[0].arn}/*"]
  }
  # Decrypt with the source key, re-encrypt with the destination key.
  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.tfstate.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.tfstate_dr[0].arn]
  }
}

resource "aws_iam_role_policy" "replication" {
  count  = local.dr_count
  name   = "replication"
  role   = aws_iam_role.replication[0].id
  policy = data.aws_iam_policy_document.replication[0].json
}

# --- Replication configuration on the primary state bucket -------------------
resource "aws_s3_bucket_replication_configuration" "tfstate" {
  count      = local.dr_count
  role       = aws_iam_role.replication[0].arn
  bucket     = aws_s3_bucket.tfstate.id
  depends_on = [aws_s3_bucket_versioning.tfstate]

  rule {
    id     = "dr"
    status = "Enabled"

    # Replicate KMS-encrypted objects (our state is SSE-KMS).
    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.tfstate_dr[0].arn
      storage_class = "STANDARD"
      encryption_configuration {
        replica_kms_key_id = aws_kms_key.tfstate_dr[0].arn
      }
    }
  }
}

# --- Server access-log bucket for the DR state bucket (CKV_AWS_18) -----------
# DR-region mirror of the primary log bucket (SSE-S3, hardened, self-logging
# skipped). In the DR region, gated behind enable_dr like the rest of dr.tf.
resource "aws_s3_bucket" "tfstate_dr_logs" {
  #checkov:skip=CKV_AWS_18:This IS the access-log target; logging a log bucket to itself is circular.
  #checkov:skip=CKV_AWS_144:Access logs are non-critical and regenerated; cross-region replication is unwarranted.
  count    = local.dr_count
  provider = aws.dr
  bucket   = "${local.dr_bucket_name}-logs"
}

# Dedicated CMK (DR region) for the DR access-log bucket — customer-managed key
# encryption (CKV_AWS_145 / trivy AVD-AWS-0132) with the S3 log-delivery grant.
resource "aws_kms_key" "tfstate_dr_logs" {
  count               = local.dr_count
  provider            = aws.dr
  description         = "Encrypts S3 server-access logs for the DR state bucket"
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

resource "aws_s3_bucket_public_access_block" "tfstate_dr_logs" {
  count                   = local.dr_count
  provider                = aws.dr
  bucket                  = aws_s3_bucket.tfstate_dr_logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tfstate_dr_logs" {
  count    = local.dr_count
  provider = aws.dr
  bucket   = aws_s3_bucket.tfstate_dr_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_dr_logs" {
  count    = local.dr_count
  provider = aws.dr
  bucket   = aws_s3_bucket.tfstate_dr_logs[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate_dr_logs[0].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate_dr_logs" {
  count    = local.dr_count
  provider = aws.dr
  bucket   = aws_s3_bucket.tfstate_dr_logs[0].id
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

resource "aws_s3_bucket_notification" "tfstate_dr_logs" {
  count       = local.dr_count
  provider    = aws.dr
  bucket      = aws_s3_bucket.tfstate_dr_logs[0].id
  eventbridge = true
}

resource "aws_s3_bucket_ownership_controls" "tfstate_dr_logs" {
  count    = local.dr_count
  provider = aws.dr
  bucket   = aws_s3_bucket.tfstate_dr_logs[0].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "tfstate_dr_logs" {
  count    = local.dr_count
  provider = aws.dr
  bucket   = aws_s3_bucket.tfstate_dr_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "S3ServerAccessLogsDelivery"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.tfstate_dr_logs[0].arn}/*"
        Condition = {
          ArnLike      = { "aws:SourceArn" = aws_s3_bucket.tfstate_dr[0].arn }
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.tfstate_dr_logs[0].arn, "${aws_s3_bucket.tfstate_dr_logs[0].arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
}

resource "aws_s3_bucket_logging" "tfstate_dr" {
  count         = local.dr_count
  provider      = aws.dr
  bucket        = aws_s3_bucket.tfstate_dr[0].id
  target_bucket = aws_s3_bucket.tfstate_dr_logs[0].id
  target_prefix = "s3-access/"
}
