# Vendored: cztack

These are the shared Terraform modules from **chanzuckerberg/cztack**, vendored into this SSOT repo to
**remove the external upstream dependency** (previously consumers referenced
`github.com/chanzuckerberg/cztack//<module>?ref=...` directly — an external public-repo supply-chain dep).

- **Source:** https://github.com/chanzuckerberg/cztack
- **Vendored version:** `v0.104.2` (the dominant pinned version across our consumers)
- **License:** MIT (see `LICENSE`) — original copyright retained.
- **Vendored:** 2026-07-01

## Scope: trimmed to the consumed set (CZID-404, 2026-07-09)

Originally all 60 upstream modules were vendored in full (#403) as a precaution so prod would not be
missing anything. Per CZID-404 (Tom approved the trim), the set has now been scoped to the modules that
are legitimately consumed across the live infra repos, plus their transitive cztack-to-cztack
dependencies. This supersedes the earlier "pulled in full on purpose" note.

- **Kept: 26 modules.** Selection = every cztack module referenced by a `source = ...` in a live
  consumer repo (path-style `.../<module>-vX.Y.Z` or git-style `//<module>?ref=...`), taking the union
  of base names and ignoring the version suffix, then closing over the internal `../<sibling>` references
  so a kept module never dangles (e.g. `aws-eks-cluster` pulls in `aws-firehose-s3-archiver`,
  `aws-iam-role-github-action`, `aws-iam-policy-ecr-writer`; `aws-aurora-mysql` pulls in `aws-aurora`;
  `aws-lambda-edge-add-security-headers` pulls in `aws-lambda-function`; the `aws-iam-role-*` roles pull
  in `aws-assume-role-policy`). Consumer scan covered cypherid-web-infra, seqtoid-graphql-federation-server,
  cypherid-workflow-infra and czid-infra; the standalone `cztack` fork mirror and the frozen
  `_baseline-itars` snapshot were excluded as they are not live SSOT consumers.
- **Removed: 34 modules** with zero references anywhere in the live infra repos, e.g. `aws-ecs-service`,
  `aws-ecs-service-fargate`, `aws-ecs-job-fargate`, `aws-aurora-postgres`, `aws-redis-node`,
  `aws-s3-public-bucket`, `aws-efs-volume`, `aws-cloudfront-*`, `bless-ca`, and the unused
  `aws-iam-role-*` / `aws-iam-group-*` variants.
- **Re-vendoring:** if a removed module is newly needed, re-vendor just that module from upstream at the
  pinned tag (`v0.104.2`) rather than restoring the whole set.

## Notes
- This SSOT copy currently has **no direct consumers yet** -- this repo's own stacks
  (`infra/state-foundation/**`) do not source cztack, and the live consumer repos still point at their own
  per-repo versioned copies (`.../modules/aws-<name>-vX.Y.Z`) or the upstream git ref. The kept set is the
  forward target for when those consumers are repointed here; nothing prod/staging depends on was dropped.
- Consumers still pinned to **older cztack versions** (v0.41.0, plus v0.43.1/v0.26.1/v0.91.1/v0.73.0/v0.60.0)
  are handled by a separate version-reconciliation step (upgrade-to-v0.104.2 with plan review, or vendor the
  specific older versions) before their refs can be repointed here.
- Do not hand-edit these modules; re-vendor from upstream at a new tag if an update is needed.
