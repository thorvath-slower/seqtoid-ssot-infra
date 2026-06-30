#!/usr/bin/env bash
# Layer: charts — render Helm charts + validate the manifests with kubeconform (no cluster).

_chart_render_validate() {  # chart_path  values_args...
  local chart="$1"; shift
  helm template release "$chart" "$@" > /tmp/.harness-chart.yaml 2>/tmp/.harness-chart.err || {
    cat /tmp/.harness-chart.err; return 1
  }
  if command -v kubeconform >/dev/null 2>&1; then
    kubeconform -strict -summary -ignore-missing-schemas /tmp/.harness-chart.yaml
  else
    echo "helm template OK (kubeconform absent — schema validation skipped)"
  fi
}

check_charts() {
  command -v helm >/dev/null 2>&1 || { skip_check "charts" "helm not installed"; return; }

  # App chart (seqtoid-web) — present once the #12 chart branch is integrated.
  if [ -d "$APP_REPO/$APP_CHART" ]; then
    run_check "charts:seqtoid-web (default)" -- _chart_render_validate "$APP_REPO/$APP_CHART"
    for vf in values-k3s.yaml values-single-tenant.yaml; do
      [ -f "$APP_REPO/$APP_CHART/$vf" ] && \
        run_check "charts:seqtoid-web ($vf)" -- _chart_render_validate "$APP_REPO/$APP_CHART" -f "$APP_REPO/$APP_CHART/$vf"
    done
  else
    skip_check "charts:seqtoid-web" "chart not on current checkout (lives on the #12 branch)"
  fi

  # Pipeline-runner chart (seqtoid-workflows) — present once the #72 branch is integrated.
  if [ -d "$WORKFLOWS_REPO/$RUNNER_CHART" ]; then
    run_check "charts:seqtoid-pipeline-runner" -- _chart_render_validate "$WORKFLOWS_REPO/$RUNNER_CHART"
  else
    skip_check "charts:seqtoid-pipeline-runner" "chart not on current checkout (lives on the #72 branch)"
  fi
}
