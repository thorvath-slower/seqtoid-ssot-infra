# =============================================================================
# foundation/modules/registries — ECR (images) + CodeArtifact (packages)
# -----------------------------------------------------------------------------
# Shared artifact homes for the CZ ID stack:
#   - ECR repositories (one per service image), scan-on-push, immutable tags,
#     KMS-encrypted, with a lifecycle policy to expire untagged layers.
#   - ECR PULL-THROUGH CACHE rules that proxy the public base images we build on
#     (Docker Hub: ruby / node / mysql / redis / nginx / opensearch, ...) into
#     this account's ECR. Kills the Docker Hub rate-limit / outage risk on every
#     build for ~$1/mo of storage — the image half of the supply-chain fix
#     (GA-#511), mirroring what CodeArtifact does for packages below.
#   - A CodeArtifact domain with an internal repo that PROXIES the public
#     registries (npm / pypi / maven). Builds pull through this instead of
#     straight from the internet, which is the registry half of the supply-chain
#     fix (bug-#012 — unproxied dependencies); pinning + checksum verification
#     is enforced in the build workflows on top of this.
#
# Portability: the appliance edition ships an Artifactory/registry mirror
# instead, so this AWS-native module is cloud-only and selected out of the
# appliance profile upstream. The published endpoints keep the same shape.
# =============================================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  tags          = merge(var.tags, { "Module" = "registries" })
  registry_host = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com"
}

# --- ECR ----------------------------------------------------------------------
resource "aws_ecr_repository" "this" {
  for_each             = toset(var.ecr_repositories)
  name                 = "${var.name}/${each.value}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = local.tags
}

# Expire untagged layers after 14 days; keep the last 30 tagged images.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 14 days"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 14 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 30 tagged images"
        selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 30 }
        action       = { type = "expire" }
      },
    ]
  })
}

# --- ECR pull-through cache (public base images) ------------------------------
# One rule per upstream public registry (GA-#511). Builds repoint their FROM
# lines at "<ecr_host>/<prefix>/<upstream-path>" and ECR lazily mirrors + caches
# the layers on first pull, so Docker Hub is no longer on the critical path for
# every build (rate limits, outages). Cost is ~storage-only (~$1/mo/account).
#
# Docker Hub REQUIRES an authenticated pull-through rule: the rule references a
# Secrets Manager secret (name MUST start with "ecr-pullthroughcache/") holding
# a Docker Hub username + read-only access token. We create the secret shell
# here so the ARN is stable and IaC-owned, but the secret VALUE is populated
# out-of-band at/after apply (a real credential must never live in git). The
# ignore_changes on secret_string keeps Terraform from clobbering that value on
# subsequent applies. Anonymous/no-auth upstreams (e.g. public.ecr.aws) set
# credential_arn = null via the map and create no secret.
resource "aws_secretsmanager_secret" "pull_through" {
  for_each = { for k, v in var.pull_through_cache_rules : k => v if v.authenticated }

  # AWS mandates this exact name prefix for pull-through-cache credentials.
  name        = "ecr-pullthroughcache/${var.name}-${each.key}"
  description = "Upstream registry credentials for the ${each.key} ECR pull-through cache rule (${var.name})."
  kms_key_id  = var.kms_key_arn
  tags        = local.tags
}

# Placeholder version so the secret is never empty (a rule referencing an
# unversioned secret fails). Replaced out-of-band with the real credential;
# Terraform ignores the value thereafter.
resource "aws_secretsmanager_secret_version" "pull_through" {
  for_each = aws_secretsmanager_secret.pull_through

  secret_id = each.value.id
  secret_string = jsonencode({
    username    = "REPLACE_ME"
    accessToken = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_ecr_pull_through_cache_rule" "this" {
  for_each = var.pull_through_cache_rules

  ecr_repository_prefix = each.value.ecr_repository_prefix
  upstream_registry_url = each.value.upstream_registry_url
  credential_arn        = each.value.authenticated ? aws_secretsmanager_secret.pull_through[each.key].arn : null
}

# --- CodeArtifact -------------------------------------------------------------
resource "aws_codeartifact_domain" "this" {
  domain         = var.codeartifact_domain
  encryption_key = var.kms_key_arn
  tags           = local.tags
}

# One upstream "store" repo per ecosystem that mirrors the public registry...
resource "aws_codeartifact_repository" "upstream" {
  for_each    = var.package_ecosystems
  domain      = aws_codeartifact_domain.this.domain
  repository  = "public-${each.key}"
  description = "Proxy of the public ${each.key} registry"
  tags        = local.tags

  external_connections {
    external_connection_name = each.value
  }
}

# ...and the internal repo builds actually point at, with the proxies upstream.
resource "aws_codeartifact_repository" "internal" {
  domain      = aws_codeartifact_domain.this.domain
  repository  = var.codeartifact_internal_repo
  description = "CZ ID internal packages + proxied public deps"
  tags        = local.tags

  dynamic "upstream" {
    for_each = aws_codeartifact_repository.upstream
    content {
      repository_name = upstream.value.repository
    }
  }
}
