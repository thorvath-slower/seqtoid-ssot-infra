# Maintenance register — czid-infra

**Purpose.** A complete inventory of what in this repo is kept current automatically
(SSOT version files + Renovate) versus what a human must maintain by hand, with the
exact file path and in-file location of each. If it's in the "human-maintained" table,
nothing will remind you — so this list is how we avoid silently drifting.

> ⚠️ **Renovate is configured (`renovate.json`) but the GitHub app is not enabled yet
> (CZID-212).** Until it is, *everything* below is effectively human-maintained. The
> "Automated" table describes the intended steady state once the app is on.

> ℹ️ **Two version regimes live here.** The live `infra/` foundation declares providers
> per-file with loose floors (`aws >= 5.0`, `required_version >= 1.6`) and is **not** yet
> wired to a `_shared/versions.tf`; only `templates/terraform-stack/` uses the symlinked-SSOT
> pattern. So the "edit once, every stack moves" story currently applies to the template,
> not the foundation — the foundation's constraints are duplicated by hand (A11/A12). The
> root `.terraform-version` is the one true live SSOT.

## A. Human-maintained (Renovate / SSOT cannot track these)

| # | Item | Where (path → location in file) | Why it's manual | How to update |
|---|------|--------------------------------|-----------------|---------------|
| A1 | Local-path module sources | `infra/state-foundation/foundation/main.tf` → `module "network"/"eks"/"openbao"/"registries"`, `source = "./modules/..."` (lines 83, 93, 109, 117) | Renovate cannot bump a local `source = "./..."`; modules are vendored in-repo under `foundation/modules/` | Edit the module code directly; no version to bump |
| A2 | Backend `key` per stack | `infra/state-foundation/foundation/backend.tf` → `terraform { backend "s3" { key } }` (line 11); `infra/state-foundation/consumers/seqtoid-web/backend.tf` (line 12) | State object paths are bespoke per stack | Set a unique `key` by hand for each new stack |
| A3 | Shared partial-backend config | `infra/state-foundation/backend.hcl` → `bucket`/`region`/`dynamodb_table`/`kms_key_id`/`encrypt` (lines 10–14) | Hardcoded AWS identifiers populated from `bootstrap` outputs; Renovate doesn't touch `.hcl` backend config | After `bootstrap`, paste real values from `terraform output`; update on account/region/KMS change |
| A4 | `terraform_remote_state` config | `infra/state-foundation/consumers/seqtoid-web/remote_state.tf` → `data "terraform_remote_state" "foundation"` `config`, `key = "foundation/terraform.tfstate"` (lines 7–14) | Hardcoded cross-stack state pointer | Keep `key`/`bucket`/`region` in sync with the foundation backend by hand |
| A5 | GitHub OIDC provider thumbprint | `infra/state-foundation/foundation/main.tf` → `aws_iam_openid_connect_provider "github"`, `thumbprint_list` (line 77) | Hardcoded GitHub cert thumbprint; no datasource tracks it | Update by hand if GitHub rotates its OIDC CA |
| A6 | GitHub OIDC trust identifiers | `infra/state-foundation/foundation/variables.tf` → `github_org` (line 79), `github_deploy_repos` (line 85), `github_deploy_ref` (line 91) | Hardcoded org, repo allow-list, and trusted branch | Edit defaults (or override via tfvars) when repos/org/branch change |
| A7 | Default region | `infra/state-foundation/bootstrap/variables.tf` → `variable "region"` (line 5); `…/foundation/variables.tf` (line 8) | Hardcoded AWS region | Change by hand on a region move |
| A8 | EKS public-endpoint CIDR allow-list | `infra/state-foundation/foundation/variables.tf` → `eks_public_access_cidrs` default `["0.0.0.0/0"]` (line 72) | Security-relevant hardcoded value (open per `.trivyignore`) | Restrict to office/VPN CIDRs by hand |
| A9 | Trivy exception list | `.trivyignore` → finding IDs + reasons (e.g. `AWS-0164` line 9; `AWS-0040`/`AWS-0041` lines 19–20) | Hand-curated triage consumed by the `trivy` job in `security.yml` | Add ID + reason + date when accepting; remove once fixed |
| A10 | Checkov inline skips | e.g. `infra/state-foundation/bootstrap/main.tf` → `#checkov:skip=CKV_AWS_18` (line 170) | In-code suppressions; not tracked | Review and remove when no longer justified |
| A11 | Provider **list membership** | per-file `required_providers`: `bootstrap/main.tf` (line 18), `foundation/versions.tf` (lines 5–12), each `foundation/modules/*/main.tf` | Renovate bumps version *constraints*, not which providers are declared; these are per-file, not a shared `versions.tf` | Add/remove a provider by hand; keep the duplicated constraints consistent |
| A12 | `required_version` floor | `bootstrap/main.tf` (line 16), `foundation/backend.tf` (line 9), each module `main.tf`, `consumers/seqtoid-web/backend.tf` (line 10) — all `>= 1.6` | Hand-set Terraform floor, duplicated across stacks; distinct from `.terraform-version` (B1) | Bump by hand if a stack needs a higher floor; keep consistent |
| A13 | CI `validate` stack matrix | `.github/workflows/terraform-ci.yml` → `jobs.validate.strategy.matrix.stack` (lines 42–45) | Bespoke list of stack dirs to validate | Add the new stack path by hand when stacks are added |
| A14 | CI tool versions fetched by literal (non-`uses:`) | `.github/workflows/security.yml` → gitleaks `VER=8.21.2` (line 40), `tflint_version: latest` (line 68) | gitleaks is curl'd by version string; tflint pinned to `latest` — neither is a Renovate-tracked `uses:` pin | Bump `VER=` by hand; consider pinning tflint |

