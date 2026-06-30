# Improvement Specification: Renovate dependency automation (improvement-#009)

**Branch**: `improvement-#009-renovate`  ·  **Spec dir**: `specs/009-renovate/`

**Created**: 2026-06-11 · **Status**: Draft · **Repo**: `czid-infra` (base: `feature-#001-shared-state-backend`)

**Input**: Extend the Renovate rollout (started in the three app/workflow repos) to the foundation/state repo so its versions are bot-maintained. See `seqtoid-web` `specs/009-renovate/spec.md` for the full Renovate-vs-Dependabot rationale.

## What this delivers — `renovate.json` (repo root)

- `extends`: `config:recommended`, `:dependencyDashboard`, `:maintainLockFilesDisabled`.
- Weekly schedule (`before 9am on monday`, `America/Los_Angeles`); `prConcurrentLimit: 5`, `prHourlyLimit: 2`; `rebaseWhen: conflicted`; `pinDigests: true`.
- **`customManagers`** (regex): tracks **`.terraform-version`** (1.12.1) against `hashicorp/terraform` GitHub releases.
- **Grouping** (`packageRules`):
  - **terraform providers** — provider/module bumps across the foundation stacks (`bootstrap`, `foundation` + its modules, `consumers`) grouped into one PR (the `terraform` manager reads `required_providers`: aws, tls).
  - **github actions** — the `tofu_ci.yml` actions (`checkout`, `setup-terraform`, `paths-filter`, `github-script`) grouped.
- `vulnerabilityAlerts.enabled: true`.

No `docker`/`npm`/`pip` managers apply (this repo is pure Terraform).

## Validation

`renovate-config-validator` (via `npx --package renovate`) passes. Enabling the Renovate app on the repo is a GitHub-side step (Bucket B).

## Base note

Branched from `feature-#001-shared-state-backend` (where the IaC lives; `main` carries no `.tf`), consistent with `improvement-#004`.
