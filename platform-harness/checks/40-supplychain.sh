#!/usr/bin/env bash
# Layer: supplychain — secret scan (gitleaks) + dependency CVE scan (trivy) across all repos.

check_supplychain() {
  # gitleaks — secret scan each repo's working tree.
  if command -v gitleaks >/dev/null 2>&1; then
    for pair in "app:$APP_REPO" "web-infra:$WEB_INFRA_REPO" "workflow-infra:$WF_INFRA_REPO" \
                "workflows:$WORKFLOWS_REPO" "foundation:$FOUNDATION_REPO"; do
      IFS=: read -r nm path <<<"$pair"
      [ -d "$path" ] || { skip_check "gitleaks:$nm" "absent"; continue; }
      run_check "gitleaks:$nm" -- gitleaks dir "$path" --no-banner --redact --exit-code 1
    done
  else
    skip_check "gitleaks" "not installed"
  fi

  # trivy — HIGH/CRITICAL dependency CVEs (fixable only) on each repo's manifests.
  if command -v trivy >/dev/null 2>&1; then
    for pair in "app:$APP_REPO" "web-infra:$WEB_INFRA_REPO" "workflow-infra:$WF_INFRA_REPO" \
                "workflows:$WORKFLOWS_REPO" "foundation:$FOUNDATION_REPO"; do
      IFS=: read -r nm path <<<"$pair"
      [ -d "$path" ] || { skip_check "trivy:$nm" "absent"; continue; }
      run_check "trivy:$nm (fixable HIGH/CRIT)" -- trivy fs --scanners vuln --severity HIGH,CRITICAL \
        --ignore-unfixed --exit-code 1 --quiet --skip-dirs '**/.terraform' "$path"
    done
  else
    skip_check "trivy" "not installed"
  fi
}
