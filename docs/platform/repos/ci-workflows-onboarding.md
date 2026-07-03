# Onboarding — seqtoid-ci-workflows

A current-state, junior-engineer-friendly guide to **`seqtoid-ci-workflows`**: what it is,
its components, how it works, the common tasks, and a setup → operate → troubleshoot
runbook. Everything here is grounded in what's checked in today; if a detail disagrees with
the repo, **the repo wins** — please fix the drift.

> Repo: `thorvath-slower/seqtoid-ci-workflows` (public). Authoritative design doc:
> [`docs/DESIGN.md`](https://github.com/thorvath-slower/seqtoid-ci-workflows/blob/main/docs/DESIGN.md).
> This guide is the onboarding companion to it.

---

## 1. What it is & why it exists

`seqtoid-ci-workflows` is the **single source of truth for cross-repo CI** on the platform
(epic CZID-310 / #408). Instead of each repo carrying its own copy of the same scan — which
drifts — every repo **calls a reusable workflow** hosted here. One definition, updated once,
used everywhere.

The problem it kills: a single CI change (e.g. the OpenTofu → Terraform revert) used to
require an edit in every repo. Centralizing removes that drift.

> **Renamed from `ci-workflows`.** It also **absorbed the former standalone
> `flake8-action` repo**, which now lives here as `flake8-action/`.

## 2. Where it sits in the platform

It is **cross-cutting** — not part of the foundation → IaC → app stack, but consumed by
every repo in it. See [08 — Architecture & the SSOT](../08-architecture-and-ssot.md). It is
the **CI** SSOT, complementing `seqtoid-ssot-infra` (the **infra** SSOT).

## 3. Components — the moving parts

| Path | What it is |
|---|---|
| `.github/workflows/security.yml` | **Reusable security scan**: gitleaks (secrets) + trivy (vuln + misconfig, hard-fail HIGH/CRITICAL) + tflint + opt-in checkov. Checks out the **caller's** repo, so each repo keeps its own `.trivyignore` baseline. |
| `.github/workflows/terraform-ci.yml` | **Reusable Terraform fmt + validate gate**: `terraform fmt -check` + per-stack `terraform validate -backend=false` (+ optional codegen / lockfile pin). Pure correctness, no cloud creds. |
| `.github/workflows/drift-check.yml` + `bin/drift-check.py` | Scheduled config-drift check. |
| `.github/workflows/selftest.yml` + `selftest/tf/` | The repo's **own** CI — proves the reusable workflows work against a fixture before consumers pin a new `@v1`. |
| `flake8-action/` | Python flake8 linter action (collapsed in from the standalone repo). Consumed as `thorvath-slower/seqtoid-ci-workflows/flake8-action@v1`. |
| `ci-adoption.yaml` | Tracks which consumer repos have adopted which reusable workflow. |

## 4. How it works — the propagation model

The crux is the tension between *"update the SSOT only"* (a moving ref) and
*"strong/secure/reproducible"* (immutable SHA pins). The **approved model is the hybrid**:

- **Consumer → SSOT edge:** consumers pin our reusable workflows/actions at the **moving
  major tag `@v1`**. One edit here + moving `v1` propagates to **every** repo with **no
  downstream change** — exactly the SSOT-only property.
- **SSOT → third-party edge:** *inside* the reusable workflows, every third-party action is
  pinned by **full SHA**, bumped by Renovate **in one place** (here). A tool/action bump is
  one PR in the SSOT, never N across consumers.
- **Why the moving `@v1` is safe:** it's *our* repo and we harden + gate it, removing the
  classic compromised-upstream risk of a moving tag.

```
consumer repo (.github/workflows/security.yml)
   uses: thorvath-slower/seqtoid-ci-workflows/.github/workflows/security.yml@v1
        │  (moving tag — one move here rolls out everywhere)
        ▼
seqtoid-ci-workflows/security.yml
   uses: <third-party-action>@<full-sha>   ← SHA-pinned, Renovate-bumped in one place
```

## 5. How-to guides — the common tasks

**Adopt the security scan in a repo** — add `.github/workflows/security.yml`:
```yaml
name: security
on: [push, pull_request, merge_group, workflow_dispatch]
jobs:
  security:
    uses: thorvath-slower/seqtoid-ci-workflows/.github/workflows/security.yml@v1
    with:
      run_checkov: ${{ inputs.run_checkov || false }}
```
Keep the repo's own `.trivyignore` baseline (accept inherited findings, hard-fail on NEW —
CZID-264).

**Adopt the Terraform gate** — add `.github/workflows/terraform-ci.yml`:
```yaml
name: terraform-ci
on:
  push: { branches: [main] }
  pull_request:
jobs:
  terraform-ci:
    uses: thorvath-slower/seqtoid-ci-workflows/.github/workflows/terraform-ci.yml@v1
    with:
      fmt_path: infra/
      check_lockfile: true
      stacks: |
        infra/state-foundation/foundation
```
Inputs: `fmt_path`, `stacks` (newline list) **or** `validate_command`, `prepare` (codegen),
`check_lockfile`, `terraform_version` (default `latest`).

**Use the flake8 action** — `uses: thorvath-slower/seqtoid-ci-workflows/flake8-action@v1`.

**Change a reusable workflow (the SSOT edit)** — branch off `integration`, edit the
reusable, keep third-party `uses:` SHA-pinned, run `selftest.yml` green, gated PR → merge,
then **move the `v1` tag** to publish to all consumers.

## 6. Runbook — setup → operate → troubleshoot

- **Setup / consume:** you don't clone this repo to *use* it — you reference `@v1` from a
  consumer (§5). Clone only to *change* the reusable workflows.
- **Build/test:** `selftest.yml` (+ `selftest/tf/`) is the build — it runs the reusable
  workflows against a fixture. Run it green before moving `v1`.
- **Deploy (= publish):** "deploying" a change is **moving the `@v1` major tag** after
  merge. Breaking changes bump the major (`v2`) so consumers opt in.
- **Operate:** Renovate keeps the SHA-pinned third-party actions current, one PR at a time,
  here. `ci-adoption.yaml` tracks consumer coverage.
- **Troubleshoot:**
  - *A consumer's scan suddenly fails after no consumer change* → the `v1` tag moved; check
    recent commits here and `selftest.yml`.
  - *trivy hard-fails on an inherited finding* → add the short-form ID to the **consumer's**
    `.trivyignore` (baseline), not here — the reusable scans the caller's tree.
  - *A repo needs a richer, repo-specific gate* (e.g. cypherid-web-infra's changed-files +
    tiered validation) → it keeps its own; uniformity only where it doesn't lose function.

## 7. Links

- Design & policy (authoritative): `seqtoid-ci-workflows/docs/DESIGN.md`
- Platform architecture & SSOT: [08 — Architecture & the SSOT](../08-architecture-and-ssot.md)
- Branch/merge/deploy rules: [Branching & deploy model](../BRANCHING-DEPLOY-MODEL.md)
