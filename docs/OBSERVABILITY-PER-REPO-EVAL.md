# Observability & Monitoring -- Per-Repo Evaluation

Ticket: Forgejo #152 (CZID-152). Feeds platform epic #14 (CZID-14) --
OpenTelemetry + Prometheus/Loki/Tempo/Grafana + SLOs.
Related: #426 (OTel infra, CLOSED/wired), #382 (Sentry resolution EPIC),
#552 (Sentry release/deploy tracking in CD), CZID-154 (Sentry SDK migration).

Status: evaluation only. No code/config changed. The DECISION on the platform
observability stack (self-hosted Prometheus/Loki/Tempo/Grafana vs AWS-native
X-Ray/CloudWatch, and the per-repo remediation order) stays Tom's.

---

## 1. Purpose and method

This doc inventories the current observability posture of every repo in the
platform and states, per repo, what exists, what is missing, and the concrete
recommendation that ladders up to the #14 platform stack. It is the per-repo
companion to #14: #14 owns the shared backend (collector + storage + dashboards
+ SLOs); this doc owns "what must each repo EMIT, and what is the gap."

Evidence was gathered by reading source across all repos (Gemfiles, initializers,
package.json, Terraform modules, Helm charts, CI workflows). File paths below are
absolute.

### The intended architecture (already partly built under #426)

Apps emit vendor-neutral **OTLP** -> an in-cluster **ADOT collector** (AWS
Distro for OpenTelemetry) -> AWS-native backends today (X-Ray traces, CloudWatch
EMF metrics, CloudWatch Logs). The backend is swappable by editing ONLY the
collector's exporter config -- this is the seam the #14 epic uses to move to
self-hosted Prometheus/Loki/Tempo/Grafana without touching app code. Error
tracking (Sentry) stays as a separate front-line signal for the app; OTel is the
backend/infra layer. This split is deliberate and should be preserved.

The three observability pillars, mapped to what exists today:

| Pillar | App-side emitter | Collector | Backend today | #14 target backend |
|---|---|---|---|---|
| Traces | opentelemetry-ruby SDK (OTLP) | ADOT | AWS X-Ray | Tempo |
| Metrics | OTLP + custom CloudWatch puts | ADOT (awsemf) | CloudWatch EMF | Prometheus |
| Logs | lograge JSON -> stdout | ADOT / awslogs | CloudWatch Logs | Loki |
| Errors | Sentry (FE + BE SDK) | n/a (direct) | Sentry SaaS | Sentry (kept) |

---

## 2. Per-repo evaluation

### 2.1 seqtoid-web (Rails app + Resque/Shoryuken workers) -- MOST INSTRUMENTED

The reference implementation. Nearly every pillar is present.

- **Errors (Sentry) -- PRESENT, on the maintained SDK.**
  - `Gemfile`: `gem "sentry-ruby", "~> 5.17"` + `gem "sentry-rails", "~> 5.17"`
    (migrated off EOL `sentry-raven` under CZID-154).
  - `config/initializers/sentry.rb`: `Sentry.init` gated on `SENTRY_DSN_BACKEND`;
    sets `config.environment` from `RAILS_ENV`; `traces_sample_rate = 0.0`
    (tracing is deliberately deferred to OTel); `send_default_pii = false`.
  - `app/controllers/application_controller.rb`: `set_sentry_context` attaches
    user id/admin + request context.
  - Frontend: `package.json` `@sentry/browser` + `@sentry/react` `^8.55.2`;
    `app/assets/src/index.tsx` `Sentry.init({ ..., environment, release:
    window.GIT_RELEASE_SHA })` plus `ErrorBoundary.tsx`.
  - **Gap:** the FRONTEND sends `release` (GIT_RELEASE_SHA) but the BACKEND
    initializer does NOT set `config.release`. This is exactly what #552 fixes
    (release + deploy association in CD). Without it there are no suspect-commits
    and no accurate regression windows on backend issues.
