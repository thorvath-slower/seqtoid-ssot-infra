# Branching & Deploy Model

The single source of truth for how code moves from a developer's branch to a running
environment on the seqtoid platform: the branch topology, the merge/promotion flow, the
required checks, and the deploy best-practices the GitHub config + GitOps CD are built on.

> **Scope.** This applies to the **`thorvath-slower/*` forks** we own and deploy. It does
> **not** apply to the upstreams (`jsims-slower`, `IT-Academic-Research-Services`,
> `chanzuckerberg`) — we never push branch-protection or merges there. See
> [02 — Working conventions](02-working-conventions.md).
>
> **Status.** The branch topology and gates below are the agreed model. The
> `integration → main` release path and the staging/prod deploy legs are **gated OFF**
> until the team sign-off + AWS bootstrap land (called out inline). Nothing here documents
> aspirational state as if it were live.

---

## 1. Branch topology

```
feature (czid-NNN-<slug>)  ──PR──▶  integration  ──release PR──▶  main
     (cut from integration)          (aggregation + staging line)   (protected release trunk)
```

- **`main`** — the **protected release trunk**. Only clean, reviewed, fully-green code.
  Nothing merges here except a deliberate **release PR** from `integration`. Maps to the
  **prod** image lineage. **HELD** until the team sign-off; then release PRs only.
- **`integration`** — the **aggregation + staging line**. All day-to-day work lands here
  via gated PRs. Maps to the **dev / staging** image lineage. This is where the
  parallel-agent PRs merge.
- **feature branches** — `czid-<ticket>-<slug>`, **cut from `integration`** (never from
  `main`, which is the divergence-conflict class we are killing). One concern per branch.

**Divergence rule.** `integration` and `main` must not be allowed to drift far apart. After
the first `integration → main` release, keep them reconciled: every release PR brings `main`
up to `integration`, and hotfixes flow straight back (§2).

## 2. Merge flow + gates

| Transition | Gate |
|---|---|
| feature → **integration** | Gated PR: **all required checks green** + **commit author = `Thomas Horvath <thomash@slower.ai>`** (verified) + no unresolved conversations. Squash or merge-commit; **no direct pushes**. |
| integration → **main** (release) | Release PR: full suite green + **author-email normalization at the boundary** (rewrite any non-`slower.ai` Tom commit → `Thomas Horvath <thomash@slower.ai>`; preserve colleagues/upstream authors) + Tom's explicit approval. `main` must only ever show `thomash@slower.ai` for our work. |
| hotfix | Branch off `main`, PR → `main` (fast-track), then **immediately back-merge** `main` → `integration` so they don't diverge. |

**Author-email is a merge gate, not an afterthought.** Verify `gh pr view <n> --json commits`
before every merge — automated/subagent environments can inject the wrong email, and `main`
carries a clean-identity invariant.

## 3. Branch protection (GitHub)

**Applied (pass 1):** on `main` + `integration` of every owned repo — require a PR to merge,
**no force-push, no deletion**, admins may bypass.

