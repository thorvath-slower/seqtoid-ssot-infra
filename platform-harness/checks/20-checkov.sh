#!/usr/bin/env bash
# Layer: checkov — IaC policy gate. Foundation is the 0-baseline hard gate; the other infra
# repos carry an accepted baseline (.checkov.baseline), so they're informational here.

check_checkov() {
  command -v checkov >/dev/null 2>&1 || { skip_check "checkov" "checkov not installed"; return; }

  # Foundation: must stay clean (it's the SSOT; checkov gate is a hard gate here).
  if [ -d "$FOUNDATION_REPO/infra" ]; then
    run_check "checkov:foundation" -- bash -c \
      'cd "$1" && checkov -d infra --compact --quiet --framework terraform' _ "$FOUNDATION_REPO"
  else
    skip_check "checkov:foundation" "foundation infra/ absent"
  fi

  # Other infra repos only on --full (they have large accepted baselines; slow).
  if [ "${HARNESS_FULL:-0}" = 1 ]; then
    for pair in "web-infra:$WEB_INFRA_REPO:terraform" "workflow-infra:$WF_INFRA_REPO:terraform"; do
      IFS=: read -r nm repo sub <<<"$pair"
      [ -d "$repo/$sub" ] || { skip_check "checkov:$nm" "absent"; continue; }
      run_check "checkov:$nm" -- bash -c \
        'cd "$1" && checkov -d "$2" --compact --quiet --framework terraform' _ "$repo" "$sub"
    done
  else
    skip_check "checkov:web-infra/workflow-infra" "baselined repos — run with --full"
  fi
}
