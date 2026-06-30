#!/usr/bin/env bash
# Layer: preflight — tool census + offline/no-AWS guard + repo presence.

check_preflight() {
  # Offline / no-AWS guard: the harness is read-only by construction (terraform -backend=false,
  # static scanners, helm template). Disable any accidental cloud calls.
  export AWS_EC2_METADATA_DISABLED=true
  export AWS_SDK_LOAD_CONFIG=0
  run_check "preflight:offline-guard" -- bash -c 'true'  # marker: harness never runs apply/real APIs

  # Required tools (FAIL if missing — core layers depend on them).
  for t in git bash; do
    if command -v "$t" >/dev/null 2>&1; then run_check "preflight:tool:$t" -- command -v "$t"
    else run_check "preflight:tool:$t" -- bash -c "echo missing; false"; fi
  done

  # Strongly-recommended tools (SKIP, don't FAIL — their layers self-skip).
  for t in terraform checkov helm kubeconform trivy gitleaks jq docker python3; do
    if command -v "$t" >/dev/null 2>&1; then
      run_check "preflight:tool:$t" -- command -v "$t"
    else
      skip_check "preflight:tool:$t" "not installed — dependent checks will SKIP"
    fi
  done

  # Repo presence.
  for pair in "app:$APP_REPO" "web-infra:$WEB_INFRA_REPO" "workflow-infra:$WF_INFRA_REPO" \
              "workflows:$WORKFLOWS_REPO" "foundation:$FOUNDATION_REPO"; do
    IFS=: read -r nm path <<<"$pair"
    if [ -d "$path/.git" ]; then run_check "preflight:repo:$nm" -- test -d "$path/.git"
    else skip_check "preflight:repo:$nm" "clone not found at $path"; fi
  done
}