- **Traces (OpenTelemetry) -- PRESENT (#426).**
  - `Gemfile`: `opentelemetry-sdk`, `opentelemetry-exporter-otlp`,
    `opentelemetry-instrumentation-all`.
  - `config/initializers/opentelemetry.rb`: no-op unless
    `OTEL_EXPORTER_OTLP_ENDPOINT` is set (injected via chamber/SSM
    `idseq-<env>-web`); `c.use_all` auto-instruments Rack/Rails/ActiveRecord/
    Mysql2/AWS SDK/Redis/Resque/GraphQL; derives service name
    (`seqtoid-web` / `seqtoid-resque` / `seqtoid-shoryuken`) from the process.
  - Custom `OpenTelemetryShoryukenMiddleware` wraps each SQS message in a
    CONSUMER span with exception recording -- Shoryuken has no bundled
    instrumentation, so worker context propagation is done by hand. Resque is
    covered by `use_all`.
- **Logs -- PRESENT (structured JSON via lograge).**
  - `Gemfile`: `gem 'lograge'`. Enabled in all four real envs
    (`config/environments/{development,staging,sandbox,prod}.rb`) with
    `Lograge::Formatters::Json`, logging to STDOUT (container -> CloudWatch),
    `ignore_actions` for the health-check endpoint.
- **Metrics -- PRESENT (custom CloudWatch).**
  - `lib/cloudwatch_util.rb` (`CloudWatchUtil.put_metric_data`) and
    `lib/instrument.rb` (`Instrument.snippet` over `ActiveSupport::Notifications`,
    `cloudwatch_namespace` + `extra_dimensions`), used e.g. in
    `lib/tasks/pipeline_monitor.rake` ("Pipeline Run Count").
- **Health checks -- PRESENT.**
  - `health_check` gem; route `get 'health_check'`. Helm charts
    (`deploy/charts/seqtoid-web`, `.../seqtoid-node-backend`) set readiness +
    liveness on `/health_check`; worker exec-liveness probes (pgrep); the
    blue/green `analysistemplate.yaml` smoke Job curls the preview color's
    `/health_check` as the promotion gate (metric-based gate deferred, #326).
- **Datadog remnants -- NONE.** Repo is Datadog-free.

Recommendation: this repo is the template. Two concrete gaps to close:
(1) backend Sentry `config.release` + CD release/deploy step (#552);
(2) upgrade the blue/green promotion gate from a smoke curl to a Prometheus
metric-based `AnalysisTemplate` once #14's Prometheus lands (#326, named in #14).

### 2.2 cypherid-web-infra -- OTEL COLLECTOR + ALARMS + DASHBOARDS

The infra repo that carries the collector and most of the AWS-native monitoring.

- **Collector (ADOT) -- PRESENT (#426).**
  - `terraform/modules/otel-collector/` -- ADOT collector as an ECS gateway
    service; OTLP in (gRPC + HTTP); config from SSM (`AOT_CONFIG_CONTENT`);
    exporters `awsemf` (CloudWatch EMF, namespace `seqtoid/<env>`), `awsxray`
    (traces), `awscloudwatchlogs`; image
    `public.ecr.aws/aws-observability/aws-otel-collector:v0.43.3`.
  - Deployed in ALL FOUR envs: `terraform/envs/{dev,prod,sandbox,staging}/otel/`.
- **Metrics + Alerting -- PRESENT.**
  - `terraform/modules/service-monitoring/main.tf`: ~16
    `aws_cloudwatch_metric_alarm`s (ECS cpu/memory/running-tasks, RDS
    cpu/connections/replica-lag/free-storage, OpenSearch cluster-red/jvm/storage,
    ALB 5xx/latency/unhealthy-hosts, Lambda errors/throttles) -> SNS.
  - `terraform/modules/export-control-monitoring/`: SNS topic + email sub,
    log-metric-filter alarms (blocked-jurisdiction / anonymizer-hits / app-deny),
    GuardDuty + EventBridge -> SNS (this is the #284-class fail-closed signal).
  - Per-env `terraform/envs/*/monitoring/`; `.../heatmap-optimization/
    cloudwatch_dashboard.tf` adds OpenSearch alarms + a heatmap SNS topic;
    `.../ecs/main.tf` has memory-reservation alarms.
- **Dashboards -- PRESENT.**
  - `terraform/modules/service-monitoring/dashboard.tf`
    (`aws_cloudwatch_dashboard "core_services"`); `terraform/envs/prod/dashboards/`.
- **Datadog remnants -- LEGACY, being removed.**
  - Live source still wiring a Datadog agent:
    `terraform/modules/instance-cloud-init-script/` (and `-v0.484.6`) --
    `datadog_api_key`, `site: datadoghq.com`, `/etc/datadog-agent/datadog.yaml`.
  - `terraform/modules/k8s-core-v5.5.1/variables.tf`: a DEPRECATED datadog/opsgenie
    alerts var.
  - Vendored `.terraform` caches carry `happy-datadog-dashboard` (not active
    source; scanner noise per [[scanner-noise-in-terraform-caches]]).

Recommendation: this is where the #14 backend swap happens. The collector's
exporter block is the single seam -- to move traces to Tempo / metrics to
Prometheus / logs to Loki, edit only `terraform/modules/otel-collector` (add
`otlphttp`/`prometheusremotewrite`/`loki` exporters) and keep the app side on
OTLP. Also: remove the live Datadog agent wiring in `instance-cloud-init-script*`
and the deprecated `k8s-core` datadog var as part of the Datadog decommission
(tracked with #426). Keep the CloudWatch alarms until #14's Grafana alerting is
proven, then migrate alarm rules to Grafana/Alertmanager as-code.

### 2.3 cypherid-workflow-infra -- CLOUDWATCH ALERTING + DASHBOARD (no OTel)

Pipeline/Lambda infra. Has the classic alerting module but no tracing.

- **Alerting -- PRESENT.** `terraform/modules/cloudwatch-alerting/main.tf`:
  `aws_cloudwatch_log_group`, `aws_cloudwatch_log_subscription_filter
  "idseq_alerting"` -> Lambda, `aws_secretsmanager_secret "slack_oauth_token"`
  (Slack alerting), `aws_sns_topic "aws_heatmap_topic"`.
- **Dashboards -- PRESENT.** `terraform/cloudwatch-dashboards.tf`
  (`aws_cloudwatch_dashboard "main"`).
- **Traces / Sentry / Datadog -- ABSENT** (only doc/script false positives).

Recommendation: the taxon-indexing + heatmap Lambdas here (see #479) are a
tracing blind spot -- add ADOT Lambda-layer instrumentation (or at minimum OTLP
spans around the DB->OpenSearch bulk path) so the pipeline/indexing path is
visible end-to-end, per #14 scope item 4 (pipeline/worker instrumentation). Keep
the Slack-alerting Lambda; fold its rules into the shared alerting SSOT so all
envs mirror.

### 2.4 czid-infra -- BOOTSTRAP ONLY (no observability by design)

Contents: `infra/state-foundation` (KMS key, S3 tfstate bucket, versioning/
encryption) + `templates/terraform-stack`. No alarms, SNS, OTel, Sentry, dashboards,
or Datadog in real source. Docs reference monitoring only conceptually.

Recommendation: none for the repo itself -- it is not a runtime surface. It is
the right home for the shared state/foundation only. (Note: its git origin points
at the seqtoid-ssot-infra remote; the two are being consolidated.)

### 2.5 seqtoid-ssot-infra -- FOUNDATION ALARMS + VENDORED CZTACK

The platform SSOT repo (this doc's home).

- **Alerting -- PRESENT (minimal).**
  `infra/state-foundation/foundation/monitoring.tf`: `aws_sns_topic "alerts"` +
  NAT alarms (`nat_port_allocation_errors`, `nat_packet_drops`) with
  alarm_actions/ok_actions.
- **Vendored cztack modules** (`modules/cztack/`): library modules carrying
  OPTIONAL Datadog + Prometheus features -- `aws-lambda-function` has a
  `datadog_enabled` var; `aws-eks-cluster` has `enable_kube_prometheus_stack`
  (`prometheus.io/scrape` annotations, kubecost); `aws-sns-lambda` is generic
  SNS. These are library options, not necessarily instantiated.
- **OTel / Sentry -- ABSENT.**

Recommendation: this repo should HOST the #14 platform stack as shared modules
(collector module reference, Prometheus/Loki/Tempo/Grafana Helm-as-Terraform,
SLO/alerting rules as-code) mirrored across all four envs per the infra-SSOT
doctrine. The cztack `enable_kube_prometheus_stack` option is a candidate
starting point for the self-hosted Prometheus path -- evaluate it vs a
purpose-built module during #14. Ensure the vendored `datadog_enabled` cztack
option is never turned on (part of the Datadog decommission).

### 2.6 seqtoid-ci-workflows -- NO OBSERVABILITY WORKFLOWS

Reusable workflows: `security.yml`, `drift-check.yml`, `selftest.yml`,
`terraform-ci.yml`, `flake8-action`, `ci-adoption.yaml`. No Sentry release step,
no OTel, no Datadog. All "release" matches are git-tag/version mechanics, not
Sentry releases.

Recommendation: this is the home for the #552 CD step. Add a reusable
"sentry-release" job (creates a Sentry release keyed to the git SHA,
`set-commits --auto`, `deploys new -e <env>`) that the seqtoid-web deploy
workflow calls, wiring `SENTRY_AUTH_TOKEN`/`SENTRY_ORG`/`SENTRY_PROJECT` as CI
secrets. Start dev-only per the current operating envelope; extend to
staging/prod when those pipelines are un-held. This propagates release tracking
like the security reusable does today.

### 2.7 seqtoid-workflows (WDL bioinformatics pipelines) -- STDOUT LOGGING ONLY

- **Logs -- basic.** `lib/idseq-dag/idseq_dag/util/log.py` echoes to stdout
  ("so they get to CloudWatch"); captured by AWS Batch / Step Functions ->
  CloudWatch. A helper notebook uses a CloudWatch Logs boto3 client for offline
  analysis only.
- **Errors / Traces / Metrics / in-repo alarms -- ABSENT.**

Recommendation: keep stdout->CloudWatch as the log path (correct for
Batch/SFN), but add structured (JSON) log lines and a run/stage correlation id so
logs are queryable and can be shipped to Loki under #14. Instrument the SFN
dispatch->completion path (spans + RED metrics) per #14 scope item 4; ties to the
pipeline health signals (#385/#390) and the benchmark workflow gate. No Sentry
here (batch jobs are not user-facing), but a failure-count metric/alarm on the
pipeline is worth adding to the shared alerting SSOT.

### 2.8 seqtoid-graphql-federation-server (GraphQL Mesh/Yoga, TS) -- LEAST INSTRUMENTED

- **Logs -- ad-hoc only.** `console.error/warn` in `utils/httpUtils.ts`,
  `utils/enrichToken.ts`. No structured logger (no pino/winston).
- **Errors -- ABSENT** (no `@sentry/*`). **Traces -- ABSENT** (no OpenTelemetry).
  **Metrics -- ABSENT.** **Datadog -- ABSENT.**
- **Health checks -- not configured.** GraphQL Yoga ships an implicit
  `/health` but nothing is customized/verified.

Recommendation: this is the biggest single gap -- a runtime service with
essentially no observability. Minimum bar to reach parity: (1) a structured
logger (pino) to stdout; (2) `@sentry/node` with environment + release;
(3) OpenTelemetry Node SDK (`@opentelemetry/sdk-node` + auto-instrumentations)
exporting OTLP to the same ADOT collector; (4) an explicit, probed `/health`
route in the Helm chart. Prioritize this repo in the #14 rollout.

---

## 3. Cross-cutting findings

1. **The seam already exists.** Apps emit OTLP to the ADOT collector; the #14
   backend swap is a collector-only change in cypherid-web-infra
   (`modules/otel-collector`). App code does not change to move from
   X-Ray/CloudWatch to Tempo/Prometheus/Loki. Preserve this vendor-neutrality.
2. **Coverage is uneven.** seqtoid-web is fully instrumented; the two
   non-Rails runtime services (graphql-federation-server, workflows) are the
   laggards; the collector + AWS-native alarms live in cypherid-web-infra;
   alerting also lives in cypherid-workflow-infra and (minimally) ssot-infra.
3. **Sentry release tracking is half-done.** Frontend sets `release`; backend
   does not, and there is no CD release/deploy step. #552 closes this and is the
   highest-leverage, lowest-effort observability item (dev-actionable now).
4. **Datadog is nearly gone but not fully.** seqtoid-web is clean; live Datadog
   agent wiring still exists in cypherid-web-infra
   (`instance-cloud-init-script*`, `k8s-core-v5.5.1` deprecated var) and as
   optional cztack features in ssot-infra. Finish the decommission with #426.
5. **Alerting is CloudWatch-alarm-based and slightly scattered** (three repos).
   #14 should consolidate alarm rules into a single as-code source (Grafana/
   Alertmanager) mirrored across all four envs, replacing the per-repo CloudWatch
   alarms once the self-hosted stack is proven.

---

## 4. Recommendation ladder to #14 (priority order)

| # | Item | Repo(s) | Effort | Why now |
|---|---|---|---|---|
| 1 | Backend Sentry `config.release` + CD release/deploy step (#552) | seqtoid-web, seqtoid-ci-workflows | Low | High leverage; kills manual Sentry grooming; dev-actionable |
| 2 | Finish Datadog decommission (agent wiring + cztack option) | cypherid-web-infra, ssot-infra | Low-Med | Removes dead vendor; unblocks a single observability story |
| 3 | Instrument graphql-federation-server (logger + Sentry + OTel + health) | seqtoid-graphql-federation-server | Med | Closes the largest coverage gap; a runtime service is dark |
| 4 | Instrument the pipeline/indexing path (SFN + taxon Lambdas) | seqtoid-workflows, cypherid-workflow-infra | Med | #14 scope item 4; makes the slow/opaque path visible |
| 5 | Stand up the #14 backend as shared modules, swap collector exporters | ssot-infra, cypherid-web-infra | High | The platform stack itself (Prometheus/Loki/Tempo/Grafana + SLOs) |
| 6 | Metric-based blue/green promotion gate | seqtoid-web, cypherid-web-infra | Med | #326; upgrades promotion from smoke to SLO once Prometheus exists |
| 7 | Consolidate CloudWatch alarms into as-code Grafana/Alertmanager | all infra repos | Med | Single alerting SSOT, mirrored across four envs |

---

## 5. Decision points for Tom

- **Backend choice for #14:** self-hosted Prometheus/Loki/Tempo/Grafana (more
  ops surface, no per-env vendor cost, full control) vs stay on AWS-native
  X-Ray/CloudWatch behind the collector (less to run, weaker query/SLO story).
  The app side is already vendor-neutral either way -- this is purely a
  collector-exporter + backend-infra decision.
- **Datadog decommission scope/timing:** confirm it is safe to strip the live
  agent wiring in `instance-cloud-init-script*` now (is anything still reading
  those Datadog metrics?), so #426's decommission can complete.
- **#552 rollout envelope:** dev-only now (matches the current operating
  envelope); confirm whether to author-and-hold the staging/prod extension.
- **Where the platform stack lives:** confirm ssot-infra as the home for the
  #14 shared modules (collector reference, storage, dashboards-as-code, SLO/
  alerting rules), mirrored across dev/staging/prod/sandbox.
- **graphql-federation-server priority:** confirm it moves up the queue given it
  is a live but effectively unmonitored service.
