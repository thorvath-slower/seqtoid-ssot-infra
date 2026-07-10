# Version / Dependency SSOT -- Audit + Plan (CZID-140)

Status: analysis / options doc. The DECISIONS below are Tom's to make; nothing here
changes code or config. Scope: every repo under the CSID refactor working tree.

Companion docs (already in the repo / workspace):
- `docs/platform/04-dependencies-and-versions.md` -- the SSOT *principle* + intended table.
- `CI-SSOT-DESIGN.md` (workspace) -- the CI-tool-version centralization design (approved 2026-07-01, hybrid model).
- Ticket #140 comment (2026-06-29) asserted SSOT was "implemented, consistent, documented." This
  audit is a fresh ground-truth re-scan (2026-07-09) and finds the *principle* is well established but
  several concrete values have since drifted and a few CI hardcodes remain.

---

## 1. The SSOT principle (what "done" looks like)

> Every tool/runtime version is pinned exactly **once**, in a version file. CI **reads the file**,
> it never hardcodes the version. Provider/dependency versions are centralized (one `versions.tf`,
> one lockfile). Lockfiles are committed. Renovate keeps everything current.

Two independent SSOT axes:

1. **Per-repo runtime pins** -- `.ruby-version`, `.node-version`, `.python-version`,
   `.terraform-version`. One file per tool per repo; every consumer
   (CI `setup-*`, Dockerfile `FROM`, `engines`, `Gemfile ruby file:`) resolves *from that file*.
2. **Cross-repo CI-tool pins** -- scanner/linter versions (trivy, tflint, checkov, gitleaks) and
   the Terraform/Node CI action versions live once inside the shared `seqtoid-ci-workflows`
   reusables, consumed by a moving `@v1` tag (CI-SSOT-DESIGN.md, option C hybrid).

A runtime version is allowed to differ *between* repos when the repos genuinely have different needs
(e.g. a lambda stuck on an EOL base). What is NOT allowed is the same repo pinning the same tool in
two places that disagree, or CI hardcoding a number that a version file already owns.

---

## 2. Current state -- ground-truth scan (2026-07-09)

Repos scanned: `seqtoid-web`, `seqtoid-workflows`, `cypherid-web-infra`, `seqtoid-ssot-infra`,
`cypherid-workflow-infra`, plus the CI/library repos `seqtoid-ci-workflows`, `cztack`,
`seqtoid-graphql-federation-server`.

### 2.1 Runtime version files (the SSOT files that exist)

