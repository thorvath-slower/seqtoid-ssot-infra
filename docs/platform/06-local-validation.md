# 06 — Local Validation

> **CI is the final gate, not the dev loop.** Validate locally first; push when you expect green.

Each repo has a way to run the important checks on your machine, in Docker, before pushing.

## seqtoid-web (Rails + frontend)
- **Full backend CI suite in Docker (Postgres):**
  ```bash
  cd seqtoid-web
  make ci-local        # runs the Ruby suite the way CI does (PostgreSQL); green this before pushing
  make rspec           # just RSpec
  ```
- **The fork's CI is Ruby-centric and does NOT run the frontend type-check.** Validate frontend changes yourself:
  ```bash
  npx tsc -p ./app/assets/tsconfig.json --noemit   # in node:$(cat .node-version)
  npm run lint
  ```
- Ruby suite runs under `ruby:3.3.6` (matches `.ruby-version`); the CI image is amd64.

## seqtoid-workflows (WDL pipelines)
- **`bin/ci-local`** mirrors the GitHub `wdl-ci.yml` pipeline **minus** the AWS/ECR push and the self-hosted integration job — so you can validate locally while the fork's CI runner is unavailable. It drives the **same Makefile targets** CI uses, so local and CI can't drift.
  ```bash
  cd seqtoid-workflows
  bin/ci-local                 # workflows changed since HEAD^ (else all)
  bin/ci-local amr             # a single workflow
  LINT_ONLY=1 bin/ci-local     # fast: lint + miniwdl check only (no docker/rust)
  SKIP_TESTS=1 bin/ci-local amr # lint + check + build, skip the step tests
  ```
  It runs: `make lint` (flake8 + pre-commit miniwdl-check) → `make check` (miniwdl static validation) → `make build` (docker build, no ECR push) → step tests → Rust tests.
- **What it can't do (Bucket B):** the ECR push, the self-hosted `wdl-ci-integration` job, and the full short-read-mngs benchmarks. Base-image refreshes that need tool-output parity still need those benchmarks.

## IaC repos (Terraform)
No AWS needed for the merge gate (**Bucket A**):
```bash
cd <stack>
terraform fmt -check -recursive
terraform init -input=false        # honors the committed lockfile
terraform validate
checkov -d .                  # policy scan (optional locally; runs in CI for czid-infra)
tflint                        # lint
trivy config .                # IaC misconfig scan
```
`plan`/`apply` need live AWS and run in the pipeline (Bucket B).

## The offline test harness (seqtoid-web)
- `seqtoid-web-test-harness/` is a **self-contained, offline, push-locked** copy of the upstream app that runs the **whole web app** in Docker and is browsable end-to-end (login → projects → sample/metadata validation → UI).
  ```bash
  cd seqtoid-web-test-harness
  ./bin/harness-up.sh          # first run builds the image (~15-30 min), then ~1 min
  # open http://localhost:3000/direct_user_login?user_id=1   (seeded admin)
  ./bin/harness-down.sh [--wipe]
  ```
- **It cannot reach the customer:** no git remote + a `pre-push` hook that hard-blocks every push. Local commits only.
- **AWS boundary (by design):** file *upload* (browser→S3 via STS) and the *pipeline* (Step Functions/Batch) need real AWS — out of scope for the offline box. Everything else works.
- Docs live inside the harness: `HARNESS-SETUP.md` (runbook) + `HARNESS-CHANGES.md` (what was changed to run locally + why).
