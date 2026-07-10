# Test Strategy & Suite Design -- Per Repo (CZID-153)

Status: analysis / strategy doc. DECISIONS (coverage targets, what to gate) are Tom's; nothing here
changes code, config, or CI. Scan date 2026-07-09.

Purpose: for each repo, document (a) the test layers that exist **today**, (b) the **intended** test
pyramid for that repo's needs, (c) **coverage targets**, (d) **CI gating**, and (e) the **gaps** to
close. This extends the workspace precursor `QUALITY-GATES-AND-TEST-STRATEGY-2026-06-27.md` with a
per-repo, ground-truth scan.

Repos in scope: `seqtoid-web`, `seqtoid-workflows`, `cypherid-web-infra`, `seqtoid-ssot-infra`,
`cypherid-workflow-infra`.

Related work: #158 (seqtoid-web test strategy), #160 (workflows test strategy --
`TICKET-160-WORKFLOWS-TEST-STRATEGY.md`), #161 (IaC checkov ratchet), coverage-gap analyses
`COVERAGE-GAP-ANALYSIS-2026-07-07.md` (Ruby) + `-JEST-2026-07-07.md` (frontend).

---

## 0. Platform-wide posture (the shared gates)

These gates are uniform across the infra + workflow repos via `seqtoid-ci-workflows@v1` and are the
*floor* every repo inherits:

