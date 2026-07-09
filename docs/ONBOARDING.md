# Onboarding — seqtoid-infra (the foundation SSOT)

A current-state, junior-engineer-friendly guide to this repo: what it is, what it
provisions, how it's laid out, how CI gates your changes, and how to make one safely.
Everything here is grounded in what's actually checked in today. If a detail here ever
disagrees with the code, **the code wins** — and please fix the drift (see the
[gotchas](#runbook--gotchas)).

> New to the platform? Read the top-level [`README.md`](../README.md) first for the
> "why", then this guide for the "how". For the state model in depth, read
> [`infra/state-foundation/README.md`](../infra/state-foundation/README.md).

---

## 1. Overview — what this repo is

`seqtoid-infra` (directory name `seqtoid-ssot-infra`; historically `czid-infra`) is the
**foundation** layer of the seqtoid platform: the Terraform Infrastructure-as-Code that
provisions the shared, long-lived AWS infrastructure that **every other seqtoid repo
builds on top of**. Nothing else in the platform can deploy until the foundation exists —
it sits at the bottom of the stack.

> **seqtoid** is a hypothesis-free metagenomic pathogen-identification platform. This repo
> is greenfield (new in the platform overhaul — not a fork of the legacy setup). The
> platform is mid-rename from `czid-*`/`cypherid-*` to `seqtoid-*`; you will see both
> names in code, resource prefixes (`czid-…`), and tickets. That naming skew is expected,
> not a bug.

### What the foundation provisions

Two Terraform stacks under `infra/state-foundation/`:

- **`bootstrap/`** — the one-time chicken-and-egg layer that creates the **home for all
  state**: a versioned, SSE-KMS-encrypted, TLS-only, public-access-blocked S3 bucket
  (`prevent_destroy`), a DynamoDB lock table (or native S3 locking on Terraform ≥ 1.10),
  a dedicated access-log bucket, and optional cross-region-replication DR (`dr.tf`, off by
  default). Runs on a **local backend** because the bucket can't store its own creation
  state until it exists.
- **`foundation/`** — the **master state**: the shared, long-lived infra, wired together
  in `main.tf` from four in-repo modules plus a few top-level resources:
  - **`modules/network`** — VPC, public/private subnets across AZs, IGW/NAT, EKS-tagged
    routing.
  - **`modules/eks`** — the platform Kubernetes cluster, managed node group, IRSA OIDC
    provider, core addons.
  - **`modules/openbao`** — [OpenBao](https://openbao.org) (open-source Vault) auto-unseal
    KMS key + IRSA unseal role, and a published address. (The OpenBao *install* — Helm
    release, policies, DB-creds engine — is delivered later by the secrets workstream; the
    foundation only owns the infra it needs and publishes a stable address.)
  - **`modules/registries`** — ECR repositories + CodeArtifact domain/repos with
    pull-through/public-registry proxies.
  - Top-level: a shared, rotated **application KMS key**, the **GitHub Actions OIDC
    provider**, and shared **least-privilege IAM roles** (`gha-deploy`, `external-secrets`).

Everything the foundation wants downstream stacks to see is exported through
[`foundation/outputs.tf`](../infra/state-foundation/foundation/outputs.tf) — **treat that
file as the platform's stable inheritance API** (VPC/subnets, EKS cluster name/endpoint/CA/
OIDC, KMS ARN, OpenBao address, registry URLs, shared role ARNs, region/account).

---

## 2. Repository layout

```
.
├── README.md                     # the "why" + platform-fit overview (start here)
├── MAINTENANCE.md                # what's auto-maintained (Renovate/SSOT) vs human-maintained
├── TODO.md                       # outstanding foundation work
├── Makefile                      # `make check` / `make fmt` — the local dev tasks
├── .terraform-version            # THE pinned Terraform toolchain (SSOT; read by CI)
├── .trivyignore                  # audited trivy scan exceptions
├── .checkov.baseline             # inherited checkov findings accepted as a baseline
├── renovate.json                 # automated dependency updates
├── bin/check                     # local CI mirror (fmt + validate + scanners)
│
├── infra/state-foundation/       # THE foundation IaC
│   ├── README.md                 # the state model + bootstrap procedure (read this)
│   ├── backend.hcl               # shared partial S3 backend config (placeholders → real after bootstrap)
│   ├── bootstrap/                # one-time: state bucket + lock table + KMS + DR (local backend)
│   ├── foundation/               # the MASTER state — shared infra
│   │   ├── main.tf outputs.tf variables.tf versions.tf backend.tf monitoring.tf
│   │   └── modules/{network,eks,openbao,registries}/
│   └── consumers/seqtoid-web/    # WORKED EXAMPLE of a downstream stack inheriting outputs
│
├── modules/cztack/               # vendored chanzuckerberg/cztack shared modules (third-party)
├── templates/                    # starter Terraform stack layout for new work
├── platform-harness/             # offline, no-AWS, whole-platform validation gate
├── specs/                        # spec-kit specs for individual change slices
├── docs/                         # architecture, security findings/hardening, THIS guide
└── .github/workflows/            # terraform-ci.yml + security.yml (thin callers to the SSOT reusable)
```

---

## 3. The two state universes (foundation vs app infra — #433 F1)

The single most important mental model for this repo. There are **two distinct kinds of
Terraform state**, and this repo owns the first and defines how the second plugs in:

1. **Foundation state** — *this repo*. The `foundation/terraform.tfstate` object is the
   **master**: it owns the shared, long-lived infra (VPC, EKS, KMS, OpenBao, registries,
   OIDC, shared roles) and **publishes** it through `outputs.tf`. There is one foundation
   per environment/account.

2. **App-infra state** — *the other repos* (`seqtoid-web-infra`, `seqtoid-workflow-infra`,
   and app stacks like `seqtoid-web`). Each is its **own** state object, under its **own**
   `key`, in the **same shared bucket**. It **reads the foundation's outputs read-only**
   via `data "terraform_remote_state" "foundation"` — it consumes the foundation, it does
   **not** own or re-create the VPC/EKS/etc.

```
   s3://czid-tfstate-<account>-<region>          (one shared, versioned, KMS-encrypted bucket)
   ├── foundation/terraform.tfstate               ← MASTER — owns shared infra, publishes outputs
   ├── apps/seqtoid-web/terraform.tfstate         ┐
   ├── apps/graphql-federation/terraform.tfstate  ├─ app-infra: own key, reads foundation outputs
   └── workflow-infra/terraform.tfstate           ┘

   foundation ──outputs.tf──▶ data.terraform_remote_state.foundation ──▶ downstream stacks
```

Why split this way rather than one giant state file: a monolithic state means org-wide
lock contention, a huge blast radius, and slow plans. One key per stack **contains the
blast radius** and keeps plans fast.

**The rules that fall out of this:**

- `terraform_remote_state` can read **outputs only**, never arbitrary resources. If a
  downstream stack needs a value from the foundation, the foundation **must export it from
  `outputs.tf`**. Adding an output is cheap and safe; changing or removing one can break a
  consumer — treat `outputs.tf` as a versioned API.
- Downstream stacks **never** declare the VPC/EKS/etc. themselves — they inherit. See the
  worked example in
  [`consumers/seqtoid-web/remote_state.tf`](../infra/state-foundation/consumers/seqtoid-web/remote_state.tf)
  (reads outputs) and
  [`consumers/seqtoid-web/backend.tf`](../infra/state-foundation/consumers/seqtoid-web/backend.tf)
  (its own `key = apps/seqtoid-web/terraform.tfstate` in the shared bucket).

### State backend hardening (bootstrap)

The shared bucket isn't just an S3 bucket — `bootstrap/main.tf` makes it durable and
auditable: **bucket versioning = the backup** (any prior state is recoverable; retention =
`state_backup_retention_days`, default 90), SSE-KMS with a dedicated rotated CMK, TLS-only
bucket policy, full public-access block, `prevent_destroy` on the bucket/lock-table/KMS,
DynamoDB lock table encrypted with the state CMK + point-in-time recovery, EventBridge
notifications for auditability, and a hardened server-access-log bucket. Region-loss DR
(cross-region replication) is committed code in `bootstrap/dr.tf`, gated behind
`enable_dr` (default `false`).

---

## 4. The vendored cztack module set

Under [`modules/cztack/`](../modules/cztack/) is a **full, verbatim vendor** of
[`chanzuckerberg/cztack`](https://github.com/chanzuckerberg/cztack) — 59 `aws-*` shared
Terraform modules (ACM, Aurora MySQL/Postgres, ECR, ECS service/job, EKS, IAM roles,
S3 buckets, Redis, SQS, SSM params, etc.), plus `bless-ca`.

Read [`modules/cztack/VENDORING.md`](../modules/cztack/VENDORING.md) before touching it.
Key facts:

- **Why vendored:** consumers previously referenced
  `github.com/chanzuckerberg/cztack//<module>?ref=…` directly — an external public-repo
  supply-chain dependency. Vendoring removes that upstream dependency.
- **Version:** `v0.104.2` (the dominant pin across consumers), vendored 2026-07-01, MIT
  licensed (`LICENSE` retained).
- **Pulled in full on purpose** — all modules, not only the ones used today (prod may need
  modules not referenced yet). A follow-up will trim to what's legitimately needed.
- **Do not hand-edit these modules.** If an update is needed, **re-vendor from upstream at
  a new tag**, don't patch in place.
- **They are third-party, not our authored IaC**, so CI **excludes them from policy scans**
  (`checkov_skip_path`/`trivy_skip_dirs` = `modules/cztack` — otherwise ~186 upstream
  checkov findings would swamp the signal; see #418). Don't "fix" scanner findings inside
  `modules/cztack`.
- The **foundation stack itself does not consume cztack** today — its four modules
  (`network/eks/openbao/registries`) are local, in-repo, and hand-written. cztack is the
  shared library the **downstream app-infra repos** draw from.

---

## 5. CI gates (terraform-ci + security via the SSOT reusable)

Both workflows in `.github/workflows/` are **thin callers**: the real logic lives once in
the shared reusable repo `thorvath-slower/seqtoid-ci-workflows`, pinned to `@v1`. One
definition, updated once, used across every repo.

### `terraform-ci.yml` — the IaC correctness gate

- Calls `seqtoid-ci-workflows/.github/workflows/terraform-ci.yml@v1`.
- Runs `terraform fmt -check -recursive` over `infra/`, then per-stack `terraform validate`
  (`init -backend=false`) for the three stacks it's told about:
  `bootstrap`, `foundation`, `consumers/seqtoid-web`.
- The Terraform version is **read from this repo's `.terraform-version`** (SSOT-by-file) —
  the reusable resolves it, so bumping the toolchain is a one-line change here.

### `security.yml` — the security gate

- Calls `seqtoid-ci-workflows/.github/workflows/security.yml@v1`.
- Runs **gitleaks** (secrets — hard-fail), **trivy**, **tflint**, and **checkov**.
- **checkov is a hard gate on every run** (`checkov_soft_fail: false`): it fails on any
  finding **not** in [`.checkov.baseline`](../.checkov.baseline). The baseline holds the
  inherited EKS-public-endpoint findings (tracked by #341). New findings must be fixed or
  explicitly accepted — you don't get to silently add to the baseline.
- `modules/cztack` is excluded from checkov and trivy (see §4).
- Audited exceptions live in [`.trivyignore`](../.trivyignore) (ID + reason + date).

### Run the exact same gates locally first

CI is the **final** gate, not your dev loop. Mirror it before you push:

```bash
make check          # == bin/check: terraform fmt + per-stack validate + scanners (if installed)
make fmt            # auto-fix formatting: terraform fmt -recursive infra/
```

`bin/check` runs the fmt+validate IaC gate (required) and the security scanners **if they
are installed**, skipping-with-a-note if not — so the IaC gate is always usable. Install
the full set with `brew install terraform trivy tflint gitleaks`. A green `make check`
predicts a green CI.

### The whole-platform harness (before merges/deploys)

[`platform-harness/`](../platform-harness/README.md) is a separate, **offline (no-AWS),
read-only** validation gate for the *entire* platform at once (`terraform` runs
`-backend=false`, scanners are static, charts are `helm template`-only — it never calls AWS
or applies anything). Run it before merging modernization branches or deploying:

```bash
cd platform-harness && ./run.sh          # all offline layers
./run.sh --list                          # list layers (preflight/terraform/checkov/charts/…)
```

It validates whatever each sibling repo currently has checked out, so check out the target
branches first. This is the platform integration gate; `make check` is the per-repo gate.

---

## 6. How to make a change

Doctrine: **small, single-concern PRs**, each traced to a tracking ticket, validated
locally before pushing (see [`README.md`](../README.md) → Toolchain & conventions).

1. **Branch off `integration`** (the working base for the modernization effort):
   ```bash
   git fetch origin
   git checkout -B <ticket>-<short-desc> origin/integration
   ```
2. **Make the change.** Edit the relevant stack/module under `infra/state-foundation/`.
   - Adding a value downstream stacks need? Add an **output** in
     `foundation/outputs.tf` (append; don't break the existing contract).
   - Adding a **new stack**? Give it a unique backend `key`, add a
     `terraform_remote_state` block if it inherits, **and** add its directory to the CI
     stack list in `terraform-ci.yml` and to `bin/check`'s `STACKS` array (and update
     `MAINTENANCE.md`).
3. **Validate locally:**
   ```bash
   make fmt            # format
   make check          # fmt-check + validate + scanners  (final: platform-harness/run.sh)
   ```
   No `terraform apply` in the dev loop — validation is `-backend=false`, no AWS.
4. **Open a gated PR** against `integration`. **Do not self-merge.** All merges to `main`
   are governed (strict review + explicit sign-off); PRs, branches, and dep-bumps are fine
   — merging is not. CI (terraform-ci + security) must be green; read the **full**
   `gh pr checks` output and confirm every required gate passed (especially the hard-fail
   scanners) before requesting merge.
5. **Commits carry no AI attribution** — all work is authored by the team.

Applying the foundation for real (bootstrap → foundation → consumers) is an **operator**
task done with AWS credentials, not part of the change/PR loop — see §7 and the
[state-foundation README](../infra/state-foundation/README.md#bootstrap-order-one-time).

---

## 7. Runbook & gotchas

### First-time bootstrap (operator, one-time, needs AWS creds)

The bucket must exist before any stack can use the S3 backend, so `bootstrap/` runs on a
**local** backend first:

```bash
cd infra/state-foundation/bootstrap
terraform init                       # local backend
terraform apply                      # creates bucket + lock table + KMS + log bucket
terraform output backend_hcl > ../backend.hcl   # paste the real values into the shared config

cd ../foundation
terraform init -backend-config=../backend.hcl
terraform plan                       # review
terraform apply                      # stands up shared infra, publishes outputs

# any downstream stack, e.g. the example:
cd ../consumers/seqtoid-web
terraform init -backend-config=../../backend.hcl
terraform apply                      # inherits foundation outputs
```

Enable region-loss DR when you want it (off by default):
`terraform apply -var enable_dr=true -var dr_region=us-east-1` in `bootstrap/`.

### Portability (cloud vs appliance)

The backend is selected by deployment profile. Cloud/MSP uses S3 + KMS + versioning + lock
(this scaffold); the on-prem **Appliance** can use a local backend or bundled **MinIO**
through the same S3 block. Same foundation/inheritance pattern either way — only
`backend.hcl` changes.

### Gotchas / things that will trip you up

- **Renovate is configured but the GitHub app is not enabled yet (CZID-212).** Until it is,
  **everything is effectively human-maintained** — the "Automated" table in
  [`MAINTENANCE.md`](../MAINTENANCE.md) describes the *intended* steady state, not today.
- **Two version regimes.** The live `infra/` foundation declares providers per-file with
  loose floors (`aws >= 5.0`, `required_version >= 1.6`) and is **not** wired to a shared
  `_shared/versions.tf` — only `templates/terraform-stack/` uses the symlinked-SSOT
  pattern. So the "edit once, every stack moves" story currently applies to the *template*,
  not the foundation; foundation constraints are duplicated by hand (MAINTENANCE A11/A12).
  The root **`.terraform-version` is the one true live SSOT** for the toolchain.
- **`.terraform-version` is the toolchain SSOT.** It is currently **`1.15.7`** and the
  narrative in `README.md`, `MAINTENANCE.md` and `templates/terraform-stack/README.md` now
  matches it (reconciled under CZID-140). When in doubt, trust `.terraform-version` -- it's
  what CI reads.
- **CI stack list is maintained by hand** in three places that must stay in sync: the
  `stacks:` block in `terraform-ci.yml`, the `STACKS` array in `bin/check`, and
  `MAINTENANCE.md`. (Note: `MAINTENANCE.md` A13 still describes an older
  `validate.strategy.matrix` shape; the workflow is now a thin caller with a `stacks:` list
  — same idea, different location.)
- **Don't touch `modules/cztack/`** except by re-vendoring, and don't chase scanner findings
  inside it — it's excluded from policy scans on purpose (§4).
- **`.terraform.lock.hcl` is committed** per stack (reproducible providers). `.terraform/`,
  `*.tfstate*`, and `*.tfvars` are gitignored — never commit state or var files.
- **`terraform validate` for workflow-infra can't run on Apple Silicon** (a vendored
  module's `hashicorp/template` provider has no arm64 build); the platform harness SKIPs it
  on macOS/arm64 and runs it on linux CI. Not a foundation problem, but you'll see it in
  harness output.

### Where to read more

| Doc | What |
|---|---|
| [`README.md`](../README.md) | The "why", platform fit, getting started |
| [`infra/state-foundation/README.md`](../infra/state-foundation/README.md) | State model, durability/backup, bootstrap procedure |
| [`MAINTENANCE.md`](../MAINTENANCE.md) | Auto-maintained vs human-maintained inventory |
| [`docs/DEPLOYMENT-ARCHITECTURE.md`](DEPLOYMENT-ARCHITECTURE.md) | Editions, GitOps, blue/green, EKS topology |
| [`docs/SECURITY-SCANNING.md`](SECURITY-SCANNING.md) | The gitleaks/trivy/tflint/checkov setup |
| [`docs/SECURITY-001-FOUNDATION-HARDENING.md`](SECURITY-001-FOUNDATION-HARDENING.md) | Foundation hardening pass + residual items |
| [`platform-harness/README.md`](../platform-harness/README.md) | The offline whole-platform validation gate |
| [`TODO.md`](../TODO.md) | Outstanding foundation work |
