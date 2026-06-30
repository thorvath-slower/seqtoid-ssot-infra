#!/usr/bin/env bash
# Platform test harness — result tracking + check runner. Robust by design:
#  - never aborts on a failing check (collects ALL results, fails at the end)
#  - per-check log captured to a file; summary table + machine-readable results
#  - PASS / FAIL / SKIP with timing; non-zero exit iff any FAIL.
set -uo pipefail

HARNESS_RESULTS="${HARNESS_RESULTS:-$(mktemp -t harness-results.XXXXXX)}"
HARNESS_LOGDIR="${HARNESS_LOGDIR:-$(mktemp -d -t harness-logs.XXXXXX)}"
: > "$HARNESS_RESULTS"

if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'; C_CYN=$'\033[36m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YLW=""; C_CYN=""; C_RST=""
fi

log()  { printf '%s[harness]%s %s\n' "$C_CYN" "$C_RST" "$*"; }
warn() { printf '%s[harness]%s %s\n' "$C_YLW" "$C_RST" "$*" >&2; }
err()  { printf '%s[harness]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }

_now() { date +%s 2>/dev/null || echo 0; }
_slug() { printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_'; }

# record STATUS NAME DURATION MESSAGE
_record() { printf '%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" >> "$HARNESS_RESULTS"; }

# run_check "name" -- cmd args...   (records PASS/FAIL; captures output)
run_check() {
  local name="$1"; shift
  [ "${1:-}" = "--" ] && shift
  local logf="$HARNESS_LOGDIR/$(_slug "$name").log"
  local start end dur
  start=$(_now)
  printf '%s▶ RUN%s  %s\n' "$C_CYN" "$C_RST" "$name"
  if "$@" >"$logf" 2>&1; then
    end=$(_now); dur=$((end - start))
    _record PASS "$name" "$dur" "ok"
    printf '%s  ✔ PASS%s %s (%ss)\n' "$C_GRN" "$C_RST" "$name" "$dur"
    return 0
  else
    end=$(_now); dur=$((end - start))
    local tailmsg; tailmsg=$(tail -n 3 "$logf" 2>/dev/null | tr '\n' ' ' | cut -c1-240)
    _record FAIL "$name" "$dur" "$tailmsg"
    printf '%s  x FAIL%s %s (%ss)  log: %s\n' "$C_RED" "$C_RST" "$name" "$dur" "$logf"
    return 1
  fi
}

# skip_check "name" "reason"
skip_check() {
  _record SKIP "$1" 0 "$2"
  printf '%s  ⊘ SKIP%s %s — %s\n' "$C_YLW" "$C_RST" "$1" "$2"
}

# assert_clean "name" "<grep-style command that should produce NO output>"
# PASS when the command yields no matching lines; FAIL (with the offending lines) otherwise.
assert_empty() {
  local name="$1"; shift
  local logf="$HARNESS_LOGDIR/$(_slug "$name").log"
  local out; out="$("$@" 2>/dev/null || true)"
  if [ -z "$out" ]; then
    _record PASS "$name" 0 "ok"
    printf '%s  ✔ PASS%s %s\n' "$C_GRN" "$C_RST" "$name"
  else
    printf '%s\n' "$out" > "$logf"
    local tailmsg; tailmsg=$(printf '%s' "$out" | head -n 3 | tr '\n' ' ' | cut -c1-240)
    _record FAIL "$name" 0 "$tailmsg"
    printf '%s  ✗ FAIL%s %s  (found: %s)  log: %s\n' "$C_RED" "$C_RST" "$name" "$tailmsg" "$logf"
  fi
}

harness_summary() {
  local pass fail skip total
  pass=$(grep -c '^PASS|' "$HARNESS_RESULTS" 2>/dev/null || true); pass=${pass:-0}
  fail=$(grep -c '^FAIL|' "$HARNESS_RESULTS" 2>/dev/null || true); fail=${fail:-0}
  skip=$(grep -c '^SKIP|' "$HARNESS_RESULTS" 2>/dev/null || true); skip=${skip:-0}
  total=$((pass + fail + skip))
  echo
  echo "================== PLATFORM HARNESS SUMMARY =================="
  while IFS='|' read -r st nm du msg; do
    local c="$C_YLW"; [ "$st" = PASS ] && c="$C_GRN"; [ "$st" = FAIL ] && c="$C_RED"
    printf '  %s%-6s%s %-50s %3ss\n' "$c" "$st" "$C_RST" "$nm" "$du"
    [ "$st" = FAIL ] && printf '         └─ %s\n' "$msg"
  done < "$HARNESS_RESULTS"
  echo "-------------------------------------------------------------"
  printf '  TOTAL %s   %sPASS %s%s   %sFAIL %s%s   %sSKIP %s%s\n' \
    "$total" "$C_GRN" "$pass" "$C_RST" "$C_RED" "$fail" "$C_RST" "$C_YLW" "$skip" "$C_RST"
  printf '  logs: %s\n' "$HARNESS_LOGDIR"
  echo "============================================================="
  [ "$fail" -eq 0 ]
}
