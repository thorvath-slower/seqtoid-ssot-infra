# =============================================================================
# foundation/main.tf — the shared (cloud-edition) foundation
# -----------------------------------------------------------------------------
# Owns the long-lived infra every downstream CZ ID stack inherits: network, EKS,
# the shared app KMS key, OpenBao's unseal infra, registries, GitHub-OIDC, and
# the shared least-privilege roles. Everything here is published through
# outputs.tf (the inheritance contract) and read via terraform_remote_state.
# =============================================================================

provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name         = "${var.name_prefix}-${var.environment}"
  cluster_name = "${var.name_prefix}-${var.environment}"
  azs          = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  account_id   = data.aws_caller_identity.current.account_id
  partition    = data.aws_partition.current.partition

  tags = merge({
    Project     = "cz-id-stack"
    Environment = var.environment
    ManagedBy   = "opentofu"
    Foundation  = "true"
  }, var.tags)
}

# --- Shared application KMS key ----------------------------------------------
# Distinct from the state-encryption key in bootstrap/. This one encrypts app
# data: EKS etcd secrets, ECR/CodeArtifact, and anything downstream wants to
# encrypt under a shared, rotated key.
resource "aws_kms_key" "app" {
  description             = "Shared CZ ID application data key (${var.environment})"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = local.tags
  # Explicit root key policy (CKV2_AWS_64); downstream services (EKS, ECR,
  # External Secrets) are granted use via their IAM policies, which the root
  # grant enables.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableRootAccount"
      Effect    = "Allow"
      Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "app" {
  name          = "alias/${local.name}-app"
  target_key_id = aws_kms_key.app.key_id
}

# --- GitHub Actions OIDC provider (no static AWS keys in CI; Principle VII) ---
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # AWS validates GitHub's OIDC certs against its trusted CA; the thumbprint is
  # required by the API but no longer the trust anchor. This is the documented value.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = local.tags
}

# --- Modules ------------------------------------------------------------------
module "network" {
  source             = "./modules/network"
  name               = local.name
  cidr               = var.vpc_cidr
  azs                = local.azs
  cluster_name       = local.cluster_name
  single_nat_gateway = var.single_nat_gateway
  tags               = local.tags
}

module "eks" {
  source                 = "./modules/eks"
  name                   = local.cluster_name
  cluster_version        = var.eks_cluster_version
  private_subnet_ids     = module.network.private_subnet_ids
  public_subnet_ids      = module.network.public_subnet_ids
  kms_key_arn            = aws_kms_key.app.arn
  endpoint_public_access = true
  public_access_cidrs    = var.eks_public_access_cidrs
  node_instance_types    = var.eks_node_instance_types
  node_min_size          = var.eks_node_min_size
  node_max_size          = var.eks_node_max_size
  node_desired_size      = var.eks_node_desired_size
  tags                   = local.tags
}

module "openbao" {
  source            = "./modules/openbao"
  name              = local.name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  tags              = local.tags
}

module "registries" {
  source           = "./modules/registries"
  name             = local.name
  kms_key_arn      = aws_kms_key.app.arn
  ecr_repositories = var.ecr_repositories
  tags             = local.tags
}

# =============================================================================
# Shared least-privilege roles (published as a map in outputs.tf)
# =============================================================================

# --- gha-deploy: assumed by GitHub Actions via OIDC, scoped to push images ---
data "aws_iam_policy_document" "gha_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
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
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for r in var.github_deploy_repos : "repo:${var.github_org}/${r}:ref:${var.github_deploy_ref}"]
    }
  }
}

data "aws_iam_policy_document" "gha_deploy_perms" {
  # ECR login token is account-scoped by API design.
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  # Push/pull limited to this foundation's repos.
  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer",
    ]
    resources = ["arn:${local.partition}:ecr:${var.region}:${local.account_id}:repository/${local.name}/*"]
  }
  # Read the cluster descriptor to build a kubeconfig (GitOps sync runs in-cluster).
  statement {
    sid       = "EksDescribe"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:${local.partition}:eks:${var.region}:${local.account_id}:cluster/${local.cluster_name}"]
  }
}

# --- external-secrets: IRSA role for the External Secrets Operator -----------
# Used during the SM/SSM -> OpenBao migration window to read legacy secrets.
data "aws_iam_policy_document" "eso_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eso_perms" {
  statement {
    sid       = "ReadSecretsManager"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["arn:${local.partition}:secretsmanager:${var.region}:${local.account_id}:secret:czid/*"]
  }
  statement {
    sid       = "ReadSsm"
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:${local.partition}:ssm:${var.region}:${local.account_id}:parameter/czid/*"]
  }
  statement {
    sid       = "DecryptAppKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.app.arn]
  }
}

resource "aws_iam_role" "shared" {
  for_each = {
    "gha-deploy"       = data.aws_iam_policy_document.gha_assume.json
    "external-secrets" = data.aws_iam_policy_document.eso_assume.json
  }
  name               = "${local.name}-${each.key}"
  assume_role_policy = each.value
  tags               = local.tags
}

resource "aws_iam_role_policy" "shared" {
  for_each = {
    "gha-deploy"       = data.aws_iam_policy_document.gha_deploy_perms.json
    "external-secrets" = data.aws_iam_policy_document.eso_perms.json
  }
  name   = each.key
  role   = aws_iam_role.shared[each.key].id
  policy = each.value
}
