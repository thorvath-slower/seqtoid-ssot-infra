#!/usr/bin/env bash
#
# plan-safety.sh — APPLY-TIME guard: fail loudly if a Terraform plan would
# DESTROY or REPLACE a stateful/data resource (Aurora/RDS, S3, EFS, etc.).
#
# Replacing any of these on a live environment = data loss or a hard outage.
# This is the gate to run before every `terraform apply` against a live stack.
#
# It is READ-ONLY with respect to your infrastructure: it only runs
# `terraform plan` (which never mutates anything) and inspects the result.
# It DOES need AWS credentials + remote-state access to produce a real plan,
# so this is an apply-time gate — NOT the offline platform harness.
#
# Usage:
#   ./plan-safety.sh <stack-dir> [-- <extra terraform plan args>]
#   ./plan-safety.sh terraform/envs/dev/db
#   ./plan-safety.sh terraform/envs/dev/db -- -var-file=dev.tfvars
#
#   # Already have a plan? Check it directly, no AWS needed:
#   terraform show -json tfplan.bin > plan.json
#   ./plan-safety.sh --plan-json plan.json
#
# Exit codes: 0 = safe (no protected destroy/replace) · 2 = DANGER (protected
# resource would be destroyed/replaced) · 1 = usage / tooling error.
#
set -euo pipefail

# --- Resource types that must never be silently destroyed/replaced on a live env.
# Extend as needed; matched against the plan's resource `type` (exact, anchored).
PROTECTED_REGEX='^aws_(rds_cluster|rds_cluster_instance|db_instance|rds_global_cluster|docdb_cluster|docdb_cluster_instance|neptune_cluster|neptune_cluster_instance|elasticache_cluster|elasticache_replication_group|s3_bucket|efs_file_system|fsx_.*|dynamodb_table|redshift_cluster|elasticsearch_domain|opensearch_domain|kms_key)$'

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

command -v jq >/dev/null 2>&1 || { red "ERROR: jq is required."; exit 1; }

PLAN_JSON=""
STACK_DIR=""
EXTRA_ARGS=()

# --- arg parsing
if [[ "${1:-}" == "--plan-json" ]]; then
  PLAN_JSON="${2:-}"
  [[ -f "$PLAN_JSON" ]] || { red "ERROR: plan json not found: $PLAN_JSON"; exit 1; }
else
  STACK_DIR="${1:-}"
  [[ -n "$STACK_DIR" && -d "$STACK_DIR" ]] || { red "ERROR: usage: $0 <stack-dir> [-- <terraform plan args>]"; exit 1; }
  shift || true
  [[ "${1:-}" == "--" ]] && shift || true
  EXTRA_ARGS=("$@")
fi

# --- produce the plan JSON (unless one was handed to us)
if [[ -z "$PLAN_JSON" ]]; then
  command -v terraform >/dev/null 2>&1 || { red "ERROR: terraform is required."; exit 1; }
  TMPDIR_PS="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR_PS"' EXIT
  PLAN_BIN="$TMPDIR_PS/tfplan.bin"
  PLAN_JSON="$TMPDIR_PS/plan.json"

  bold "==> terraform plan in: $STACK_DIR"
  # -input=false: never prompt.  -lock=false: read-only, don't take a state lock.
  if ! terraform -chdir="$STACK_DIR" plan -input=false -lock=false -out="$PLAN_BIN" "${EXTRA_ARGS[@]}"; then
    red "ERROR: terraform plan failed — resolve that before judging safety."
    exit 1
  fi
  terraform -chdir="$STACK_DIR" show -json "$PLAN_BIN" > "$PLAN_JSON"
fi

# --- analyse: any change whose actions contain "delete" is a delete or a replace.
#     (replace == ["delete","create"] or ["create","delete"]; delete == ["delete"])
DESTRUCTIVE="$(jq -c '
  [ .resource_changes[]
    | select(.change.actions | index("delete"))
    | { address, type,
        kind: (if (.change.actions == ["delete"]) then "DESTROY" else "REPLACE" end) }
  ]' "$PLAN_JSON")"

PROTECTED="$(jq -c --arg re "$PROTECTED_REGEX" '[ .[] | select(.type | test($re)) ]' <<<"$DESTRUCTIVE")"
OTHER="$(jq -c --arg re "$PROTECTED_REGEX"     '[ .[] | select(.type | test($re) | not) ]' <<<"$DESTRUCTIVE")"

n_protected="$(jq 'length' <<<"$PROTECTED")"
n_other="$(jq 'length' <<<"$OTHER")"

echo
if [[ "$n_other" -gt 0 ]]; then
  yellow "── $n_other non-protected resource(s) would be destroyed/replaced (informational):"
  jq -r '.[] | "   • [\(.kind)] \(.address)"' <<<"$OTHER"
  echo
fi

if [[ "$n_protected" -gt 0 ]]; then
  red "╔══════════════════════════════════════════════════════════════════╗"
  red "║  DANGER: this plan would DESTROY/REPLACE a stateful data resource ║"
  red "║  DO NOT APPLY — this means data loss or a hard outage.            ║"
  red "╚══════════════════════════════════════════════════════════════════╝"
  jq -r '.[] | "   ✗ [\(.kind)] \(.address)  (\(.type))"' <<<"$PROTECTED"
  echo
  red "If this is intentional (e.g. a true greenfield env), apply that stack"
  red "deliberately and out-of-band — never as part of the routine deploy."
  exit 2
fi

green "✓ SAFE: no protected data resource (RDS/S3/EFS/…) is destroyed or replaced."
[[ "$n_other" -gt 0 ]] && yellow "  (review the non-protected replacements above before applying.)"
exit 0