| Repo | Ruby | Node | Python | IaC engine |
|---|---|---|---|---|
| seqtoid-web | `.ruby-version` 3.3.6 | `.node-version` 24.18.0 | `.python-version` 3.12 | -- |
| seqtoid-workflows | -- | -- | `.python-version` 3.10 | -- |
| cypherid-web-infra | -- | -- | -- | `.terraform-version` 1.15.7 |
| seqtoid-ssot-infra | -- | -- | -- | `.terraform-version` 1.15.7 |
| cypherid-workflow-infra | -- | -- | `.python-version` 3.9 | `.terraform-version` 1.15.7 |
| seqtoid-ci-workflows | -- | -- | -- | (reads caller's file) |
| cztack | -- | -- | -- | `.terraform-version` 1.15.7 |
| seqtoid-graphql-federation-server | -- | `.node-version` 20.18.1 | -- | -- |

### 2.2 How each version file is consumed (agree vs hardcode)

| Consumer surface | Reads the SSOT file? | Notes |
|---|---|---|
| seqtoid-web Ruby CI (`check.yml`, `pull-request-only.yml`) | YES | comment confirms setup-ruby auto-reads `.ruby-version` |
| seqtoid-web Node CI (`check.yml`, `e2e`, `nightly`, `prettier`) | YES | `node-version-file: ./.node-version` |
| seqtoid-web Python CI (`check.yml`) | YES | `python-version-file: .python-version` |
| seqtoid-web `Gemfile` | YES | `ruby file: '.ruby-version'` (best-in-class -- no duplicate pin) |
| seqtoid-web `package.json` engines | PARTIAL | `node >=24 <25`, `npm >=11 <12` -- a *range* that must be kept in sync with `.node-version` by hand |
| seqtoid-web Dockerfile builder stage | YES + digest | `FROM ruby:3.3.6@sha256:347e...` |
| seqtoid-web Dockerfile runtime stage | TAG ONLY | `FROM ruby:3.3.6-slim` -- **not digest-pinned** (builder is; runtime isn't) |
| graphql-federation Node CI (`jest`, `security`, `deploy`) | YES | `node-version-file: .node-version` |
| graphql-federation Dockerfile | YES + digest | `FROM node:20.18.1@sha256:968c...` matches `.node-version` |
| graphql-federation `package.json` engines | MISSING | no `engines` block -- Node floor not enforced at install time |
| web-infra / ssot-infra Terraform CI | YES | via `seqtoid-ci-workflows/terraform-ci.yml@v1` `terraform_version_file` |
| workflow-infra IaC CI (`validate.yml`, `plan_call.yml`) | YES | `terraform_version_file: .terraform-version` |
| workflow-infra Python CI (`check.yml`) | YES | `python-version-file: .python-version` |
| **seqtoid-workflows `idseq-dag-tests.yml`** | **NO -- HARDCODED** | `python-version: "3.12"` while repo `.python-version` = **3.10** (drift, and no file read) |

### 2.3 Container base images (digest-pinning posture)

| Repo | Base images | Digest-pinned? |
|---|---|---|
| seqtoid-web | `ruby:3.3.6` builder / `ruby:3.3.6-slim` runtime | builder YES, runtime NO |
| graphql-federation | `node:20.18.1` | YES |
| cypherid-web-infra | `grafana/grafana:7.1.2` | YES |
| seqtoid-workflows | ~13 `ubuntu:{18,20,22}.04` bases + `quay.io/jupyter/scipy-notebook` | jupyter YES; **all ubuntu bases TAG-only** |
| cypherid-workflow-infra | `python:3.8`, `public.ecr.aws/lambda/python:3.8`, `node:18`, `nodejs:18` | **none pinned; also EOL runtimes** |

### 2.4 Terraform / provider constraints (the cross-cutting SSOT)

| Repo | `required_version` | AWS provider | SSOT mechanism |
|---|---|---|---|
| cypherid-web-infra | `>= 1.10` | `~> 5.100.0` | `_shared/versions.tf` **symlinked** into every stack (strong SSOT) |
| seqtoid-ssot-infra (template) | `>= 1.10` | `~> 5.100` | `templates/terraform-stack/_shared/versions.tf` symlinked (strong) |
| seqtoid-ssot-infra (live `state-foundation`) | `>= 1.6` | `>= 5.0` | **own per-module blocks, NOT symlinked to the template** -- floor + provider drift |
| cypherid-workflow-infra | `>= 1.10` | `~> 4.54` | `versions.tf` symlinked (CZID-169) -- but AWS **4.x** vs web-infra **5.100** |
| cztack (module library) | mixed `>= 0.13` .. `~> 1.9` | mixed `~> 5.0` / `>= 5.99` | per-module, loose floors -- acceptable for a library, not a consumer |

### 2.5 Cross-repo CI-tool centralization (`seqtoid-ci-workflows@v1`)

| Repo | Uses shared `security.yml@v1` | Uses shared `terraform-ci.yml@v1` | flake8 source |
|---|---|---|---|
| seqtoid-ssot-infra | YES | YES | -- |
| cypherid-web-infra | YES | (own `terraform_ci.yml`, richer) | -- |
| seqtoid-web | NO (inline `security-scan.yml`) | -- | `seqtoid-ci-workflows/flake8-action@v1` |
| seqtoid-workflows | NO (inline `security.yml`) | -- | -- |
| cypherid-workflow-infra | NO (inline `security.yml` + `validate.yml`) | NO | **`thorvath-slower/flake8-action@v2`** (the *old* standalone fork) |
| graphql-federation | NO (inline `security.yml`) | -- | -- |

Inside the reusable, `security.yml` still passes `tflint_version: latest` (unpinned) -- the one tool
version not yet nailed down in the SSOT.

### 2.6 Renovate / Dependabot coverage

| Repo | Automation |
|---|---|
| seqtoid-web, seqtoid-workflows, cypherid-web-infra, seqtoid-ssot-infra, cypherid-workflow-infra, seqtoid-ci-workflows, graphql-federation | `renovate.json` present |
| cztack | `.github/dependabot.yml` (kept from the upstream fork) |

Renovate/Dependabot is present in **every** repo -- the automation layer is uniform. (Note: Renovate
*enablement* on the Forgejo/GitHub side is tracked separately, CZID-212; a committed config is
necessary but not sufficient.)

---

## 3. Where it AGREES vs where it DRIFTS

### Agrees (SSOT working as intended)
- **Ruby:** one repo owns Ruby (seqtoid-web); `.ruby-version` = Gemfile = Dockerfile builder = CI. Clean.
- **IaC provider centralization** within web-infra and workflow-infra: symlinked `versions.tf`, one edit moves every stack.
- **Renovate** committed everywhere; **flake8** centralized (mostly); **terraform-ci/security** centralized in the two infra repos that adopted `@v1`.
- **Node** in graphql-federation: file = Dockerfile digest = CI, internally consistent.

### Drifts (the fix list feeds section 5)

D1. **The documented SSOT table is stale.** `04-dependencies-and-versions.md` still lists
Terraform **1.12.1**, Node **20.20.2**, Python **3.10**. Ground truth: Terraform **1.15.7**,
Node **24.18.0** (web) / **20.18.1** (graphql), Python **3.12/3.10/3.9**. The doc must be
regenerated from the files (or, better, generated *by* a check -- see 5.1).

D2. **Python is pinned to three different minors** with no single owner: web **3.12**,
workflows **3.10**, workflow-infra **3.9**, and a workflow-infra Dockerfile still on **3.8**.
Some spread is legitimate (lambda base images), but 3.9/3.8 are near/at EOL.

D3. **`idseq-dag-tests.yml` hardcodes `python-version: "3.12"`** against a repo `.python-version`
of **3.10** -- a direct SSOT violation (CI hardcode + value disagreement).

D4. **AWS provider major-version split:** web-infra `~> 5.100` vs workflow-infra `~> 4.54`. Two
infra repos on different provider majors is a real divergence (upgrade cost + behavioural drift).

D5. **ssot-infra `state-foundation` is off-template:** `required_version >= 1.6` and `aws >= 5.0`
instead of the template's `>= 1.10` / `~> 5.100`. The one live foundation stack doesn't inherit
the repo's own canonical `versions.tf`.

D6. **Two flake8 sources coexist:** `seqtoid-ci-workflows/flake8-action@v1` (web) vs the older
standalone `thorvath-slower/flake8-action@v2` (workflow-infra). The SSOT doc says these were
collapsed into the ci-workflows repo; workflow-infra never moved.

D7. **Digest-pinning is inconsistent:** seqtoid-web runtime stage is tag-only; all seqtoid-workflows
ubuntu bases are tag-only; workflow-infra lambda bases are tag-only *and* EOL (python3.8, node18).

D8. **`security.yml` reusable uses `tflint_version: latest`** -- an unpinned CI tool inside the SSOT.

D9. **`engines` ranges are hand-maintained** (web `package.json`, and graphql has none) -- these
duplicate/omit the `.node-version` fact rather than deriving from it.

D10. **CI-tool SSOT is only ~40% adopted:** seqtoid-web, seqtoid-workflows, workflow-infra, and
graphql all still carry inline `security.yml` copies (the exact duplication CI-SSOT-DESIGN.md set
out to kill).

---

## 4. The SSOT plan (target model, no code change here)

**Principle, restated concretely:**

1. **One version file per tool per repo** is the only place a version literal appears. Everything
   else -- CI, Dockerfiles, `engines`, Gemfile -- *reads* it. No number is written twice.
2. **CI never hardcodes** a tool version. `setup-*` uses `*-version-file`; scanner/action versions
   live inside `seqtoid-ci-workflows` reusables consumed by `@v1`.
3. **Provider/tool constraints are centralized** -- one symlinked `versions.tf` per infra repo; the
   *live* stacks must inherit it (no off-template stacks).
4. **Everything reproducible is committed and pinned by digest** -- lockfiles committed; base images
   `tag@sha256`; third-party actions SHA-pinned inside the SSOT (CI-SSOT-DESIGN option C).
5. **Renovate is the currency engine** -- committed everywhere (done) and enabled (CZID-212).

**A canonical cross-repo version registry (proposal for Tom).** Today "the SSOT" is N per-repo files
with no place that shows the whole fleet at a glance, so drift like D1/D2/D4 is invisible until a
manual scan. Two options:

- **Option A -- documented table, drift-checked (lighter).** Keep per-repo files as the SSOT, but add
  a CI check (in the platform-harness `crossrepo` layer) that regenerates the
  `04-dependencies-and-versions.md` table from the actual files and fails if the doc is stale. Cheap,
  no new moving parts, kills D1 permanently.
- **Option B -- a `versions.env` / registry in seqtoid-ssot-infra (heavier).** A single machine-readable
  file (e.g. `platform-versions.yaml`) listing the intended version per tool per repo, with the harness
  asserting each repo's file matches. Strongest guarantee; more scaffolding. **Recommend A now, B later**
  if drift keeps recurring.

---

## 5. Per-repo fix list (concrete, ordered by leverage)

### 5.1 seqtoid-ssot-infra (this repo -- the SSOT owner)
- **Regenerate `docs/platform/04-dependencies-and-versions.md`** from ground truth (fixes D1): Terraform 1.15.7, Node 24.18.0/20.18.1, Python 3.12/3.10/3.9. Add a harness `crossrepo` drift-check (Option A).
- **Bring `state-foundation` onto the canonical `versions.tf`** (fixes D5): raise `required_version` to `>= 1.10`, `aws` to `~> 5.100`, or symlink the shared file. (Verify no foundation-specific reason for `>= 1.6`.)

### 5.2 cypherid-workflow-infra (highest drift count)
- **Repoint flake8 to `seqtoid-ci-workflows/flake8-action@v1`** (fixes D6).
- **Bump `.python-version` 3.9 -> a supported minor** and align the lambda Dockerfiles off `python:3.8` / `node:18` (fixes D2/D7; pull-forward rule, file follow-up tickets -- this is the OpenTofu-not-yet-converted repo, so sequence behind that conversion).
- **Decision needed (D4):** plan the AWS provider `~> 4.54 -> ~> 5.x` upgrade to match web-infra, or record the deliberate reason it lags.
- Adopt the shared `security.yml@v1` (fixes part of D10) -- gated behind the Terraform conversion.

### 5.3 seqtoid-workflows
- **Fix `idseq-dag-tests.yml`:** replace `python-version: "3.12"` with `python-version-file: .python-version` (fixes D3) and reconcile whether the repo target is 3.10 or 3.12.
- **Digest-pin the ubuntu base images** (fixes D7) -- Renovate can then track the digests.
- Adopt shared `security.yml@v1` (D10).

### 5.4 seqtoid-web
- **Digest-pin the runtime Dockerfile stage** (`ruby:3.3.6-slim` -> `@sha256:...`) to match the builder stage (fixes D7).
- **Derive/verify `package.json` engines from `.node-version`** or add a check that they don't disagree (fixes part of D9).
- Adopt shared `security.yml@v1` to retire the inline `security-scan.yml` (D10).

### 5.5 cypherid-web-infra
- Already strong. **Pin `tflint_version`** in the shared `security.yml` reusable (fixes D8, benefits all callers).
- Optional: converge its richer `terraform_ci.yml` onto the shared `terraform-ci.yml@v1` where function isn't lost (CI-SSOT-DESIGN keeps this as an allowed exception).

### 5.6 seqtoid-graphql-federation-server
- Being decommissioned by the federation collapse -- **no version-SSOT investment** beyond leaving it consistent. Add `engines` only if it lives long enough to matter (low priority; fixes remainder of D9).

### 5.7 cztack (vendored module library)
- Loose per-module floors are correct for a reusable library. **No change**; keep Dependabot.

---

## 6. Decision points for Tom

1. **Registry model:** Option A (documented table + harness drift-check) now, Option B (machine-readable
   `platform-versions.yaml`) only if drift recurs? (Recommend A.)
2. **Python fleet target:** pick the canonical app/lambda Python minor and the allowed exceptions
   (workflow-infra 3.9/3.8 lambdas). What is the floor?
3. **AWS provider convergence (D4):** schedule workflow-infra `4.54 -> 5.x`, or ratify the lag?
4. **CI-tool SSOT adoption (D10):** approve retiring the four inline `security.yml` copies in favour of
   `@v1`, or keep any deliberately inline? (This is already the approved CI-SSOT-DESIGN direction --
   this doc just quantifies the remaining ~60%.)
5. **Sequencing:** most workflow-infra fixes ride behind its OpenTofu->Terraform conversion; confirm
   they should be batched with it rather than done standalone.

*None of the above is applied. All fixes are per-repo PRs to be authored and gated per the standing
dev-only / staging-prod-gated envelope.*
