# 01 — Platform Overview

CZ ID is a hypothesis-free metagenomic platform: scientists upload sequencing data, a bioinformatics pipeline identifies pathogens, and a web app presents the results. The platform spans **six repositories**, each with a clear responsibility.

## The repositories

| Repo | Role | Stack | How it's run |
|---|---|---|---|
| **czid-infra** | IaC **state foundation** trunk — the shared remote state backend + foundational account infra | Terraform | `terraform-ci.yml` (validate), `security.yml` (scanning) |
| **cypherid-web-infra** | IaC for the **web application's** AWS infra (per account + per env) | Terraform | `validate-stack.yml`, `plan_*`, `apply_*`, `promote.yml` |
| **cypherid-workflow-infra** | IaC for the **bioinformatics pipeline** AWS infra (Batch, Step Functions, Lambdas) | Terraform | `validate.yml`, `plan_call.yml`, `deploy.yml` |
| **seqtoid-web** | The **web application** — API + UI | Ruby on Rails 7.1 + React/TypeScript (Relay) | `check.yml`, Ruby test/lint CI |
| **seqtoid-workflows** | The **bioinformatics pipelines** | WDL + per-workflow Docker images | `wdl-ci.yml`; local `bin/ci-local` |
| **seqtoid-graphql-federation-server** | The **GraphQL federation** layer (NextGen API) | Node / TypeScript (GraphQL Mesh) | node CI; `reusable-deploy.yml` |

> Repo names are mid-rename (`czid-*`/`cypherid-*`/`idseq-*` → `seqtoid-*`). See the rename epics (CZID-170/53 and children). Treat the names above as the current truth.

## How it fits together (request → result)

```
            ┌─────────────────────────────┐
  Browser → │ seqtoid-web (Rails + React) │ ── GraphQL ──┐
            └─────────────┬───────────────┘              │
                          │ upload (S3) / dispatch        ▼
                          │                    seqtoid-graphql-federation-server
                          ▼                          (NextGen API)
              AWS Step Functions / Batch
                          │
                          ▼
            seqtoid-workflows (WDL pipelines,
            per-workflow Docker images on ECR)
                          │
                          ▼
              Results → S3 / DB → seqtoid-web UI
```

All of the AWS substrate underneath (VPC, EKS/ECS, RDS, S3, Batch, IAM, Step Functions) is defined as code in the three **IaC repos**, whose state is centralized in the **state foundation** (`czid-infra`).

## The AWS accounts
Infrastructure is split across **four AWS accounts**: `dev`, `staging`, `prod`, and `support`. `cypherid-web-infra` already encodes this as `terraform/accounts/idseq-{dev,prod,staging,support}/` (per-account provider + backend wiring) and `terraform/envs/<env>/<component>/` (the stacks). See [03 — Terraform / IaC](03-terraform-iac.md). Whether to separate state/pipelines further per account is an open exploration (CZID-208).

## The toolchain at a glance
- **Terraform 1.12.1** (not Terraform; not fogg) — all IaC. Pinned via `.terraform-version`.
- **Node 20.20.2** (seqtoid-web frontend, gql-fed) — pinned via `.node-version`.
- **Ruby 3.3.6** (seqtoid-web backend) — pinned via `.ruby-version`.
- **Python 3.10** (seqtoid-workflows) — pinned via `.python-version`.
- **Docker** — all pipeline workflows + local validation harnesses.
- **GitHub Actions** — CI/CD. Actions are kept on the Node-24 runtime (see [04](04-dependencies-and-versions.md)).
- **Linear** — work tracking (ticket IDs are `CZID-NNN`).
