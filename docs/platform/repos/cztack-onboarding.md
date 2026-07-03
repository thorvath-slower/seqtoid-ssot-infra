# Onboarding — cztack (shared Terraform modules)

A current-state, junior-engineer-friendly guide to **cztack**: what it is, how it's
vendored into the platform, how it's pinned and consumed, and how to update it.
Everything here is grounded in what's checked in today; if a detail disagrees with the
repos, **the repos win** — please fix the drift.

> Two things named "cztack" — don't confuse them:
> - **`thorvath-slower/cztack`** — the standalone **private in-house fork** of the upstream
>   `chanzuckerberg/cztack` module collection.
> - **`seqtoid-ssot-infra/modules/cztack/`** — the **vendored copy** the platform actually
>   consumes (see `modules/cztack/VENDORING.md`).

---

## 1. What it is & why it exists

**cztack** (pronounced "stack") is CZI's collection of shared Terraform modules —
reusable building blocks (`aws-eks-cluster`, `aws-s3-private-bucket`, IAM roles/policies,
CloudWatch log groups, etc.) that our IaC composes instead of hand-writing raw resources.

We bring it in-house for two reasons:

1. **Remove the external supply-chain dependency.** Previously consumers referenced
   `github.com/chanzuckerberg/cztack//<module>?ref=...` directly — an external public-repo
   dep resolved at plan/apply time. Vendoring pins it to code we control and can scan.
2. **Standalone private fork, not a GitHub fork.** Per platform policy, third-party deps
   are brought in as a **standalone private `thorvath-slower` repo** (`gh repo create
   --private`), never `gh repo fork` (which is public + upstream-linked). Consumers then
   pin by tag/SHA.

## 2. Where it sits in the platform

cztack is a **dependency of the IaC layer**, consumed *through the SSOT*. The vendored
modules live in `seqtoid-ssot-infra/modules/cztack/`; IaC stacks reference them by relative
path. See [08 — Architecture & the SSOT](../08-architecture-and-ssot.md).

```
cztack (upstream chanzuckerberg)  ──vendored at a tag──▶  seqtoid-ssot-infra/modules/cztack/
                                                                   │  module "x" { source = "../modules/cztack/<m>" }
                                                                   ▼
                                          cypherid-web-infra / cypherid-workflow-infra stacks
```

## 3. Components

| Location | What it is |
|---|---|
| `thorvath-slower/cztack` | The standalone private fork of the upstream collection; ~59 modules. Source of truth for *what a module version contains*. |
| `seqtoid-ssot-infra/modules/cztack/` | The **vendored** modules the platform consumes. `VENDORING.md` records source, version, license, and date. |
| `seqtoid-ssot-infra/modules/cztack/VENDORING.md` | The provenance + rules file — **read this before touching the modules**. |

## 4. How it works — vendoring, pinning, consuming

- **Vendored version:** `v0.104.2` (the dominant pinned version across our consumers),
  vendored **in full** on purpose (all modules, not only the ones used today — prod may
  need modules we don't reference yet; a follow-up trims to what's needed). License: **MIT**
  (original copyright retained).
- **How consumers pin:** stacks reference the vendored module by **relative path**, e.g.
  `source = "../modules/cztack/aws-eks-cluster"`. The version is implicit in the vendored
  tree (no external `?ref=`). Where a consumer refers to a specific older version, the path
  is suffixed (e.g. `aws-s3-private-bucket-v0.73.0`) and a note records the cztack version.
- **Version skew is known:** some consumers are still pinned to **older cztack versions**
  (v0.41.0 ×29, plus v0.43.1 / v0.26.1 / v0.91.1 / v0.73.0 / v0.60.0). These are handled by
  a **separate version-reconciliation step** (upgrade-to-v0.104.2 with plan review, or
  vendor the specific older version) before their refs can be repointed to the vendored copy.

## 5. How-to guides

**Consume a cztack module in a new stack**
```hcl
module "log_group" {
  source = "../modules/cztack/aws-cloudwatch-log-group"
  # ... module inputs ...
}
```
Use a relative path into the vendored tree. Do **not** re-add an external
`github.com/chanzuckerberg/cztack//...?ref=...` source — that reintroduces the
supply-chain dep we removed.

**Update to a newer cztack version** — **re-vendor from upstream at the new tag**; do
**not** hand-edit the vendored modules. Then run a plan review across affected consumers
before repointing them. Record the new version/date in `VENDORING.md`.

**Add a consumer currently on an older version** — either upgrade it to the vendored
version (plan-reviewed) or vendor the specific older version alongside; don't silently
repoint it to a different version.

## 6. Runbook — setup → operate → troubleshoot

- **Setup:** nothing to install — the modules are in-tree under
  `seqtoid-ssot-infra/modules/cztack/`. `terraform init` in a consuming stack resolves the
  relative-path modules locally.
- **Validate:** the SSOT's terraform-ci gate (`terraform fmt -check` + `validate`) covers
  the vendored modules; the security scan **skips** `modules/cztack/` (vendored upstream
  code, not our source — CZID-418) to avoid inheriting upstream findings as new failures.
- **"Operate":** cztack has no runtime — it's build-time module code. "Operating" it is the
  vendoring lifecycle: re-vendor at a tag when an update is needed, reconcile consumer
  versions, keep `VENDORING.md` accurate.
- **Troubleshoot:**
  - *`terraform init` can't find a module* → check the relative `source` path resolves into
    `modules/cztack/`; a `-v<version>` suffix must match a directory that exists.
  - *A plan wants to replace resources after a cztack bump* → expected across a version jump;
    review the diff before applying — that's the reconciliation step, not a bug.
  - *A scanner flags a finding under `modules/cztack/`* → usually vendored-upstream noise;
    the scan is configured to skip this tree. Verify deployed-vs-noise before ticketing.

## 7. Links

- Provenance & rules: `seqtoid-ssot-infra/modules/cztack/VENDORING.md`
- Upstream: https://github.com/chanzuckerberg/cztack
- Platform architecture & SSOT: [08 — Architecture & the SSOT](../08-architecture-and-ssot.md)
- Dependency/version policy: [04 — Dependencies & versions](../04-dependencies-and-versions.md)
