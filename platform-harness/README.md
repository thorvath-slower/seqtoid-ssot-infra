# Platform Test Harness

A mission-critical, **offline (no-AWS)** validation harness for the whole platform — all repos at
once. It's the gate we run **before/while merging** the modernization branches and **before** any
deployment, so integration breakage and parity regressions surface immediately.

> Read-only by construction: `terraform` runs with `-backend=false`, scanners are static, charts are
> `helm template`-only. It never calls AWS and never applies anything.

## Usage

```bash
cd czid-infra/platform-harness        # the harness lives in the SSOT repo
./run.sh                               # all offline layers
./run.sh --with-app                    # also run the Rails suite (Docker + MySQL; slow)
./run.sh --full                        # deeper sweep (every web-infra stack, full checkov)
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

Missing tools / absent repos / branch-only artifacts **SKIP** (not FAIL) with a clear reason, so the
harness is honest about what it could and couldn't verify.

## Status / robustness notes
- `terraform validate` for **workflow-infra** can't run on Apple Silicon (the vendored swipe module's
  `hashicorp/template` provider has no arm64 build) — it SKIPs on macOS/arm64 and runs on linux CI.
- A shared `TF_PLUGIN_CACHE_DIR` makes repeated `init -backend=false` fast after the first run.
- The harness is the home for the deploy smoke-test checklist; extend `checks/` as new invariants are
  identified. Adding a check = drop a `check_<layer>` function in `checks/NN-*.sh`.
