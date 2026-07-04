#!/usr/bin/env bash
# Platform harness — metric extraction for the regression-delta gate.
#
# Every extractor echoes a single number (or "NA" when it can't be measured on
# this checkout/environment) so the caller can decide skip-vs-compare. None of
# these touch AWS. The heavy ones (RSpec/Jest/coverage) parse artifacts the app
# suite already produces, rather than re-running anything.
set -uo pipefail

# --- checkov: count of PASSED policy checks in a repo's IaC (source-only).
# A DROP here means checks were removed or resources deleted/suppressed — a regression signal
# distinct from "new findings" (which the checkov layer already gates).
metric_checkov_passed() {  # <repo_root> <subdir>
  local repo="$1" sub="${2:-terraform}"
  command -v checkov >/dev/null 2>&1 || { echo "NA"; return; }
  [ -d "$repo/$sub" ] || { echo "NA"; return; }
  local n
  n=$(cd "$repo" && checkov -d "$sub" --compact --quiet --framework terraform 2>/dev/null \
        | sed -nE 's/.*Passed checks:[[:space:]]*([0-9]+).*/\1/p' | tail -1)
  [ -n "$n" ] && echo "$n" || echo "NA"
}

# --- terraform: static count of resource blocks across a repo (inventory proxy, no AWS).
# Informational — a legitimate stack removal lowers this; the gate treats it as WARN, not FAIL.
metric_tf_resource_blocks() {  # <repo_root> <subdir>
  local repo="$1" sub="${2:-.}"
  [ -d "$repo/$sub" ] || { echo "NA"; return; }
  local n
  n=$(grep -rIE '^[[:space:]]*resource[[:space:]]+"' "$repo/$sub" 2>/dev/null \
        | grep -vE '/\.terraform/|\.terraform\.lock' | wc -l | tr -d ' ')
  [ -n "$n" ] && echo "$n" || echo "NA"
}

# --- RSpec: parse "N examples, M failures[, P pending]" from a suite log.
# Echoes "examples failures" (space-separated); "NA NA" if the summary line is absent.
metric_rspec_from_log() {  # <logfile>
  local log="$1"
  [ -f "$log" ] || { echo "NA NA"; return; }
  local line ex fa
  # Last matching summary line wins (RSpec prints it once at the end; retries print more).
  line=$(grep -aE '[0-9]+ examples?, [0-9]+ failures?' "$log" 2>/dev/null | tail -1)
  [ -z "$line" ] && { echo "NA NA"; return; }
  # position-independent extraction (the number can be at start-of-line, e.g. "12 examples, 0 failures")
  ex=$(printf '%s' "$line" | grep -oE '[0-9]+ examples?' | grep -oE '^[0-9]+' | head -1)
  fa=$(printf '%s' "$line" | grep -oE '[0-9]+ failures?' | grep -oE '^[0-9]+' | head -1)
  echo "${ex:-NA} ${fa:-NA}"
}

# --- Jest: parse "Tests: ... N total" (and failed count) from a suite log.
# Echoes "total failed"; "NA NA" if absent.
metric_jest_from_log() {  # <logfile>
  local log="$1"
  [ -f "$log" ] || { echo "NA NA"; return; }
  local line total failed
  line=$(grep -aE '^Tests:' "$log" 2>/dev/null | tail -1)
  [ -z "$line" ] && { echo "NA NA"; return; }
  total=$(printf '%s' "$line" | grep -oE '[0-9]+ total' | grep -oE '^[0-9]+' | head -1)
  failed=$(printf '%s' "$line" | grep -oE '[0-9]+ failed' | grep -oE '^[0-9]+' | head -1)
  echo "${total:-NA} ${failed:-0}"
}

# --- Coverage: read SimpleCov's machine-readable last-run (line-coverage %).
# SimpleCov writes coverage/.last_run.json: {"result":{"line":78.42}} (newer) or
# {"result":{"covered_percent":78.42}} (older). Echoes the percent or "NA".
metric_coverage_line() {  # <app_repo_root>
  local repo="$1" f="$1/coverage/.last_run.json"
  [ -f "$f" ] || { echo "NA"; return; }
  command -v jq >/dev/null 2>&1 || { echo "NA"; return; }
  jq -r '.result.line // .result.covered_percent // "NA"' "$f" 2>/dev/null || echo "NA"
}

# --- helper: is a value a real number (not NA/empty)?
is_num() { case "$1" in ''|NA|na) return 1;; *[!0-9.]* ) return 1;; *) return 0;; esac; }
