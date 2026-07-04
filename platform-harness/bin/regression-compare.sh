#!/usr/bin/env bash
# regression-compare.sh — SINGLE-REPO regression comparator for the reusable CI gate.
#
# Re-measures the metrics a repo cares about and exits NON-ZERO if any regressed vs a committed
# baseline. This is the single-repo analogue of checks/80-regression.sh; both reuse lib/metrics.sh
# (the one source of metric-extraction truth) so the numbers can't drift between local + CI.
#
#   regression-compare.sh --baseline .regression-baseline.json \
#        [--app-log ci-local.log]           # → app.rspec.* / app.jest.*
#        [--coverage coverage/.last_run.json]# → app.coverage.line
#        [--checkov-dir terraform] [--repo .]# → checkov.passed  (+ tf.resource_blocks, informational)
#        [--coverage-tol 0.5]
#
# Baseline JSON (only the keys present are enforced):
#   { "metrics": { "app.rspec.examples":1708, "app.rspec.failures":0, "app.jest.total":420,
#                  "app.jest.failed":0, "app.coverage.line":72.1, "checkov.passed":119 } }
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib/metrics.sh"
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }

BASELINE=""; APP_LOG=""; COV_FILE=""; CKV_DIR=""; REPO="."; COV_TOL="0.5"
while [ $# -gt 0 ]; do
  case "$1" in
    --baseline) BASELINE="$2"; shift ;;
    --app-log) APP_LOG="$2"; shift ;;
    --coverage) COV_FILE="$2"; shift ;;
    --checkov-dir) CKV_DIR="$2"; shift ;;
    --repo) REPO="$2"; shift ;;
    --coverage-tol) COV_TOL="$2"; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac; shift
done
[ -f "$BASELINE" ] || { echo "ERROR: baseline not found: $BASELINE (run capture-baseline on a green main and commit it)" >&2; exit 2; }

_bl() { jq -r --arg k "$1" '.metrics[$k] // "NA"' "$BASELINE" 2>/dev/null; }
FAILS=0; C_R=$'\033[31m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_0=$'\033[0m'
[ -t 1 ] || { C_R=""; C_G=""; C_Y=""; C_0=""; }
pass() { printf '  %s✔%s %s\n' "$C_G" "$C_0" "$1"; }
fail() { printf '  %sx REGRESSION%s %s\n' "$C_R" "$C_0" "$1"; FAILS=$((FAILS+1)); }
skip() { printf '  %s⊘%s %s\n' "$C_Y" "$C_0" "$1"; }

cmp_up()   { local n="$1" b="$2" c="$3" t="${4:-0}"
  if ! is_num "$b" || ! is_num "$c"; then skip "$n unmeasured (baseline=$b current=$c)"; return; fi
  if awk -v b="$b" -v c="$c" -v t="$t" 'BEGIN{exit !(c+0.0000001 >= b-t)}'; then pass "$n (>=$b, got $c)"
  else fail "$n dropped $b -> $c (tol $t)"; fi; }
cmp_zero() { local n="$1" c="$2"
  if ! is_num "$c"; then skip "$n unmeasured"; return; fi
  if [ "${c%.*}" -eq 0 ] 2>/dev/null; then pass "$n (==0)"; else fail "$n = $c (must be 0)"; fi; }
info()     { local n="$1" b="$2" c="$3"
  if is_num "$b" && is_num "$c"; then
    if awk -v b="$b" -v c="$c" 'BEGIN{exit !(c<b)}'; then skip "$n inventory decreased $b -> $c (verify intentional)"
    else printf '  · %s (%s -> %s)\n' "$n" "$b" "$c"; fi
  else skip "$n unmeasured"; fi; }

echo "regression-compare vs $BASELINE"

# app suite counts
if [ -n "$APP_LOG" ]; then
  read -r ex fa < <(metric_rspec_from_log "$APP_LOG")
  read -r jt jf < <(metric_jest_from_log "$APP_LOG")
  cmp_up   "app.rspec.examples" "$(_bl app.rspec.examples)" "$ex"
  cmp_zero "app.rspec.failures" "$fa"
  cmp_up   "app.jest.total"     "$(_bl app.jest.total)"     "$jt"
  cmp_zero "app.jest.failed"    "$jf"
fi
# coverage
if [ -n "$COV_FILE" ]; then
  cov=$(COV="$COV_FILE"; f="$COV_FILE"; [ -f "$f" ] && jq -r '.result.line // .result.covered_percent // "NA"' "$f" 2>/dev/null || echo NA)
  cmp_up "app.coverage.line" "$(_bl app.coverage.line)" "$cov" "$COV_TOL"
fi
# checkov + tf inventory (infra repos)
if [ -n "$CKV_DIR" ]; then
  cmp_up "checkov.passed"      "$(_bl checkov.passed)"      "$(metric_checkov_passed "$REPO" "$CKV_DIR")"
  info   "tf.resource_blocks"  "$(_bl tf.resource_blocks)"  "$(metric_tf_resource_blocks "$REPO" "$CKV_DIR")"
fi

echo
if [ "$FAILS" -eq 0 ]; then echo "${C_G}regression gate: PASS${C_0}"; exit 0
else echo "${C_R}regression gate: FAIL ($FAILS regression(s))${C_0}"; exit 1; fi
