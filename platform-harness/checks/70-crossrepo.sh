#!/usr/bin/env bash
# Layer: crossrepo — consistency invariants ACROSS repos (drift is the SSOT failure mode).

check_crossrepo() {
  # Terraform version pin must be identical across every infra repo that has converted.
  local found=0 mismatch=""
  for pair in "foundation:$FOUNDATION_REPO" "web-infra:$WEB_INFRA_REPO" "workflow-infra:$WF_INFRA_REPO"; do
    IFS=: read -r nm repo <<<"$pair"
    local vf="$repo/.terraform-version"
    if [ -f "$vf" ]; then
      found=$((found+1))
      local v; v="$(tr -d '[:space:]' < "$vf")"
      if [ "$v" != "$TERRAFORM_VERSION_EXPECTED" ]; then
        mismatch="$mismatch $nm=$v"
      fi
    fi
  done
  if [ "$found" -eq 0 ]; then
    skip_check "crossrepo:terraform-version" "no .terraform-version on current checkouts (conversion unmerged)"
  elif [ -n "$mismatch" ]; then
    run_check "crossrepo:terraform-version=$TERRAFORM_VERSION_EXPECTED" -- bash -c "echo 'mismatch:$1'; false" _ "$mismatch"
  else
    run_check "crossrepo:terraform-version=$TERRAFORM_VERSION_EXPECTED ($found repos)" -- true
  fi

  # No leftover OpenTofu/tofu references in any infra repo's working tree (conversion completeness).
  for pair in "foundation:$FOUNDATION_REPO" "web-infra:$WEB_INFRA_REPO" "workflow-infra:$WF_INFRA_REPO"; do
    IFS=: read -r nm repo <<<"$pair"
    [ -d "$repo" ] || continue
    if [ -f "$repo/.terraform-version" ]; then   # only assert on converted checkouts
      assert_empty "crossrepo:no-tofu-refs:$nm" bash -c \
        'grep -rIE "opentofu|OpenTofu|\btofu\b" "$1" 2>/dev/null | grep -vE "\.terraform/|terraform\.tfstate|\.terraform\.lock|\.git/" | head' _ "$repo"
    else
      skip_check "crossrepo:no-tofu-refs:$nm" "not on a converted checkout"
    fi
  done
}
