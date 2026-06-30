# 02 — Working Conventions

**Read this before making any change.** These conventions are non-negotiable; they keep the work safe, traceable, and reviewable.

## 1. Governance: where work goes
- **All work happens on `thorvath-slower/*` forks.** Push branches and open PRs there only.
- **Never push or PR to an upstream** — not `jsims-slower`, `chanzuckerberg`, `IT-Academic-Research-Services`, or any third party. The fork's `upstream` remote (e.g. `jsims-slower`) is fetch-reference only.
- Nothing reaches the customer/upstream without a deliberate, separately-approved step.
- When you need an in-house copy of a **third-party** dependency or GitHub Action, create a **standalone private repo** under `thorvath-slower` with `gh repo create --private` — **never `gh repo fork`** (a fork is public and linked to the upstream). See [05 — Runbooks](05-runbooks.md#bring-a-third-party-action-in-house).

## 2. Small, single-concern PRs
- **One ticket → one branch → one PR.** If a change needs an "and also", split it into separate PRs.
- Branch name: `czid-NNN-short-slug`. Commit subject: `CZID-NNN: <imperative summary>`.
- Commit body = **what / why / validation**. No "Generated with…" / `Co-Authored-By` trailers — all work is authored as the engineer.
- A PR description is **What / Why / Validation**, with links to the related `CZID-NNN` tickets (full URLs).

## 3. The Linear lifecycle (do all four, in order)
1. **On start:** set the ticket to **In Progress**.
2. Do the work → open the PR → get CI green → merge.
3. **Comment the outcome on the ticket**: root cause + PR link + validation. The ticket is the durable record, not just the PR.
4. **Then** set the ticket to **Done**. Order matters: comment *before* Done.
- Found something out of scope? **File a new ticket** (root cause + fix + validation, link related) — don't bundle it into the current change.

## 4. Validate before you merge
- **Validate locally first** (see [06 — Local validation](06-local-validation.md)). CI is the final gate, not the dev loop.
- Before merging, read the **full** `gh pr checks` output and confirm **every required gate is `pass`**.
  - The line that shows `fail … Ns` is usually the **cancelled `push` run** — ignore it; the real gate is the longer `pull_request` run.
  - For IaC repos the gate is `terraform fmt + validate` (czid-infra also runs `tflint`/`gitleaks`/`trivy`).
- Merge with `gh pr merge <n> --squash --delete-branch`, then resync local `main` (`git fetch && git reset --hard origin/main`).

## 5. Never downgrade — pull forward
- Never pin a dependency *backward* to dodge a version conflict. **Bump the toolchain forward** (e.g. Node), and file a ticket for any follow-on. Keep forward fixes as separate PRs.

## Bucket A vs Bucket B
- **Bucket A** — doable in this dev environment: authoring code/IaC, `terraform validate` + checkov/trivy/tflint, local Docker builds, unit/integration tests, documentation.
- **Bucket B** — needs live AWS / admin / credentials: `terraform apply` against real accounts, live data cutovers, creating AWS/GitHub/Auth0 admin resources, anything that mutates production resources with consumers.
- **A change can be authored in Bucket A but only safely *merged* in Bucket B** if applying it could break live resources (e.g. adding SSE-KMS to a live bucket). When that's the case, label the ticket `bucket-b`, link the blocked-work tracker (CZID-167), and hold the merge for apply access. Say so explicitly on the ticket.

## Concurrent-agent hazard
Multiple people/agents may share these local clones. **Before any write:** `git fetch && git status`, and reset to a fresh `origin/main` before branching. Verify state after operations rather than assuming.

## Git credential note
If a local `git push`/`fetch` fails with `could not read Username … Device not configured`, the credential helper hiccupped. Work around it with the `gh` token inline:
```bash
git push https://x-access-token:$(gh auth token)@github.com/thorvath-slower/<repo>.git <branch>
```
…then **scrub the token** afterward: `git remote set-url origin https://github.com/thorvath-slower/<repo>.git` (the token otherwise persists in plaintext in `.git/config`).
