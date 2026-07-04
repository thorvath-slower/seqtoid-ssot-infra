#!/usr/bin/env bash
# capture-baseline.sh — snapshot the current known-good metrics into a baseline manifest.
#
# Run this on a GREEN `main` (or the promotion candidate you're blessing) to record the
# numbers the regression gate will hold the line against: RSpec/Jest counts, coverage %,
# per-repo checkov pass-counts, and a terraform inventory proxy. The gate (checks/80-regression.sh)
# then FAILS a future merge if any of these regresses.
#
#   ./capture-baseline.sh                          # infra metrics + coverage artifact (fast, no Docker)
#   ./capture-baseline.sh --app-log ci-local.log   # also fold in RSpec/Jest counts from a saved suite log
#   ./capture-baseline.sh --run-app                # run `make ci-local` (Docker+MySQL) and capture from it
#   ./capture-baseline.sh -o baseline/main-baseline.json
#
# It is READ-ONLY w.r.t. infrastructure. Output is a flat JSON manifest; commit it alongside the harness.
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HARNESS_DIR/config.sh"
source "$HARNESS_DIR/lib/metrics.sh"
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 1; }

OUT="$HARNESS_DIR/baseline/main-baseline.json"
APP_LOG=""; RUN_APP=0
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUT="$2"; shift ;;
    --app-log) APP_LOG="$2"; shift ;;
    --run-app) RUN_APP=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac; shift
done
mkdir -p "$(dirname "$OUT")"

echo "[capture] gathering infra metrics (no AWS)…" >&2
CKV_WEB=$(metric_checkov_passed "$WEB_INFRA_REPO" terraform)
CKV_WF=$(metric_checkov_passed "$WF_INFRA_REPO" .)
CKV_FND=$(metric_checkov_passed "$FOUNDATION_REPO" infra)
TFB_WEB=$(metric_tf_resource_blocks "$WEB_INFRA_REPO" terraform)
TFB_WF=$(metric_tf_resource_blocks "$WF_INFRA_REPO" .)
TFB_FND=$(metric_tf_resource_blocks "$FOUNDATION_REPO" infra)

# Optionally run the app suite to produce a fresh log to parse.
if [ "$RUN_APP" = 1 ] && [ -z "$APP_LOG" ]; then
  if docker info >/dev/null 2>&1 && grep -qE '^ci-local:' "$APP_REPO/Makefile" 2>/dev/null; then
    APP_LOG="$(mktemp -t ci-local.XXXXXX.log)"
    echo "[capture] running app suite (make ci-local) → $APP_LOG …" >&2
    ( cd "$APP_REPO" && make ci-local ) >"$APP_LOG" 2>&1 || echo "[capture] WARN: app suite exited non-zero (capturing counts anyway)" >&2
  else
    echo "[capture] WARN: --run-app requested but Docker/ci-local unavailable; app metrics = NA" >&2
  fi
fi

RSPEC_EX=NA; RSPEC_FA=NA; JEST_TOT=NA; JEST_FAIL=NA
if [ -n "$APP_LOG" ]; then
  read -r RSPEC_EX RSPEC_FA < <(metric_rspec_from_log "$APP_LOG")
  read -r JEST_TOT JEST_FAIL < <(metric_jest_from_log "$APP_LOG")
fi
COV=$(metric_coverage_line "$APP_REPO")

# Record the exact commit each metric was captured from (provenance for the delta).
sha() { git -C "$1" rev-parse --short HEAD 2>/dev/null || echo "unknown"; }

jq -n \
  --arg captured_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg host "$(uname -sm)" \
  --arg sha_app "$(sha "$APP_REPO")" \
  --arg sha_web "$(sha "$WEB_INFRA_REPO")" \
  --arg sha_wf "$(sha "$WF_INFRA_REPO")" \
  --arg sha_fnd "$(sha "$FOUNDATION_REPO")" \
  --arg app_branch "$APP_TARGET_BRANCH" \
  --argjson rspec_ex "$(is_num "$RSPEC_EX" && echo "$RSPEC_EX" || echo null)" \
  --argjson rspec_fa "$(is_num "$RSPEC_FA" && echo "$RSPEC_FA" || echo null)" \
  --argjson jest_tot "$(is_num "$JEST_TOT" && echo "$JEST_TOT" || echo null)" \
  --argjson jest_fail "$(is_num "$JEST_FAIL" && echo "$JEST_FAIL" || echo null)" \
  --argjson cov "$(is_num "$COV" && echo "$COV" || echo null)" \
  --argjson ckv_web "$(is_num "$CKV_WEB" && echo "$CKV_WEB" || echo null)" \
  --argjson ckv_wf "$(is_num "$CKV_WF" && echo "$CKV_WF" || echo null)" \
  --argjson ckv_fnd "$(is_num "$CKV_FND" && echo "$CKV_FND" || echo null)" \
  --argjson tfb_web "$(is_num "$TFB_WEB" && echo "$TFB_WEB" || echo null)" \
  --argjson tfb_wf "$(is_num "$TFB_WF" && echo "$TFB_WF" || echo null)" \
  --argjson tfb_fnd "$(is_num "$TFB_FND" && echo "$TFB_FND" || echo null)" \
  '{
    captured_at: $captured_at, host: $host, app_branch: $app_branch,
    commits: { "seqtoid-web": $sha_app, "cypherid-web-infra": $sha_web,
               "cypherid-workflow-infra": $sha_wf, "foundation": $sha_fnd },
    metrics: {
      "app.rspec.examples":  $rspec_ex,
      "app.rspec.failures":  $rspec_fa,
      "app.jest.total":      $jest_tot,
      "app.jest.failed":     $jest_fail,
      "app.coverage.line":   $cov,
      "checkov.web-infra.passed":     $ckv_web,
      "checkov.workflow-infra.passed":$ckv_wf,
      "checkov.foundation.passed":    $ckv_fnd,
      "tf.web-infra.resource_blocks":     $tfb_web,
      "tf.workflow-infra.resource_blocks":$tfb_wf,
      "tf.foundation.resource_blocks":    $tfb_fnd
    }
  }' > "$OUT"

echo "[capture] wrote $OUT" >&2
jq . "$OUT"