| Gate | Mechanism | State |
|---|---|---|
| Secret scanning | gitleaks (full history, hard-fail) | live where `@v1` adopted |
| Dependency/IaC/Dockerfile vuln + misconfig | trivy (HIGH/CRIT hard-fail, `.trivyignore` baseline) | live |
| IaC fmt + validate + lockfile | terraform `fmt -check` + `validate` | live on infra repos |
| Deep IaC policy | checkov | **opt-in, `soft_fail: true`, not gating** (#161) |
| Local == CI parity | `make check` per repo | present |

The *depth* work (below) is what remains: contract tests, benchmark gating, coverage targets,
de-flaking, and turning checkov into a hard gate.

**The standard pyramid we grade each repo against:**

```
        e2e / integration      (few, slow, high-signal: real flows end-to-end)
      request / API / contract  (medium: HTTP + schema surfaces the frontend depends on)
   unit (models/services/utils) (many, fast: pure logic)
static: lint + type + IaC-validate + security (fastest, every PR)
```

For IaC repos the pyramid is compressed: static (fmt/validate/lint/security) is the base and the
bulk; "unit" = module/plan tests; "integration" = a real plan/apply in a throwaway env.

---

## 1. seqtoid-web (Rails app -- the product surface)

**Layers today**
- **Unit + request (RSpec):** ~289 `*_spec.rb` files, ~3,200+ examples, across
  `models/ services/ requests/ controllers/ graphql/ jobs/ lib/ integration/ views/ mailers/`.
  Mature, broad. Runs on MySQL 8 (`bin/ci-test` / `docker-compose.ci.yml`).
- **Frontend unit (Jest):** `testMatch **/*.test.{js,jsx,ts,tsx}`, honest whole-tree coverage.
- **e2e (Playwright):** ~89 `*.spec.ts` under `e2e/` with page-objects.
- **Static:** rubocop (+ AsciiComments), brakeman (`config/brakeman.ignore` baseline, #294),
  ESLint (+ a11y rules), `tsc` type-check, unused-package check.

**Coverage today (gate = ratchet floors, not targets)**
- Ruby SimpleCov: **line 61 / branch 46** floor (`.simplecov`, `enable_coverage :branch`). CI fails on regression.
- Jest: **lines 11 / branches 9 / functions 9 / statements 11** floor (honest whole-tree, re-measured 2026-07-08 after coverage waves #244-246). Deliberately just below actual so coverage can only rise.

**Intended pyramid**
- Keep RSpec as the strong unit+request base. Add a **GraphQL contract test** for the Rails-native
  `/graphql` schema -- post federation-collapse, `/graphql` *is* the contract with the frontend (#158).
- Playwright e2e stays thin and high-signal (critical journeys: upload -> pipeline -> report, auth/Auth0).
- Jest ratchets upward toward the frontend target.

**Coverage targets (standing goal, memory):** **90% line AND 90% branch on BOTH suites.** Current
Ruby ~86.8/69.6 (main, 2026-07-07); Jest ~11/9. The Ruby long-tail needs Pareto whale-hunting +
integration specs; the Jest gap is large and needs sustained waves (see the two gap-analysis docs).

**CI gating**
- PR gate lives in `pull-request-only.yml` (rubocop/reviewdog) + the RSpec/Jest/tsc jobs; `check.yml`
  is the manual full-check (`workflow_dispatch`). RSpec + Jest coverage floors are enforced.

**Gaps to close**
1. **Flakiness (CZID-151)** -- the historical blocker; de-flake before raising floors or the ratchet stalls.
2. **GraphQL contract test (#158)** -- lock the `/graphql` shape the frontend depends on.
3. **Coverage climb** -- Ruby branch (69.6 -> 90) and the whole Jest tree (11 -> 90) are the big lifts.
4. **e2e in CI** -- confirm Playwright runs as a gate (not just nightly `e2e-automation.yml` / `nightly-test-suite.yml`); decide PR-blocking vs nightly.

---

## 2. seqtoid-workflows (WDL bioinformatics pipelines -- correctness IS the product)

**Layers today**
- **WDL task/pipeline tests (miniwdl):** `wdl-ci.yml` + `wdl-ci-integration.yml` build the pipeline
  image, push to ECR, run miniwdl-driven tests. ~19 `.wdl`, ~59 test-related `.py`.
- **idseq-dag unit tests:** `idseq-dag-tests.yml` -> `run_idseq_dag_tests.sh` (pytest).
- **Rust unit tests:** `index-generation-cargo-test.yml` -> `cargo test` (ncbi-compress crate).
- **Benchmarks:** `short-read-mngs-full-benchmarks.yml` + `-viral-benchmarks.yml` -- real pipeline
  runs checking correctness (AUPR / deviation) = the true beta-readiness proof.
- **Static:** security CI (gitleaks/trivy) added (#4).

**Intended pyramid**
- Base: idseq-dag pytest + cargo unit tests (fast, per-PR).
- Middle: miniwdl **task-level** unit tests + per-pipeline integration (`wdl-ci`).
- Top: the benchmarks as a **gated correctness/perf suite** -- the highest-value layer because a
  numerically-wrong pipeline is a silent product failure (`benchmarks-are-the-AWS-e2e-validator`).

**Coverage targets**
- Coverage-% is the wrong metric here; the meaningful target is **benchmark correctness gates**
  (AUPR >= 0.98, deviation < 1%) plus green miniwdl task tests. Set those as the exit criteria, not a line-%.

**CI gating**
- `wdl-ci` / cargo / idseq-dag run in CI. **Benchmarks are triggered bare (`on: push` / manual), not a
  merge gate** -- their pass/fail doesn't block.

**Gaps to close**
1. **Gate the benchmarks (#160)** -- promote short-read-mngs/viral benchmarks from `on: push` to a
   correctness gate with explicit AUPR/deviation thresholds. Highest leverage.
2. **miniwdl task-level unit tests** -- most WDL tasks lack isolated tests; add per-task coverage.
3. **SSOT drift in `idseq-dag-tests.yml`** -- it hardcodes `python-version: "3.12"` vs repo
   `.python-version` 3.10 (see CZID-140 audit); reconcile so the test env matches the runtime.
4. **Digest-pin the pipeline base images** so benchmark/integration runs are reproducible.

---

## 3. cypherid-web-infra (Terraform -- the app's cloud footprint)

**Layers today**
- **Static/IaC:** `terraform_ci.yml` (fmt + validate + per-stack lockfile), `validate-stack.yml`
  (richer tiered validation, internal reusable), `argocd-ci.yml` (Argo manifest checks), `security.yml`
  (via `@v1`: gitleaks/trivy/tflint/checkov).
- Provider SSOT: `_shared/versions.tf` symlinked into every stack.
- No unit/integration test layer beyond validate.

**Intended pyramid (compressed for IaC)**
- Base (bulk): fmt + validate + lint + security on every PR. **Present and strong.**
- Middle: **checkov as a baselined hard-gate** (currently opt-in/report-only) + selective module/plan tests where logic is non-trivial (LB/IRSA/EKS wiring).
- Top: a real `plan` (and, gated, `apply`) against a throwaway/dev env -- partially covered by the deploy workflows + the platform-harness.

**Coverage targets**
- IaC "coverage" = **policy coverage**, not line-%. Target: **checkov gating with a committed baseline,
  hard-fail on NEW findings only** (inherited backlog accepted via `.checkov.baseline`, CZID-264 model).

**CI gating**
- fmt/validate/lockfile/security gate PRs today. checkov runs `soft_fail: true` (does not block).

**Gaps to close**
1. **Ratchet checkov opt-in -> baselined hard-gate (#161)** -- the single highest-leverage IaC add.
   Needs a `run_checkov` hard-fail + `baseline` input in the shared `security.yml` (backward-compatible),
   then flip callers. (Measured 2026-06-27: foundation 169 pass / 2 fail; the 2 are the EKS public-endpoint class.)
2. **Module/plan tests** for the non-trivial modules (terratest or `terraform test` where it fits).
3. **tflint version pin** (shared reusable passes `tflint_version: latest`).

---

## 4. seqtoid-ssot-infra (Terraform foundation + platform harness -- the SSOT repo)

**Layers today**
- **Static/IaC:** `terraform-ci.yml@v1` + `security.yml@v1` (adopts the shared reusables -- exemplar).
- **Platform harness (unique to this repo):** `platform-harness/run.sh` -- an **offline, no-AWS,
  multi-repo** validation gate with layers `preflight terraform checkov charts supplychain parity
  crossrepo` (+ optional `--with-app`). This is the closest thing the fleet has to an integration test
  of the *platform as a whole*.
- `infra/state-foundation` Terraform (bootstrap + foundation modules: eks/network/openbao/registries).

**Intended pyramid**
- Base: fmt/validate/security on every PR (present).
- Middle: the **platform-harness layers** are the integration tier -- they assert cross-repo parity and
  supply-chain/chart validity without AWS. This is the repo's differentiator; invest here.
- Top: `plan`-safety checks (`platform-harness/plan-safety.sh`) as the pre-apply gate.

**Coverage targets**
- Target: **`./run.sh` green is a required pre-merge/pre-deploy gate** for platform-affecting changes,
  and the `crossrepo` layer should assert the CZID-140 version-SSOT (catch drift automatically).

**CI gating**
- `security.yml` + `terraform-ci.yml` gate PRs. **Confirm the platform-harness itself runs in CI** (it
  is documented as a manual `./run.sh` pre-merge step) -- wiring it as a job is a gap.

**Gaps to close**
1. **Run the platform-harness in CI** (at least the offline layers) rather than relying on a manual `./run.sh`.
2. **Add a `crossrepo` version-drift check** (ties to CZID-140 Option A) so SSOT drift fails a PR.
3. **`state-foundation` module tests** -- the foundation (eks/network/openbao) has no unit/plan test;
   it also runs off-template `versions.tf` (see CZID-140 D5).

---

## 5. cypherid-workflow-infra (OpenTofu + Python lambdas -- the pipeline control plane)

**Layers today**
- **Static/IaC:** `validate.yml` (`terraform fmt`+`validate`), `plan_call.yml` / `plan_only.yml`,
  inline `security.yml`.
- **Python lambda unit tests EXIST but are NOT gated:** `test/test_utils.py`, `test/system_test.py`,
  `lambdas/taxon-indexing-eviction/test/test_*.py` (reporter/change-detection/task-mgmt/config/data).
  `check.yml` has the test step **commented out** (`# run: python3 -m unittest discover ...` -- "TODO:
  need to setup localstack") and the whole workflow is `on: workflow_dispatch` (not push/PR).
- flake8 lint runs -- but via the **old** `thorvath-slower/flake8-action@v2` (SSOT drift, CZID-140 D6).

**Intended pyramid**
- Base: fmt/validate/lint/security per PR (validate is present; **lint + security are not PR-gated
  because `check.yml` is manual-only**).
- Middle: the **existing Python lambda unit tests, actually run in CI** -- with LocalStack/moto for the
  AWS-touching ones. This is low-hanging fruit: the tests already exist, they just aren't wired.
- Top: `plan` against dev as the pre-apply gate (present via `plan_call`).

**Coverage targets**
- Target: **turn on the existing lambda unit tests as a required gate** and set a modest starting
  coverage floor for the `lambdas/*` Python (ratchet upward), matching the seqtoid-web ratchet model.

**CI gating -- the biggest gap in the fleet**
- `check.yml` is `on: workflow_dispatch` only, so **flake8 + (disabled) tests never run on a PR**. IaC
  `validate` does gate. Net: this repo has the weakest automated PR gating of the five.

**Gaps to close**
1. **Make `check.yml` run on push/PR** (not just manual) -- immediately gates flake8.
2. **Enable the commented-out lambda tests** with LocalStack/moto -- the tests already exist.
3. **Adopt the shared `security.yml@v1`** + repoint flake8 to `seqtoid-ci-workflows/flake8-action@v1` (CZID-140).
4. Sequence behind the OpenTofu->Terraform conversion where it overlaps.

---

## 6. Cross-repo summary + priorities

| Repo | Base (static) | Unit | Integration/contract | e2e | Coverage gate | Biggest gap |
|---|---|---|---|---|---|---|
| seqtoid-web | strong | strong (RSpec) | request specs; **no GraphQL contract** | Playwright (89) | ratchet 61/46 Ruby, 11/9 Jest | flakiness + coverage climb + contract test |
| seqtoid-workflows | security added | pytest + cargo | miniwdl `wdl-ci` | benchmarks (**not gated**) | correctness-based | gate the benchmarks |
| cypherid-web-infra | strong | -- | validate/plan | deploy flow | policy (checkov opt-in) | checkov ratchet to hard-gate |
| seqtoid-ssot-infra | strong (`@v1`) | -- | platform-harness | plan-safety | harness-green | run harness in CI + drift check |
| cypherid-workflow-infra | **manual-only** | lambda tests **disabled** | validate/plan | plan | none | wire tests + PR-gate `check.yml` |

**Recommended priority (Bucket A, all authorable, none need AWS)**
1. **Ratchet checkov to a baselined hard-gate on the infra repos (#161)** -- cheap once baselined, deep IaC policy. `czid-infra`/ssot-infra foundation is the ideal pilot (near-zero baseline).
2. **Gate the workflow benchmarks (#160)** -- pipeline correctness is the product; make AUPR/deviation block.
3. **Wire cypherid-workflow-infra's existing lambda tests + PR-gate its `check.yml`** -- highest ratio of value to effort (tests already written).
4. **Rails GraphQL contract test (#158)** -- lock the post-collapse `/graphql` surface.
5. **Define + start ratcheting coverage targets** per repo (90/90 for seqtoid-web; correctness gates for workflows; policy baselines for IaC) -- makes every gate meaningful.

---

## 7. Decision points for Tom

1. **seqtoid-web coverage:** ratify 90/90 line+branch on both suites as the target, and the ratchet
   cadence to get there (accepting it's a multi-wave climb, esp. Jest 11 -> 90).
2. **Playwright gating:** PR-blocking or nightly-only? (Currently nightly.)
3. **Workflows:** approve promoting the benchmarks to a merge gate and the AUPR/deviation thresholds.
4. **IaC:** approve the checkov ratchet (opt-in -> baselined hard-fail-on-NEW) and which repo pilots.
5. **workflow-infra:** approve flipping `check.yml` to push/PR and standing up LocalStack/moto for the
   lambda tests -- and whether that batches with the OpenTofu->Terraform conversion.
6. **Formal regression plan (SMP-684/685):** this per-repo strategy is the input; confirm whether a
   single fleet-level regression plan doc + an executed pass against a deployed env (#390) is the next deliverable.

*Nothing here is applied. Each gap becomes its own gated PR under the standing dev-only /
staging-prod-gated envelope.*
