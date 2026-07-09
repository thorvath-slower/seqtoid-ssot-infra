# cztack vendoring direction -- local per-repo vs SSOT (CZID-424)

**Status:** DECISION doc -- options + recommendation for Tom. No code/config change.
**Scope:** where the vendored `chanzuckerberg/cztack` Terraform modules live and which
copy consumers actually source.
**Related:** CZID-403 (eliminate the cztack repo dep by vendoring), CZID-404 (trim the
vendored set), CZID-140 (version SSOT), CZID-322 (EKS endpoint param), the infra-SSOT
principle, the in-house cztack fork (`thorvath-slower/cztack`, tag `v0.104.2-seqtoid.1`).

---

## 1. TL;DR

We vendor cztack **two ways at once** today:

- **(a) Per-repo local copies** under `cypherid-web-infra/terraform/modules/aws-*-v<ver>`
  -- this is what stacks **actually source and deploy** (LIVE).
- **(b) A single SSOT copy** at `seqtoid-ssot-infra/modules/cztack/` -- trimmed to the
  consumed set (26 modules, PR #40) but with **zero direct consumers**; nothing sources it.

This is duplication with no consumer on the SSOT side, and we have **already been bitten
by drift** between the two copies. The recommendation is **Option A: keep per-repo local
vendoring as the source of truth and retire the SSOT `modules/cztack/` staging copy** (or
demote it to an explicitly-labelled non-consumed reference), because the cross-repo
sourcing that would justify (b) hits the same private-repo CI git-auth wall that CZID-403
was created to remove. The decision is Tom's.

---

## 2. How we got here

- Originally consumers referenced `github.com/chanzuckerberg/cztack//<module>?ref=...`
  directly -- an external public-repo supply-chain dependency.
- **CZID-403** removed that upstream dep by vendoring the used modules **in-tree**. The
  ticket's original framing was "vendor into `seqtoid-ssot-infra`" (one SSOT copy), but
  the decision landed on **local per-repo vendoring** because a cross-repo module ref into
  `seqtoid-ssot-infra` (a **private** repo) would still be a remote private fetch in CI --
  the exact git-auth wall we were trying to remove -- and local matches web-infra's
  existing `terraform/modules/<name>-v<ver>` pattern.
- **CZID-404** then trimmed the SSOT copy from 60 modules down to the 26 legitimately
  consumed (PR #40).
- **CZID-322 / PR #37** had to *separately* add the `endpoint_public_access*` parameter to
  the SSOT `aws-eks-cluster` copy to bring it to parity with web-infra's copy -- i.e. **we
  hit real drift**: the fork feature existed in the live web-infra copy but not in the
  SSOT copy until PR #37 back-filled it.

### Verified current state (origin/main, 2026-07-09)

| Fact | Value |
|---|---|
| SSOT copy path | `seqtoid-ssot-infra/modules/cztack/` |
| SSOT copy module count | **26** (post-#404 trim) |
| SSOT copy direct consumers | **0** (`grep` for `modules/cztack` / `seqtoid-ssot-infra` in any `*.tf` source ref = empty) |
| Live per-repo copies | `cypherid-web-infra/terraform/modules/aws-*-v0.104.2` (+ older `v0.41.0` x29, `v0.43.1`, `v0.26.1`, `v0.91.1`, `v0.73.0`, `v0.60.0`) |
| How stacks source them | relative path, e.g. `source = "../../../modules/aws-eks-cluster-v0.104.2" # cztack v0.104.2-seqtoid.1` |
| Live upstream refs remaining | none -- no `github.com/chanzuckerberg/cztack` refs in any stack `*.tf` |
| Drift already observed | CZID-322 `endpoint_public_access` present in web-infra copy, absent from SSOT copy until PR #37 |

The SSOT copy is, functionally, a **staging/reference copy that nothing deploys**.

---

## 3. Options

### Option A -- Keep per-repo local vendoring; RETIRE the SSOT staging copy (RECOMMENDED)

Per-repo local copies remain the single source of truth (they are what deploys). Delete
(or clearly demote to "reference only, not sourced") `seqtoid-ssot-infra/modules/cztack/`.

- **Pros**
  - Removes the duplicate-with-no-consumer -- one copy per repo, and that copy is the one
    that ships. No "which copy is real?" ambiguity.
  - Kills the drift class we already hit (CZID-322): there is no second copy to fall out of
    sync, so no recurring parity back-fill (PR #37) work.
  - No cross-repo/CI git-auth machinery -- keeps the CZID-403 win intact (private repo, but
    modules resolve from local paths, never a remote private fetch).
  - Matches web-infra's long-standing `modules/<name>-v<ver>` convention; lowest surprise.
- **Cons**
  - If a *second* repo (e.g. `cypherid-workflow-infra`) later needs the same cztack module,
    it vendors its own local copy -- genuine N-way duplication returns. (Today web-infra is
    effectively the only cztack consumer, so N=1 and this cost is theoretical.)
  - Loses the "single upgrade point" aspiration -- a cztack bump is applied per repo.
  - The SSOT repo no longer holds a browsable canonical cztack set (mitigated: the in-house
    fork `thorvath-slower/cztack` already is that canonical source at a tag).

### Option B -- Repoint all consumers to the SSOT copy; drop per-repo copies

Make `seqtoid-ssot-infra/modules/cztack/` the one true copy and have every stack source it.

- **Pros**
  - True DRY: one copy, one upgrade point, one place to review a cztack change.
  - Realizes the original CZID-403/infra-SSOT aspiration.
- **Cons**
  - **Reintroduces the exact wall CZID-403 removed.** `seqtoid-ssot-infra` is a **private**
    repo; a cross-repo Terraform module `source` into it is either:
    - a **remote git source** (`git::https://github.com/thorvath-slower/seqtoid-ssot-infra//modules/cztack/...`)
      -- needs git credentials in every CI job and every `terraform init`/apply context =
      the private-fetch auth wall, now on the critical deploy path; or
    - a **git submodule / sync step** in each consumer repo -- extra machinery, submodule
      pointer churn, and a two-step "bump SSOT then bump the pointer" workflow.
  - Couples every consumer to the SSOT repo's **release cadence** -- an SSOT change can ripple
    into unrelated stacks' plans.
  - Higher blast radius: one edit in SSOT touches every environment at once.

### Option C -- Keep both, with a defined sync process

Keep the SSOT copy as canonical *reference* and the per-repo copies as the deployed copies,
with a scripted/CI check that keeps them byte-identical.

- **Pros**
  - Preserves a single browsable canonical set **and** local-path resolution (no CI
    git-auth wall on the deploy path).
  - A drift check (CI diff SSOT vs each per-repo copy) turns silent drift into a loud gate.
- **Cons**
  - **Still two copies to maintain** -- the duplication cost stays; we just automate policing
    it. This is the status quo *plus* a maintenance job.
  - The sync tooling is itself something to build, own, and debug; PR #37 shows manual sync
    is error-prone, and an automated sync is only as good as its coverage.
  - Ambiguity persists ("edit which copy first?") unless the sync direction is strictly
    one-way and enforced.

---

## 4. Recommendation

**Adopt Option A: per-repo local vendoring is the source of truth; retire the SSOT
`modules/cztack/` staging copy** (delete it, or demote it to a clearly-labelled
non-sourced reference and stop trimming/parity-patching it).

Rationale:

1. The SSOT copy has **no consumers** and never has -- it is pure duplication today, and the
   only maintenance it has generated is **drift cleanup** (CZID-404 trim, CZID-322/PR #37
   parity). Removing it removes that recurring cost outright.
2. Option B's DRY benefit is real but is **paid for with the private-repo CI git-auth wall
   that CZID-403 deliberately removed**, now placed on the live deploy path. That is a
   strictly worse trade than the duplication it saves, especially while cztack has
   effectively one consumer.
3. Option C keeps the duplication and adds tooling to babysit it -- more moving parts for a
   problem Option A deletes.
4. If we ever genuinely need a shared canonical cztack across multiple repos, the
   **in-house fork `thorvath-slower/cztack` (tag `v0.104.2-seqtoid.1`) already is that
   canonical source**; consumers can re-vendor from it at a tag. The SSOT in-tree copy adds
   nothing the tagged fork does not already provide.

### Re-vendor workflow under Option A (unchanged from today)

To update cztack in a consumer: re-vendor the needed module(s) from the in-house fork at a
new tag into that repo's `terraform/modules/<name>-v<ver>/`, bump the stack `source`
comment (`# cztack v<tag>`), plan-review, and apply. One repo, one PR, local-path resolution
-- no remote private fetch.

---

## 5. The decision Tom needs to make

1. **A, B, or C?** (Recommendation: A.)
2. If **A**: **delete** `seqtoid-ssot-infra/modules/cztack/` outright, or **keep it as a
   labelled "reference, not sourced" copy** (and if kept, do we stop spending parity/trim
   effort on it -- i.e. accept it may drift, since nothing deploys it)?
3. Confirm the **in-house fork `thorvath-slower/cztack@v0.104.2-seqtoid.1`** is the accepted
   canonical origin for any future re-vendor (so we are not left with *no* single source
   after retiring the SSOT copy).

No code or config is changed by this doc; the follow-up (retire/relabel) is a separate,
gated PR once Tom decides.
