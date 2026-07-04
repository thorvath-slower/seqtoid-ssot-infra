# Platform Test Harness

A mission-critical, **offline (no-AWS)** validation harness for the whole platform — all repos at
once. It's the gate we run **before/while merging** the modernization branches and **before** any
deployment, so integration breakage and parity regressions surface immediately.

> Read-only by construction: `terraform` runs with `-backend=false`, scanners are static, charts are
> `helm template`-only. It never calls AWS and never applies anything.

## Usage

```bash
cd platform-harness                    # the harness lives in the SSOT repo (seqtoid-ssot-infra)
./run.sh                               # all offline layers
./run.sh --with-app                    # also run the Rails suite (Docker + MySQL; slow)
./run.sh --full                        # deeper sweep (every web-infra stack, full checkov)
./run.sh --main-gate                   # the integration→main REGRESSION gate (--full + --with-app + baseline delta)
./run.sh terraform parity              # only the named layers
./run.sh --list                        # list layers
```

It validates **whatever each repo currently has checked out**, so for an integration check, check out
the target branches first (app = `version-4-mysql-latest-auth0`, infra = the merge target). Point it at
the clones with `WORKSPACE_ROOT` / `FOUNDATION_REPO` if they aren't siblings of this repo.

The run **collects every result** (never aborts mid-way), prints a summary table, and **exits non-zero
iff any check FAILED**. Each check writes a log under the printed `logs:` dir.

## Layers

| Layer | What it checks | Tools |
|---|---|---|
| `preflight` | tool census + offline guard + repo presence | — |
| `terraform` | `fmt -check` across infra repos + `validate` of foundation stacks + a web-infra stack (`--full` = all) | terraform |
| `checkov` | IaC policy — foundation as a 0-baseline hard gate (`--full` = all infra) | checkov |
| `charts` | `helm template` + kubeconform on the app + runner charts (incl. value profiles) | helm, kubeconform |
| `supplychain` | secret scan + fixable HIGH/CRITICAL dependency CVEs, every repo | gitleaks, trivy |
| `parity` | drop-in invariants from the jsims sweep: target branch exists, app is MySQL (not Postgres), no Postgres `::` casts in the date-histogram (#372), redis 7.1 | git, grep |
| `crossrepo` | cross-repo consistency: identical Terraform version pin, no leftover `tofu`/OpenTofu refs | — |
| `app` *(--with-app)* | the Rails suite (RSpec/lint/JS/Python) in Docker against MySQL — mirrors GitHub Actions | docker |
| `regression` *(--main-gate / named)* | **holds the line vs the last blessed baseline** — see below. Runs last, after `app`. | jq, checkov |

Missing tools / absent repos / branch-only artifacts **SKIP** (not FAIL) with a clear reason, so the
harness is honest about what it could and couldn't verify.

## The regression gate (`--main-gate`)

A static "all green" can hide a suite that silently **shrank** (deleted/skipped tests), coverage that
**slid**, or policy checks that were **suppressed**. The `regression` layer re-measures the candidate and
**FAILs if a monotonic-up metric dropped** below the last blessed baseline.

```bash
./capture-baseline.sh --run-app         # on a GREEN main: snapshot metrics → baseline/main-baseline.json (commit it)
./run.sh --main-gate                    # on an integration→main candidate: full + app + baseline delta
```

**Metric classes** (baseline lives in [`baseline/main-baseline.json`](baseline/main-baseline.json)):

| Class | Metrics | Rule |
|---|---|---|
| monotonic-up | `app.rspec.examples`, `app.jest.total`, `checkov.*.passed`, `app.coverage.line` | FAIL if `current < baseline − tolerance` (coverage tol = `COVERAGE_TOLERANCE`, default 0.5pp) |
| must-be-zero | `app.rspec.failures`, `app.jest.failed` | FAIL if nonzero |
| informational | `tf.*.resource_blocks` | never FAILs; a decrease SKIPs with a "verify intentional removal" note |

- **App counts** (`rspec`/`jest`) are read from `$HARNESS_APP_LOG` — CI runs `make ci-local | tee "$HARNESS_APP_LOG"`
  before invoking the harness. **Coverage** is read from the SimpleCov `coverage/.last_run.json` artifact.
- Any metric that is **NA in either the baseline or the candidate is SKIPPED**, not failed (honest about
  what it couldn't measure — e.g. app counts when Docker is absent, checkov counts without `--full`).
- **Re-bless after an intentional change** (a real coverage shift, a removed stack): re-run
  `./capture-baseline.sh` on the new green main and commit the updated manifest. The baseline is the
  audit trail — every value is provenance-stamped with the commit it was captured from.

## Status / robustness notes
- `terraform validate` for **workflow-infra** can't run on Apple Silicon (the vendored swipe module's
  `hashicorp/template` provider has no arm64 build) — it SKIPs on macOS/arm64 and runs on linux CI.
- A shared `TF_PLUGIN_CACHE_DIR` makes repeated `init -backend=false` fast after the first run.
- The harness is the home for the deploy smoke-test checklist; extend `checks/` as new invariants are
  identified. Adding a check = drop a `check_<layer>` function in `checks/NN-*.sh`.
