# =============================================================================
# Canonical Terraform version + provider constraints — THE single source of truth.
#
# This file is symlinked into every root stack as `versions.tf`. Bump a version
# here ONCE and every stack moves together — no drift, no per-stack edits.
# (Do not edit the copy in a stack; edit this file.)
#
# Keep providers MPL-2.0 / permissively licensed — no BUSL/SSPL.
# =============================================================================
terraform {
  required_version = ">= 1.10" # >= 1.10 for native S3 state locking (use_lockfile)

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.100" }
    random = { source = "hashicorp/random", version = "~> 3.4" }
    null   = { source = "hashicorp/null", version = "~> 3.2" }
  }
}
