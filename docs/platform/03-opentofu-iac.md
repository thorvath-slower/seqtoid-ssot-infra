# 03 — OpenTofu / Infrastructure-as-Code

All AWS infrastructure is defined as code with **OpenTofu** (the open-source Terraform fork). We do **not** use Terraform CLI, Terraform Cloud, or **fogg** (the old scaffolding generator) anymore.

## Why OpenTofu (not Terraform / fogg)
- **OpenTofu** is the FOSS, community-governed continuation of Terraform — no licensing lock-in. The provider registry is `registry.opentofu.org`.
- **fogg** used to *generate* the Terraform tree (layout, provider/version blocks, backends). We removed it: the tree is now hand-authored and committed directly. A starter template that replaces fogg's scaffolding is planned (CZID-207).

## Version SSOT — the single most important rule
- The OpenTofu version is pinned **once** per repo in **`.opentofu-version`** (currently **`1.12.1`**).
- CI reads that file; it never hardcodes a version:
  ```yaml
  - uses: opentofu/setup-opentofu@v2      # node24 runtime (see doc 04)
    with:
      tofu_version_file: .opentofu-version  # <- SSOT
      tofu_wrapper: false
  ```
- To upgrade OpenTofu everywhere: change `.opentofu-version`, regenerate lockfiles, done. See [05 — Runbooks](05-runbooks.md#bump-the-opentofu-version).

## Provider lockfiles — reproducible builds
- Each repo commits a **`.terraform.lock.hcl`** that pins exact provider versions + checksums.
- CI runs **`tofu init` without `-upgrade`**, so providers never float between runs and a malicious/broken provider release can't slip in.
- A validate-workflow guard fails the build if the lockfile is **missing or drifts** during `tofu init` (forces a re-lock + commit when providers change).
- Lock for the platforms CI + developers use (`linux_amd64`, `darwin_amd64`; add `arm64` once no provider blocks it). See the regenerate runbook in [05](05-runbooks.md#regenerate-a-provider-lockfile).

## The three IaC repos

### czid-infra — the state foundation
This repo bootstraps and owns the **shared remote state backend** every other stack uses.
```
czid-infra/infra/state-foundation/
├── bootstrap/     # run ONCE, with a LOCAL backend, to create the S3 state bucket
├── foundation/    # foundational, account-wide infra (+ modules/)
└── consumers/     # per-consumer state wiring (e.g. seqtoid-web)
```
- The backend bucket is `czid-tfstate-<account_id>-<region>`, with **S3-native state locking** (no DynamoDB lock table needed), versioning, encryption, public-access-block, and `prevent_destroy` so an errant plan can't delete it.
- **Bootstrap order:** `tofu init` (local backend) → `apply` to create the bucket → add the `backend "s3"` block → `tofu init -migrate-state`. You only do this once per account.
- CI: `tofu-ci.yml` (fmt-check + a `validate` matrix over the state-foundation stacks); `security.yml` (tflint/gitleaks/trivy/checkov).

### cypherid-web-infra — the web app's infra
```
cypherid-web-infra/terraform/
├── _shared/                 # shared versions.tf + provider config (symlinked into stacks)
├── accounts/idseq-{dev,prod,staging,support}/   # per-AWS-account provider + backend wiring
└── envs/{dev,staging,prod,public,sandbox}/<component>/   # the stacks
        access-management/ auth0/ db/ ecs/ eks/ k8s-core/ redis/ resque/
        route53/ web/ web-waf/ downloads/ params-secrets/ …
```
- A **component** (a.k.a. stack) = one independently-applied unit (e.g. `envs/dev/db`).
- The `_shared/versions.tf` is symlinked into stacks so provider/version constraints are defined **once** (SSOT for provider versions across ~188 stacks).
- CI: `validate-stack.yml` / `tofu_ci.yml` (validate), `plan_*` (PR plan), `apply_*` (gated apply), `promote.yml` (promotion between environments).

### cypherid-workflow-infra — the pipeline's infra
- Flatter layout (`terraform/` + `terraform/modules/`) for the Batch / Step Functions / Lambda substrate that runs the WDL pipelines.
- Uses chalice-generated `chalice.tf.json` for some Lambdas; `make package-lambdas` runs codegen before `tofu init`.
- CI: `validate.yml` (fmt + validate), `plan_call.yml` / `plan_only.yml` (plan), `deploy.yml` (manual deploy).

## The change flow: validate → plan → apply
1. **validate** (runs on every PR): `tofu fmt -check -recursive` + `tofu validate`. This is the merge gate. It needs no AWS credentials (**Bucket A**).
2. **plan** (PR / on demand): assumes the per-account role, `tofu plan` against the live account, surfaces the diff. Needs AWS (**Bucket B**).
3. **apply** (gated): `tofu apply` after promotion gating. Needs AWS + approval (**Bucket B**). The target is **dev → staging → prod** promotion so no change reaches prod without two prior environments confirming it (CZID-96/166).

### Make an IaC change (walkthrough)
```bash
# 1. fresh branch off the fork's main
git fetch && git checkout origin/main -b czid-NNN-short-slug

# 2. edit the stack, e.g. terraform/envs/dev/db/main.tf

# 3. validate locally (Bucket A — no AWS needed)
cd terraform/envs/dev/db
tofu fmt -recursive ..        # format
tofu init -input=false        # honors the committed lockfile (no -upgrade)
tofu validate
# optional policy/security scan: checkov -d . ; tflint ; trivy config .

# 4. commit (single concern), push to the fork, open the PR
#    CI runs `tofu fmt + validate`; confirm it's green.

# 5. plan/apply happen via the gated pipeline (Bucket B) after merge.
```
Do **not** hand-run `tofu apply` against a live account from a laptop — apply goes through the gated pipeline.

## Common gotchas
- New work belongs off **fresh** `origin/main` (czid-infra `main` is the trunk and moves fast).
- OpenTofu's registry is `registry.opentofu.org` — not `registry.terraform.io`. Lockfiles and egress allowlists must point at it.
- The deprecated `hashicorp/template` provider has no arm64 build — it blocks arm64 lockfile platforms until removed (tracked separately).
- Module sources should be commit-hash-pinned (supply-chain hardening) — see [04](04-dependencies-and-versions.md).
