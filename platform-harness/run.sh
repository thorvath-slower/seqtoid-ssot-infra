#!/usr/bin/env bash
# Platform test harness — top-level orchestrator.
# Validates the whole platform (all repos) WITHOUT touching AWS. Runs every layer,
# collects all results, prints a summary, exits non-zero iff any check FAILED.
#
#   ./run.sh                 # all offline layers
#   ./run.sh --with-app      # also run the app suite (Docker + MySQL; slow)
#   ./run.sh --full          # deeper sweep (all stacks, full checkov)
#   ./run.sh --main-gate     # the integration→main REGRESSION gate: --full + --with-app + baseline delta
#   ./run.sh terraform parity   # only the named layers
#   ./run.sh --list          # list layers
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HARNESS_DIR/config.sh"
source "$HARNESS_DIR/lib/harness.sh"
source "$HARNESS_DIR/lib/metrics.sh"
for f in "$HARNESS_DIR"/checks/*.sh; do source "$f"; done

# 'regression' runs LAST (after app) so it can read the coverage artifact + app-suite log.
ALL_LAYERS=(preflight terraform checkov charts supplychain parity crossrepo)
WITH_APP=0; MAIN_GATE=0; LAYERS=()
export HARNESS_FULL="${HARNESS_FULL:-0}"
while [ $# -gt 0 ]; do
  case "$1" in
    --with-app) WITH_APP=1 ;;
    --full) export HARNESS_FULL=1 ;;
    --main-gate) MAIN_GATE=1; WITH_APP=1; export HARNESS_FULL=1 ;;
    --list) printf '%s\n' "${ALL_LAYERS[@]}" app regression; exit 0 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    --*) warn "unknown flag: $1" ;;
    *) LAYERS+=("$1") ;;
  esac; shift
done
# Default selection: all offline layers. --main-gate additionally pins the regression layer on.
[ ${#LAYERS[@]} -eq 0 ] && LAYERS=("${ALL_LAYERS[@]}")
[ "$MAIN_GATE" -eq 1 ] && LAYERS+=(regression)

log "platform harness — workspace: $WORKSPACE_ROOT"
log "layers: ${LAYERS[*]}$([ "$WITH_APP" -eq 1 ] && echo ' +app')   full=$HARNESS_FULL$([ "$MAIN_GATE" -eq 1 ] && echo '   [MAIN-GATE]')"

# Pass 1: every selected layer except the app suite and regression (which run after).
for layer in "${LAYERS[@]}"; do
  case "$layer" in app|regression) continue ;; esac
  if declare -F "check_$layer" >/dev/null; then
    echo; log "──── layer: $layer ────"
    "check_$layer" || true
  else
    warn "unknown layer: $layer (try --list)"
  fi
done

# The app suite (Docker+MySQL) — produces the coverage artifact + (via HARNESS_APP_LOG) the suite log.
if [ "$WITH_APP" -eq 1 ]; then echo; log "──── layer: app ────"; check_app || true; fi

# Regression delta LAST, so it sees whatever the app layer just produced.
case " ${LAYERS[*]} " in
  *" regression "*) echo; log "──── layer: regression ────"; check_regression || true ;;
esac

harness_summary
