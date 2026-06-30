# CZ ID Stack — Bug / Remediation Inventory

Findings from the discovery/review pass. **Each fix is committed on its own branch using the convention `bug-#NNN-<slug>`** (e.g. `bug-#010-rank-session-var-ranking`), one branch + commit per bug, never pushed.

> Most items below are **security / EOL / portability findings** rather than functional crashes — but each is a real defect or risk worth a tracked fix. Severity is operational risk, not "the app is down."

**Legend — can the agent complete it?**
- ✅ **Fully** — I author the complete fix (code/config/tests), ready to review/merge, no live access needed. Final *runtime/perf validation on real data* is still yours for the SQL items.
- 🔶 **Author-only** — I write the change, but **you** must build/run/validate it (version upgrades break things only at runtime) or supply real values (secret rotation).
- ⛔ **Yours** — requires the live environment, real data, or human sign-off; I can't do it at all. *(No finding is purely ⛔ — every fix here I can at least author; the ⛔ work is the validation/apply tail, listed in §3.)*

---

## 1. Bugs I can fix end-to-end (✅)

| ID / branch | Finding | Repo | Severity | Fix I author |
|-------------|---------|------|----------|--------------|
| **bug-#006-tf-state-locking** | No Terraform state locking → concurrent applies can corrupt state | `cypherid-web-infra` | High | DynamoDB lock table / Terraform `use_lockfile`. **Already implemented** in the state-backend scaffold (`feat/shared-state-backend`); re-commit under this ID if tracked separately. |
| **bug-#007-overbroad-deploy-iam** | Over-broad deploy IAM role (least-privilege violation) | `cypherid-web-infra` | High | Scoped, least-privilege policy/role in HCL + a deny-by-default baseline. |
| **bug-#008-manual-deploy-no-bluegreen** | Manual `workflow_dispatch` deploys; no blue/green; no auto-rollback | CI / `cypherid-web-infra` | Medium | Automated GitHub Actions deploy + Argo Rollouts blue/green spec with analysis gate, auto-rollback, graceful drain. |
| **bug-#010-rank-session-var-ranking** | Fragile MySQL `@rank` session-variable ranking in the `TaxonCount` path — plan-dependent, correctness-risky | `seqtoid-web` | Medium | Rewrite to `ROW_NUMBER()` window functions + parity tests (offline). |
| **bug-#011-mysql-specific-sql** | MySQL-only SQL (`GROUP_CONCAT`, `IFNULL`, `RAND`, `json_extract`) blocks portability & Postgres parity | `seqtoid-web` | Medium | Rewrite to `string_agg`/`COALESCE`/`random()`/jsonb operators + parity tests (offline). |
| **bug-#012-unproxied-dependencies** | Builds pull dependencies straight from the public internet (no proxy/pinning → supply-chain risk) | all | Medium | CodeArtifact/Artifactory proxy config + pinned lockfiles + checksum verification. |

---

## 2. Bugs I can author, but YOU must validate/run (🔶)

| ID / branch | Finding | Repo | Severity | I author / you do |
|-------------|---------|------|----------|-------------------|
| **bug-#001-ruby-eol-upgrade** | Ruby 3.1 is EOL (no security patches) | `seqtoid-web` | High | I bump `.ruby-version`/Gemfile + known dep updates → **you** build, run the suite, fix runtime breakages. |
| **bug-#002-rails-eol-upgrade** | Rails 7.0 is EOL | `seqtoid-web` | High | I bump the Gemfile + author upgrade shims/config → **you** run `rails app:update`, resolve deprecations, test. |
| **bug-#003-node-eol-upgrade** | Node 16/18 are EOL | `seqtoid-web`, `seqtoid-graphql-federation-server` | High | I bump `engines`/Dockerfile/CI → **you** build, run, fix breakages. |
| **bug-#004-base-image-eol** | EOL base images (Ubuntu 18.04/20.04, old images) | Dockerfiles (multiple) | High | I update base tags + harden → **you** rebuild and confirm images boot. |
| **bug-#005-mysql-eol** | Aurora MySQL 5.7 engine EOL | infra/data | Medium | I author the version bump → **you** apply. *Note: superseded by the Postgres migration in the overhaul path.* |
| **bug-#009-secrets-no-rotation** | ~110 Secrets Manager/SSM refs, no rotation, no dynamic creds | multiple | Medium | I author OpenBao/rotation config + dynamic-cred engine → **you** rotate the real values and unseal. |

---

## 3. The ⛔ tail — what only you can do (the validation/apply half)

These aren't separate bugs; they're the parts of the fixes above that need the live environment, real data, or sign-off:
- Building & running the upgraded runtimes and fixing runtime-only breakages (#001–#004).
- Applying the engine/version changes against real infra (#005); `terraform apply` of the IAM scoping (#007).
- **Live-data parity & performance validation** of the SQL rewrites (#010, #011) — I provide offline parity tests; the real-data run and `EXPLAIN` tuning are yours.
- Rotating real secrets and unsealing OpenBao (#009).
- Security review / pen test sign-off where relevant.

---

## 4. Workflow

- One branch + commit per bug: `git checkout -b bug-#NNN-<slug>` → fix → `git commit -m "bug-#NNN: <name of bug fix>"` → re-bundle `--all` to outputs. Never push.
- Most ✅ fixes need the **real source files** (upload them here, or use the coding agent against the local repo) — I can't fix files I can't see. `bug-#006` is the exception: already done in the state-backend scaffold.
- Order suggestion: knock out the ✅ self-contained fixes first (#006 done, then #007, #010, #011, #012, #008), then the 🔶 version upgrades as a batch (#001–#004) since they interact.
