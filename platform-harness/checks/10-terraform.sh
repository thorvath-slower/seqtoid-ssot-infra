#!/usr/bin/env bash
# Layer: terraform — fmt -check across infra repos + validate key stacks (backend=false, no AWS).

_tf_validate_stack() {  # repo_root  stack_subdir
  cd "$1/$2" || return 1
  git config --global url."https://github.com/".insteadOf "git@github.com:" >/dev/null 2>&1 || true
  terraform init -backend=false -input=false >/dev/null && terraform validate
}

check_terraform() {
  command -v terraform >/dev/null 2>&1 || { skip_check "terraform" "terraform not installed"; return; }

  # fmt -check across the three infra repos.
  for pair in "foundation:$FOUNDATION_REPO:infra" "web-infra:$WEB_INFRA_REPO:terraform" "workflow-infra:$WF_INFRA_REPO:."; do
    IFS=: read -r nm repo sub <<<"$pair"
    [ -d "$repo" ] || { skip_check "tf-fmt:$nm" "repo absent"; continue; }
    run_check "tf-fmt:$nm" -- bash -c 'cd "$1" && terraform fmt -check -recursive "$2"' _ "$repo" "$sub"
  done

  # Validate the foundation stacks (always — they're the SSOT).
  for stack in "${FOUNDATION_STACKS[@]}"; do
    if [ -d "$FOUNDATION_REPO/$stack" ]; then
      run_check "tf-validate:foundation/$stack" -- _tf_validate_stack "$FOUNDATION_REPO" "$stack"
    else
      skip_check "tf-validate:foundation/$stack" "stack absent on current checkout"
    fi
  done

  # Validate a representative web-infra stack (or every stack with --full).
  if [ -d "$WEB_INFRA_REPO" ]; then
    if [ "${HARNESS_FULL:-0}" = 1 ]; then
      while IFS= read -r d; do
        rel="${d#"$WEB_INFRA_REPO"/}"
        run_check "tf-validate:web-infra/$rel" -- _tf_validate_stack "$WEB_INFRA_REPO" "$rel"
      done < <(find "$WEB_INFRA_REPO/terraform/envs" -type f -name '*.tf' -not -path '*/.terraform/*' -exec dirname {} \; 2>/dev/null | sort -u)
    elif [ -d "$WEB_INFRA_REPO/$WEB_INFRA_SAMPLE_STACK" ]; then
      run_check "tf-validate:web-infra/$WEB_INFRA_SAMPLE_STACK" -- _tf_validate_stack "$WEB_INFRA_REPO" "$WEB_INFRA_SAMPLE_STACK"
    fi
  fi

  # workflow-infra validate cannot run on Apple Silicon: the vendored swipe module's
  # hashicorp/template provider publishes no darwin_arm64 build (CI runs it on ubuntu).
  if [ "$(uname -m)" = "arm64" ] && [ "$(uname -s)" = "Darwin" ]; then
    skip_check "tf-validate:workflow-infra" "needs linux/amd64 (hashicorp/template has no arm64 build)"
  elif [ -d "$WF_INFRA_REPO" ]; then
    run_check "tf-validate:workflow-infra" -- _tf_validate_stack "$WF_INFRA_REPO" "."
  fi
}