**Pass 2 (after this doc's sign-off + confirming each check is universal):** add
**required status checks**. Only checks that run on **every** PR qualify — path-filtered
gates (`wdl-ci`, `terraform-ci`, `validate-stacks`) would wrongly block unrelated PRs, and
OIDC-dependent build jobs cannot pass until the OIDC bootstrap lands. Proposed universal set:

| Repo | Required checks (universal) |
|---|---|
| seqtoid-web | `Ruby Test (MySQL 8)`, `rubocop`, `brakeman`, `Secret scan (gitleaks)` |
| cypherid-web-infra | `security / checkov`, `security / tflint`, `security / trivy`, `security / gitleaks` |
| cypherid-workflow-infra | `security / checkov`, `security / tflint`, `security / trivy`, `security / gitleaks`, `actionlint` |
| seqtoid-workflows | `security / checkov`, `security / trivy`, `security / gitleaks` |
| seqtoid-ssot-infra | `security / *` (gitleaks/trivy/tflint) + `terraform-ci` once universal |

- **`strict: false`** (don't force branch-up-to-date) — avoids the rebase treadmill;
  velocity over strictness on the active line.
- **Required approvals: 0** for now (solo/small team — Tom is the approver by role; GitHub
  blocks self-approval, so requiring 1 would deadlock). Revisit as the team grows.
- Path-filtered + OIDC-gated checks (`wdl-ci`, `terraform-ci`, image builds) stay
  **non-required** until OIDC is bootstrapped; then promote the reliable ones to required.

## 4. Environment promotion (the deploy path)

```
build (main push) ──▶ ECR image sha-<commit> ──▶ dev ──▶ staging ──▶ prod
       (Trivy + Cosign)     GitOps image.tag advance     (blue/green, Argo Rollouts)
```

- **dev** — `gitops-advance-dev.yml` bumps `image.tag` on a green build → Argo CD syncs →
  Argo Rollouts auto-promotes on smoke pass (`blueGreen.autoPromotionEnabled: true`).
- **staging** — `gitops-promote.yml` (dev → staging) → auto-promote on smoke pass.
- **prod** — `gitops-promote.yml` (staging → prod) → the Rollout **pauses** for a manual
  `kubectl argo rollouts promote` (`autoPromotionEnabled: false`). **Gated OFF** until
  validated — no staging/prod deploys yet.
- **Promote the tested digest, never rebuild between envs** — the exact image that passed
  dev/staging is what reaches prod.
- Deploys are **Git-driven** (move an `image.tag` pointer), never a manual `kubectl apply`.
  The legacy ECS/czecs path is retired once this is proven.

> The chart lives in `seqtoid-web/deploy/charts/seqtoid-web`; per-env values live in
> `cypherid-web-infra/deploy/argocd/values/seqtoid-web/<env>.yaml`, layered on by the Argo
> CD multi-source Application. See [08 — Architecture & SSOT](08-architecture-and-ssot.md).

## 5. Deploy best practices (the rules)

1. **Everything through gated PRs** — no direct pushes to `main` / `integration`.
2. **Branch off `integration`**, not `main` (kills the divergence-conflict class).
3. **Verify author-email + CI green before every merge** (both are hard gates).
4. **Digest-based promotion** — build once, promote the same artifact; no per-env rebuilds.
5. **Prod is always manually gated** (Argo Rollouts pause) + health-gated auto-abort/rollback.
6. **OIDC-only auth** to AWS (no static keys); scoped per env, split plan/apply.
7. **`main` clean-identity invariant** — only `thomash@slower.ai` for our work; normalize
   at the boundary.
8. **Reversible-first** — force-push / history-rewrite only deliberately, never on shared
   branches without lifting protection + an explicit go.

## 6. Runbook — the common flows

**Start a piece of work**
```sh
git fetch origin
git switch -c czid-<ticket>-<slug> origin/integration   # always off integration
# ... commit as Thomas Horvath <thomash@slower.ai> ...
git push -u origin czid-<ticket>-<slug>
gh pr create --base integration --repo thorvath-slower/<repo>
```

**Merge to integration** — confirm the full `gh pr checks <n>` set is green (read the
untruncated list — some gates hard-fail and are not summarised by `--watch`), confirm
`gh pr view <n> --json commits` shows only `thomash@slower.ai` for our commits, then merge.

**Cut a release (integration → main)** — *held until sign-off.* Open the release PR, run
the author-email normalization at the boundary, get Tom's explicit approval, merge, then
tag the prod image lineage.

**Hotfix** — branch off `main`, PR → `main`, merge fast-track, then **immediately**
`git switch integration && git merge main` (or a back-merge PR) so the lines stay reconciled.

## 7. Open decisions (for sign-off)

- Sign off on the **required-checks set** (§3) before pass-2 branch protection is applied.
- **First `integration → main` release**: when the hold lifts, run the release PR + the
  boundary email normalization.
- **`main` ↔ `integration` reconciliation**: fold into the first release, or a dedicated
  reconciliation pass first.
