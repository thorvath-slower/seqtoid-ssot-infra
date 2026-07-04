#!/usr/bin/env bash
# Layer: regression — hold the line vs the last blessed baseline (checks/../baseline/main-baseline.json).
#
# This is the teeth of the main-merge gate: a static "all green" pass can hide a suite that
# silently shrank (deleted/skipped tests), coverage that slid, or policy checks that were
# suppressed. Here we RE-MEASURE the candidate and FAIL if a monotonic-up metric dropped
# below (baseline − tolerance).
#
# Metric classes:
#   monotonic-up  (FAIL on decrease):  rspec.examples, jest.total, checkov.*.passed, coverage.line
#   must-be-zero  (FAIL if nonzero):   rspec.failures, jest.failed
#   informational (WARN only):         tf.*.resource_blocks  (legit stack removal lowers it)
#
# App counts (rspec/jest) are read from $HARNESS_APP_LOG when set — CI runs the suite as
#   `make ci-local | tee "$HARNESS_APP_LOG"` before invoking the harness. Coverage is read from
#   the SimpleCov artifact. Anything NA in EITHER baseline or candidate is SKIPPED (not failed).

# baseline JSON getter: metric_key -> value ("NA" when null/absent)
_bl() { jq -r --arg k "$1" '.metrics[$k] // "NA"' "$BASELINE_FILE" 2>/dev/null; }

# monotonic-up compare: FAIL if current < baseline - tol. Handles floats via awk.
_cmp_up() {  # <name> <baseline> <current> <tol>
  local name="$1" b="$2" c="$3" tol="${4:-0}"
  if ! is_num "$b" || ! is_num "$c"; then skip_check "regr:$name" "unmeasured (baseline=$b current=$c)"; return; fi
  if awk -v b="$b" -v c="$c" -v t="$tol" 'BEGIN{exit !(c + 0.0000001 >= b - t)}'; then
    run_check "regr:$name (>=$b, got $c)" -- true
  else
    run_check "regr:$name" -- bash -c "echo 'REGRESSION: $name dropped $b -> $c (tol $tol)'; false"
  fi
}

# must-be-zero compare.
_cmp_zero() {  # <name> <current>
  local name="$1" c="$2"
  if ! is_num "$c"; then skip_check "regr:$name" "unmeasured"; return; fi
  if [ "${c%.*}" -eq 0 ] 2>/dev/null; then
    run_check "regr:$name (==0)" -- true
  else
    run_check "regr:$name" -- bash -c "echo 'REGRESSION: $name = $c (must be 0)'; false"
  fi
}

# informational delta: never fails; records the movement.
_info_delta() {  # <name> <baseline> <current>
  local name="$1" b="$2" c="$3"
  if is_num "$b" && is_num "$c"; then
    if awk -v b="$b" -v c="$c" 'BEGIN{exit !(c < b)}'; then
      skip_check "regr-info:$name" "inventory decreased $b -> $c (verify it was an intentional removal)"
    else
      run_check "regr-info:$name ($b -> $c)" -- true
    fi
  else
    skip_check "regr-info:$name" "unmeasured (baseline=$b current=$c)"
  fi
}

check_regression() {
  command -v jq >/dev/null 2>&1 || { skip_check "regression" "jq not installed"; return; }
  if [ ! -f "$BASELINE_FILE" ]; then
    skip_check "regression" "no baseline at $BASELINE_FILE — run ./capture-baseline.sh on a green main first"
    return
  fi
  log "baseline: $BASELINE_FILE (captured $(jq -r '.captured_at // "?"' "$BASELINE_FILE"))"

  # --- infra metrics: re-measured here (checkov only on --full; it's slow) ---
  if [ "${HARNESS_FULL:-0}" = 1 ]; then
    _cmp_up "checkov.web-infra.passed"      "$(_bl checkov.web-infra.passed)"      "$(metric_checkov_passed "$WEB_INFRA_REPO" terraform)"
    _cmp_up "checkov.workflow-infra.passed" "$(_bl checkov.workflow-infra.passed)" "$(metric_checkov_passed "$WF_INFRA_REPO" .)"
    _cmp_up "checkov.foundation.passed"     "$(_bl checkov.foundation.passed)"     "$(metric_checkov_passed "$FOUNDATION_REPO" infra)"
  else
    skip_check "regr:checkov.*.passed" "baselined repos — run with --full"
  fi
  _info_delta "tf.web-infra.resource_blocks"      "$(_bl tf.web-infra.resource_blocks)"      "$(metric_tf_resource_blocks "$WEB_INFRA_REPO" terraform)"
  _info_delta "tf.workflow-infra.resource_blocks" "$(_bl tf.workflow-infra.resource_blocks)" "$(metric_tf_resource_blocks "$WF_INFRA_REPO" .)"
  _info_delta "tf.foundation.resource_blocks"     "$(_bl tf.foundation.resource_blocks)"     "$(metric_tf_resource_blocks "$FOUNDATION_REPO" infra)"

  # --- coverage: from the SimpleCov artifact (needs the app suite to have run) ---
  _cmp_up "app.coverage.line" "$(_bl app.coverage.line)" "$(metric_coverage_line "$APP_REPO")" "$COVERAGE_TOLERANCE"

  # --- app suite counts: from $HARNESS_APP_LOG (CI tees `make ci-local` into it) ---
  if [ -n "${HARNESS_APP_LOG:-}" ] && [ -f "${HARNESS_APP_LOG:-/nonexistent}" ]; then
    read -r cur_ex cur_fa < <(metric_rspec_from_log "$HARNESS_APP_LOG")
    read -r cur_jt cur_jf < <(metric_jest_from_log "$HARNESS_APP_LOG")
    _cmp_up   "app.rspec.examples" "$(_bl app.rspec.examples)" "$cur_ex"
    _cmp_zero "app.rspec.failures" "$cur_fa"
    _cmp_up   "app.jest.total"     "$(_bl app.jest.total)"     "$cur_jt"
    _cmp_zero "app.jest.failed"    "$cur_jf"
  else
    skip_check "regr:app.rspec/jest.counts" "set HARNESS_APP_LOG to a 'make ci-local' log to compare suite counts"
  fi
}
