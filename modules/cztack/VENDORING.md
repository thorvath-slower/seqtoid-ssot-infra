# Vendored: cztack

These are the shared Terraform modules from **chanzuckerberg/cztack**, vendored into this SSOT repo to
**remove the external upstream dependency** (previously consumers referenced
`github.com/chanzuckerberg/cztack//<module>?ref=...` directly — an external public-repo supply-chain dep).

- **Source:** https://github.com/chanzuckerberg/cztack
- **Vendored version:** `v0.104.2` (the dominant pinned version across our consumers)
- **License:** MIT (see `LICENSE`) — original copyright retained.
- **Vendored:** 2026-07-01

## Notes
- **Pulled in full on purpose** (all modules, not only the ones currently used) — prod may need modules we
  don't reference today. A follow-up will review and trim to what's legitimately needed.
- Consumers still pinned to **older cztack versions** (v0.41.0 ×29, + v0.43.1/v0.26.1/v0.91.1/v0.73.0/v0.60.0)
  are handled by a separate version-reconciliation step (upgrade-to-v0.104.2 with plan review, or vendor the
  specific older versions) before their refs can be repointed here.
- Do not hand-edit these modules; re-vendor from upstream at a new tag if an update is needed.
