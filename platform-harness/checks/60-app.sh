#!/usr/bin/env bash
# Layer: app — the Rails app suite (RSpec/lint/JS/Python) in Docker against MySQL.
# Heavy + slow; only runs with --with-app. Validates the v4 (MySQL 8) drop-in target.

check_app() {
  [ -d "$APP_REPO/.git" ] || { skip_check "app:ci-local" "app repo absent"; return; }
  command -v docker >/dev/null 2>&1 || { skip_check "app:ci-local" "docker not available"; return; }
  if ! docker info >/dev/null 2>&1; then skip_check "app:ci-local" "docker daemon not running"; return; fi

  # Run the repo's own containerized CI runner (Docker + MySQL), which mirrors GitHub Actions.
  if [ -x "$APP_REPO/bin/ci-local" ] || grep -qE '^ci-local:' "$APP_REPO/Makefile" 2>/dev/null; then
    run_check "app:ci-local (Docker+MySQL, v4)" -- bash -c 'cd "$1" && make ci-local' _ "$APP_REPO"
  else
    skip_check "app:ci-local" "bin/ci-local / make ci-local not found on current checkout"
  fi
}
