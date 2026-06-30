#!/usr/bin/env bash
# Layer: parity — static drop-in-parity assertions distilled from the jsims parity sweep.
# These guard the deployment-critical invariants (right branch, right DB, the #372 fix).

check_parity() {
  local A="$APP_REPO"
  [ -d "$A/.git" ] || { skip_check "parity:*" "app repo absent"; return; }

  # 1. The drop-in target branch exists (deploy v4, NOT main).
  if git -C "$A" rev-parse --verify -q "$APP_TARGET_BRANCH" >/dev/null 2>&1 \
     || git -C "$A" rev-parse --verify -q "origin/$APP_TARGET_BRANCH" >/dev/null 2>&1; then
    run_check "parity:app-drop-in-target-exists" -- true
  else
    run_check "parity:app-drop-in-target-exists" -- bash -c "echo 'missing branch: $APP_TARGET_BRANCH'; false"
  fi

  # 2. The drop-in target is MySQL (mysql2), not Postgres.
  run_check "parity:app-db-is-mysql2" -- bash -c \
    'git -C "$1" show "$2:Gemfile" 2>/dev/null | grep -qE "gem .mysql2."' _ "$A" "$APP_TARGET_BRANCH"
  run_check "parity:app-not-postgres" -- bash -c \
    '! git -C "$1" show "$2:Gemfile" 2>/dev/null | grep -qE "^\s*gem .pg."' _ "$A" "$APP_TARGET_BRANCH"

  # 3. The #372 fix: no Postgres :: casts in the date-histogram controllers (check the fix branch
  #    if present, else the target branch — surfaces the merge-readiness either way).
  local ref="$APP_TARGET_BRANCH"
  git -C "$A" rev-parse --verify -q "czid-372-mysql8-date-histogram-fix" >/dev/null 2>&1 \
    && ref="czid-372-mysql8-date-histogram-fix"
  assert_empty "parity:no-postgres-casts-in-date-histogram ($ref)" \
    git -C "$A" grep -nE "::(date|numeric|int)\b" "$ref" -- \
      app/controllers/samples_controller.rb app/controllers/projects_controller.rb

  # 4. redis 7.1 present in web-infra prod (jsims prod had a broken locals block).
  if [ -d "$WEB_INFRA_REPO" ]; then
    run_check "parity:web-infra-redis-7.1" -- bash -c \
      'grep -rqE "engine_version\s*=\s*.7\.1." "$1/terraform/envs/prod/redis" 2>/dev/null' _ "$WEB_INFRA_REPO"
  else
    skip_check "parity:web-infra-redis-7.1" "web-infra absent"
  fi
}
