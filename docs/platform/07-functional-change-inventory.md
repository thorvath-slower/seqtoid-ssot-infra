# 07 — Functional Change Inventory

Everything the overhaul changed, organized by area, with ticket references. This is the "what did we do and why" map — use it to understand *why* the platform looks the way it does. For day-by-day detail see the `ACCOMPLISHMENTS-*.md` and `SESSION-*` docs at the workspace root.

> Convention key: ✅ done/merged · ◐ in progress · ⬜ planned/backlog · 🅱️ Bucket B (needs live AWS).

## A. Build system & toolchain: Terraform/fogg → Terraform
- ✅ Converted the IaC repos from Terraform/Terraform-Cloud/fogg to **Terraform 1.12.1** (CZID-2, CZID-16). Removed fogg scaffolding; the tree is hand-authored.
- ✅ **State foundation** stood up in `czid-infra` (`main` is the trunk): shared S3 backend `czid-tfstate-<account>-<region>` with **S3-native state locking** (CZID-29), bootstrap → foundation → consumers (state-foundation set).
- ✅ **Provider lockfiles committed + `-upgrade` dropped** so builds are reproducible (CZID-30 for workflow-infra; ⬜ CZID-198 for web-infra's remaining half).
- ✅ `hashicorp/setup-terraform@v1` → `@v2` (Node-24 runtime) across all 3 IaC repos (CZID-199).
- ⬜ Confirm fogg/Terraform fully gone (CZID-95); fogg-replacement **starter template** (CZID-207); per-account separation **workup** (CZID-208).

## B. Single-source-of-truth (SSOT) for versions
- ✅ Audit + sweep so every toolchain version lives in one file (`.terraform-version`/`.node-version`/`.ruby-version`/`.python-version`), CI reads the file (CZID-140 + children).
- ✅ seqtoid-web node single-sourced to `.node-version` across the repo: bumped `.node-version` 20.18.1 → **20.20.2**, `bin/setup-ci` + `Dockerfile` read the file (CZID-195/196/197).
- ✅ Workflow-infra provider versions consolidated into `versions.tf` (CZID-169); web-infra uses a symlinked `_shared/versions.tf`.
- ⬜ Renovate across the repos to keep it current (CZID-8).

## C. GitHub Actions: Node-runtime modernization
- ✅ Node-20/16 runtime sweep — bump every action to a Node-24-compatible version before GitHub removes Node 20 on **2026-09-16** (CZID-89). IaC repos done; app-repo remainder mapped to CZID-163/150.
- ✅ Brought `flake8-action` in-house: standalone **private** `thorvath-slower/flake8-action` (node16 → node24), consumers pinned to the SSOT `@v2` moving tag (CZID-204).
- ⬜ Held action bumps: `configure-aws-credentials@v4→v6`, `upload-artifact@v4→v7`, release-please (CZID-163/149); seqtoid-workflows actions (CZID-150).

## D. Security & supply-chain hardening
- ✅ **Digest-pinned** container images (CZID-4); unverified Dockerfile downloads tracked (CZID-78).
- ✅ IaC hardening landed/triaged: S3 public-access-block + IMDSv2 documentation (CZID-57 part 1); Brakeman re-triage to 6.1.2 (CZID-48); Open3 shell-form → `FileUtils` (CZID-191); resque CSRF / Rails 7.1 (CZID-117); AWS SDK + `stub_const` test fixes (CZID-119/120).
- 🅱️ Apply-gated hardening held for live access: encryption-at-rest CMK (CZID-57 remainder), RDS protection/logging (CZID-32/33), force_destroy removal (CZID-31), private-key-in-state (CZID-42), latent public RDS (CZID-43), IAM least-privilege (CZID-28/18), EKS public endpoint (CZID-55). Tracker: CZID-167.
- ⬜ Triage the 40 active Brakeman warnings before ratcheting (CZID-189); security-scanning suites per repo (CZID-183/102/98).

## E. EOL refreshes
- ✅ Node bump (above). ✅ Benchmark image off frozen 2022 Jupyter → `quay.io/jupyter/scipy-notebook` py3.13 (CZID-203).
- ◐ EOL container base images — `ubuntu:18.04` set in seqtoid-workflows decomposed per image (CZID-44 parent → CZID-200 diamond / 201 legacy-host-filter / 202 short-read-mngs+s3quilt; 203 done).
- ⬜ MySQL 5.7 EOL → 8.x for upstream/harness (CZID-194); sentry-raven → sentry-ruby (CZID-154); axios/TS4.6 (CZID-45).

## F. CI / delivery
- ✅ Local validation harnesses: seqtoid-web `make ci-local`, seqtoid-workflows `bin/ci-local` (CZID-184), the offline test harness (CZID-193).
- ⬜ Promotion gating dev→staging→prod (no direct-to-prod) across IaC + apps (CZID-96/164/165/166/101); image build/scan/sign + promotion (CZID-75/77/74); one-button provisioning (CZID-11).

## G. Database & API direction (planning)
- ⬜ seqtoid-web Aurora MySQL → **PostgreSQL** (customer-driven, behavior-preserving, tests-first; improvement-#005 / CZID-21 live cutover 🅱️).
- ✅ API simplification — the GraphQL federation layer was collapsed into Rails-native `/graphql` (CZID-129 spike → Phases 1–4 CZID-132–136 + the ports 285/302–311). The `seqtoid-graphql-federation-server` is **decommissioned**; Rails serves `/graphql` directly (contract locked by a schema test, CZID-158).

## H. Dependency sourcing (planning)
- ⬜ Single **FOSS** internal source for all build/runtime deps to avoid intermittent internet-dependency failures (CZID-205 spike → CZID-23 stand-up 🅱️; CZID-86 egress allowlist; CZID-10 golden image/offline mirror).

## I. Documentation & process
- ✅ PR/ticket conventions: small, single-concern, traceable (CZID-108); this maintenance guide (CZID-206).
- ⬜ Platform rename `czid/cypherid/idseq → seqtoid` across repos/docs/identifiers (CZID-170/53 epic + CZID-171–174/181/182).

---
*This inventory is a snapshot — re-pull live Linear state each session; ticket statuses move.*
