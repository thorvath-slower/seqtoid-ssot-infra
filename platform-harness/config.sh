#!/usr/bin/env bash
# Platform test harness — configuration (single source of truth for paths + pins).
# Override any value via the environment before invoking run.sh.

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# This harness lives in czid-infra/platform-harness. The other repo clones are siblings of czid-infra.
FOUNDATION_REPO="${FOUNDATION_REPO:-$(cd "$HARNESS_DIR/.." && pwd)}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$FOUNDATION_REPO/.." && pwd)}"

APP_REPO="${APP_REPO:-$WORKSPACE_ROOT/seqtoid-web}"
WEB_INFRA_REPO="${WEB_INFRA_REPO:-$WORKSPACE_ROOT/cypherid-web-infra}"
WF_INFRA_REPO="${WF_INFRA_REPO:-$WORKSPACE_ROOT/cypherid-workflow-infra}"
WORKFLOWS_REPO="${WORKFLOWS_REPO:-$WORKSPACE_ROOT/seqtoid-workflows}"

# The app drop-in target is the MySQL 8 branch — NOT main (main drops the NextGen/federation path).
APP_TARGET_BRANCH="${APP_TARGET_BRANCH:-version-4-mysql-latest-auth0}"

# Pinned toolchain versions (must match each repo's .terraform-version, etc.).
TERRAFORM_VERSION_EXPECTED="${TERRAFORM_VERSION_EXPECTED:-1.15.7}"

# czid-infra (foundation) Terraform stacks to validate.
FOUNDATION_STACKS=(
  "infra/state-foundation/bootstrap"
  "infra/state-foundation/foundation"
  "infra/state-foundation/consumers/seqtoid-web"
)

# A representative web-infra stack to validate (full sweep via --full).
WEB_INFRA_SAMPLE_STACK="${WEB_INFRA_SAMPLE_STACK:-terraform/envs/dev/cloud-env}"

# Helm charts to render + validate.
APP_CHART="${APP_CHART:-deploy/charts/seqtoid-web}"
RUNNER_CHART="${RUNNER_CHART:-deploy/charts/seqtoid-pipeline-runner}"

# Shared Terraform provider cache so repeated `init -backend=false` is fast + offline-after-first.
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR" 2>/dev/null || true

# --- Regression gate (checks/80-regression.sh) ---
# The blessed baseline of known-good metrics; capture it on a green main via ./capture-baseline.sh.
BASELINE_FILE="${BASELINE_FILE:-$HARNESS_DIR/baseline/main-baseline.json}"
# Allowed line-coverage slip (percentage points) before a coverage drop is called a regression.
COVERAGE_TOLERANCE="${COVERAGE_TOLERANCE:-0.5}"
# CI tees the app suite into HARNESS_APP_LOG so the regression layer can compare RSpec/Jest counts;
# unset by default (the layer skips the count comparison when it's absent).
