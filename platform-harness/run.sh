#!/usr/bin/env bash
# Platform test harness — top-level orchestrator.
# Validates the whole platform (all repos) WITHOUT touching AWS. Runs every layer,
# collects all results, prints a summary, exits non-zero iff any check FAILED.
#
#   ./run.sh                 # all offline layers
#   ./run.sh --with-app      # also run the app suite (Docker + MySQL; slow)
#   ./run.sh --full          # deeper sweep (all stacks, full checkov)
#   ./run.sh terraform parity   # only the named layers
#   ./run.sh --list          # list layers
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HARNESS_DIR/config.sh"
source "$HARNESS_DIR/lib/harness.sh"
for f in "$HARNESS_DIR"/checks/*.sh; do source "$f"; done

ALL_LAYERS=(preflight terraform checkov charts supplychain parity crossrepo)
WITH_APP=0; LAYERS=()
export HARNESS_FULL="${HARNESS_FULL:-0}"
while [ $# -gt 0 ]; do
  case "$1" in
    --with-app) WITH_APP=1 ;;
    --full) export HARNESS_FULL=1 ;;
    --list) printf '%s\n' "${ALL_LAYERS[@]}" app; exit 0 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    --*) warn "unknown flag: $1" ;;
    *) LAYERS+=("$1") ;;
  esac; shift
done
[ ${#LAYERS[@]} -eq 0 ] && LAYERS=("${ALL_LAYERS[@]}")

log "platform harness — workspace: $WORKSPACE_ROOT"
log "layers: ${LAYERS[*]}$([ "$WITH_APP" -eq 1 ] && echo ' +app')   full=$HARNESS_FULL"

for layer in "${LAYERS[@]}"; do
  if declare -F "check_$layer" >/dev/null; then
    echo; log "──── layer: $layer ────"
    "check_$layer" || true
  else
    warn "unknown layer: $layer (try --list)"
  fi
done
if [ "$WITH_APP" -eq 1 ]; then echo; log "──── layer: app ────"; check_app || true; fi

harness_summary
