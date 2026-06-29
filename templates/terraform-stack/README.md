# terraform-template

A starter template for **Terraform** infrastructure on the CZ ID platform — the **fogg replacement**. Copy this layout to stand up a new IaC repo (or a new set of stacks) that already follows our conventions: version SSOT, per-account/per-env layout, shared remote state, and a CI validate gate.

> No fogg. No Terraform CLI / Terraform Cloud. Terraform only (registry `registry.terraform.io`).

## How to use this
1. **Generate from the template:** click "Use this template" on GitHub (this repo is a template repo), or `gh repo create thorvath-slower/<your-repo> --private --template thorvath-slower/terraform-template`.
2. Pick your Terraform version in **`.terraform-version`** (currently `1.12.1`). CI reads this file — never hardcode the version anywhere else.
3. Wire each stack's backend (see [State](#state)).
4. Add your stacks under `envs/<env>/<component>/` and list each in the `validate.yml` matrix.
5. Commit `.terraform.lock.hcl` per stack (see [Lockfiles](#lockfiles)).

## Layout
```
.
├── .terraform-version          # version SSOT — CI reads this (setup-terraform@v2)
├── _shared/
│   └── versions.tf            # SSOT for Terraform + provider constraints (symlinked into every stack)
├── accounts/                  # (add) per-AWS-account provider/backend bootstrap, one dir per account
│   └── <account>/             #   e.g. idseq-dev, idseq-staging, idseq-prod, idseq-support
├── envs/
│   └── <env>/                 # dev | staging | prod | support
│       └── <component>/       # one independently-applied stack (e.g. db, web, redis)
│           ├── main.tf
│           ├── variables.tf
│           ├── terraform.tf   # backend "s3" + provider config
│           └── versions.tf    # -> symlink to ../../../_shared/versions.tf
└── .github/workflows/
    └── validate.yml           # fmt + validate gate (no AWS needed)
```
A **component** (a.k.a. stack) is the unit of `apply`. Keep them small and single-purpose.

## Version SSOT
- Terraform version: **`.terraform-version`** — read by `hashicorp/setup-terraform@v2` via `terraform_version`.
- Provider versions: **`_shared/versions.tf`**, symlinked into each stack as `versions.tf`. Bump once here and every stack moves together.
  ```bash
  # add the shared versions.tf to a new stack:
  cd envs/dev/<component>
  ln -s ../../../_shared/versions.tf versions.tf
  ```

## State
- Remote state lives in the per-account foundation bucket **`czid-tfstate-<account_id>-<region>`** (stood up by the `czid-infra` state-foundation).
- Each stack gets its **own key** (`terraform/<env>/components/<component>.tfstate`) so state is isolated per env + component.
- **Native S3 state locking** (`use_lockfile = true`) — no DynamoDB lock table (Terraform ≥ 1.10).
- Fill the placeholders in each stack's `terraform.tf` (`<account_id>`, `<region>`, key path).

## Lockfiles
Commit `.terraform.lock.hcl` per stack — reproducible builds, no floating providers. CI runs `terraform init` **without `-upgrade`**.
```bash
cd envs/dev/<component>
terraform providers lock -platform=linux_amd64 -platform=darwin_amd64
git add .terraform.lock.hcl
```

## CI
- **`validate.yml`** (here): `terraform fmt -check` + `terraform validate` per stack (uses `terraform init -backend=false`, so **no AWS needed** — this is the merge gate). Add each new stack to the matrix.
- **plan / apply** (add per your account wiring): assume the per-account role, `terraform plan` on PR, gated `terraform apply` after dev→staging→prod promotion. Mirror the patterns in `cypherid-web-infra`.

## Conventions
Follow the platform guide — **`czid-infra/docs/platform/`** (overview, conventions, Terraform/IaC, dependency & version management, runbooks). In short: work on `thorvath-slower` forks only; small single-concern PRs; validate locally before pushing; never downgrade a dependency to dodge a conflict — pull the toolchain forward.

## Renovate
`renovate.json` keeps dependencies + the `.terraform-version` pin current automatically once the Renovate app is enabled on the repo (see CZID-212).
