# =============================================================================
# foundation/modules/openbao — auto-unseal KMS key, IRSA role, stable address
# -----------------------------------------------------------------------------
# OpenBao is our secrets backend (MPL fork of Vault — Principle II). The
# foundation owns the INFRASTRUCTURE OpenBao depends on and publishes a stable
# address; the actual OpenBao install (Helm release, policies, dynamic DB-creds
# engine) is the secrets workstream (feature-#004) delivered via GitOps.
#
# What lives here:
#   - a dedicated KMS key for AWS-KMS auto-unseal (no manual unseal in cloud),
#   - an IRSA role the OpenBao pod assumes to use that key,
#   - the in-cluster service address every consumer reads from the foundation.
#
# Portability: the appliance edition unseals via Shamir keys (no AWS KMS), so
# this module is selected out of the appliance profile upstream; the published
# `address` stays the same shape (in-cluster service DNS).
# =============================================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  tags    = merge(var.tags, { "Module" = "openbao" })
  address = coalesce(var.address_override, "http://${var.service_name}.${var.namespace}.svc.cluster.local:8200")
}

# --- Auto-unseal KMS key ------------------------------------------------------
resource "aws_kms_key" "unseal" {
  description             = "OpenBao auto-unseal for the CZ ID stack"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = local.tags
  # Explicit root key policy (CKV2_AWS_64); the OpenBao IRSA role below is granted
  # use of the key via its IAM policy, which the root grant enables.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableRootAccount"
      Effect    = "Allow"
      Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  lifecycle {
    # Losing this key locks OpenBao sealed — protect it like state.
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "unseal" {
  name          = "alias/${var.name}-openbao-unseal"
  target_key_id = aws_kms_key.unseal.key_id
}

# --- IRSA role the OpenBao pod assumes to call the unseal key ------------------
data "aws_iam_policy_document" "irsa_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "unseal" {
  name               = "${var.name}-openbao-unseal"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume.json
  tags               = local.tags
}

# Least privilege: only the unseal ops, only on the unseal key (Principle VII).
data "aws_iam_policy_document" "unseal" {
  statement {
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"]
    resources = [aws_kms_key.unseal.arn]
  }
}

resource "aws_iam_role_policy" "unseal" {
  name   = "openbao-unseal"
  role   = aws_iam_role.unseal.id
  policy = data.aws_iam_policy_document.unseal.json
}