## B. Automated — SSOT version files + Renovate

| # | Item | Where (path → location in file) | Maintained by |
|---|------|--------------------------------|---------------|
| B1 | Terraform version (root SSOT) | `.terraform-version` → `1.12.1` | Renovate custom regex manager (`renovate.json`, `depName hashicorp/terraform`, github-releases); also read by CI via `terraform_version` in `terraform-ci.yml` |
| B2 | Terraform version (template SSOT) | `templates/terraform-stack/.terraform-version` | `templates/terraform-stack/renovate.json` custom regex manager (when the template ships as its own Renovate-enabled repo) |
| B3 | Provider version **constraints** | `foundation/versions.tf` `aws`/`tls` `version`; each module `main.tf` `required_providers` `version`; `templates/terraform-stack/_shared/versions.tf` | Renovate `terraform` manager, grouped "terraform providers" (`renovate.json` packageRules) |
| B4 | Committed provider lockfiles | `infra/state-foundation/foundation/.terraform.lock.hcl`; `…/bootstrap/.terraform.lock.hcl`; `templates/terraform-stack/envs/dev/example/.terraform.lock.hcl` | Renovate terraform manager updates lock hashes alongside constraint bumps. NOTE: `:maintainLockFilesDisabled` is set — locks move only *with* a constraint bump, not on their own |
| B5 | GitHub Actions `uses:` pins | `.github/workflows/terraform-ci.yml` (`actions/checkout@v6`, `hashicorp/setup-terraform@v2`); `.github/workflows/security.yml` (`actions/checkout@v6`, `aquasecurity/trivy-action`, `terraform-linters/setup-tflint`, `bridgecrewio/checkov-action`) | Renovate `github-actions` manager, grouped "github actions" |
| B6 | Action/Docker **digests** | the `uses:` refs above | Renovate `pinDigests: true` pins + bumps digests once the app is enabled |

## When you add something, update the register

- New stack? Add its backend `key` (A2) + `terraform_remote_state` (A4), and add the dir to the `terraform-ci.yml` validate matrix (A13).
- New provider? Add it to every relevant `required_providers` by hand (A11) — Renovate only moves the constraint.
- New hardcoded AWS identifier (ARN, account ID, bucket, region, OIDC value)? Human-maintained → add a row to A.
- New CI tool fetched by literal version (curl/`VER=`)? Add it to A14; prefer an action `uses:` pin so Renovate (B) can track it.
- Accepting a scanner finding? Add the ID + reason + date to `.trivyignore` (A9) or an inline `checkov:skip` (A10).
