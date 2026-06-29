# 04 — Dependencies & Version Management

This is the heart of "how we maintain the platform." Almost every maintenance task is *some* version moving. The rules below make those moves safe and consistent.

## The SSOT principle
> **Every tool/runtime version is pinned exactly once, in a version file. CI reads the file — it never hardcodes the version.**

| Toolchain | SSOT file | Read by |
|---|---|---|
| Terraform | `.terraform-version` (1.12.1) | `setup-terraform@v2` (`terraform_version`) |
| Node.js | `.node-version` (20.20.2) | `setup-node` (`node-version-file`), Dockerfiles, `bin/setup-ci` |
| Ruby | `.ruby-version` (3.3.6) | `setup-ruby`, Docker base |
| Python | `.python-version` (3.10) | `setup-python` (`python-version-file`) |
| Providers (Terraform) | `_shared/versions.tf` + committed `.terraform.lock.hcl` | `terraform init` |
| App deps | `Gemfile.lock`, `package-lock.json`, `requirements*.txt` | bundler / npm / pip |

**Why it matters:** a version hardcoded in a workflow (e.g. `node-version: 20`) silently drifts from `.node-version` and breaks the SSOT. If you find one, point it back at the file. (Several of these were fixed in the SSOT sweep — CZID-140 and children.)

## Lockfiles are committed
- Commit `.terraform.lock.hcl`, `Gemfile.lock`, `package-lock.json`. They make builds reproducible and stop a bad transitive release slipping in.
- CI installs from the lock (`terraform init` without `-upgrade`, `npm ci`, `bundle install --frozen`), never re-resolving.
- To add ONE npm dep without floating the whole tree: `npm ci` first (lock-respecting), then `npm install <dep>`.

## Container images are digest-pinned
- Base images are pinned by **digest** (`image:tag@sha256:…`), not just a tag, so the build is reproducible and the tag can't be re-pointed under us (CZID-4).
- Note: **Docker Hub `jupyter/*` images are frozen** (since 2023-10) — current Jupyter images live at `quay.io/jupyter/*`. The same "tag moved/froze upstream" risk is why a single internal dependency source is being explored (CZID-205).

## GitHub Action versions
- **Keep actions on the Node-24 runtime.** GitHub removes the Node-20 runtime from runners on **2026-09-16**; node16/node20 actions break after that (CZID-89). Check an action's runtime by reading its `action.yml` `runs.using` at the pinned ref.
- **Composite / Docker actions are unaffected** by the Node-runtime deprecation (they have no Node entrypoint).
- When an upstream action is unmaintained on an old runtime, **bring it in-house**: a standalone **private** repo under `thorvath-slower` (never `gh repo fork`), modernize it there, and pin consumers to it. Example: `julianwachholz/flake8-action` (node16) → `thorvath-slower/flake8-action` (node24).
  - **SSOT for an in-house action:** a single **moving major tag** (e.g. `@v2`) in our action repo is the single source of truth. Every consumer references `@v2`; to roll out a new version, move that one tag and all consumers pick it up. (Alternative: SHA-pin + Renovate to bump in lockstep — more strict, needs Renovate.)

## Renovate
- Renovate (CZID-8) is the automation that keeps in-range dependency + action versions current by opening PRs. It is the management layer that keeps the SSOT files / lockfiles from going stale.
- Where Renovate isn't enabled yet, version currency is a manual sweep (e.g. the deadline-driven Node-runtime sweep, CZID-89).

## The cardinal rule: never downgrade — pull forward
- If a dependency conflicts, **do not pin it backward** to make the conflict go away.
- **Bump the toolchain forward** (e.g. Node 20.18 → 20.20 to satisfy an `engine-strict` dep), and file a ticket for any follow-on. Keep the forward fix as its own PR.
- Old pins that block modern runtimes get *fixed forward*, not frozen: e.g. `markupsafe==2.0.1`/`boto3~=1.23.0` don't run on Python 3.13, so they're bumped, not the base pinned back (CZID-203).

## Where the gotchas live (seqtoid-web frontend)
- `.npmrc` has `engine-strict = true` — a frontend dep that needs a newer Node is **blocked** until `.node-version` moves forward (don't pin the dep back).
- The fork's CI is **Ruby-centric and does not run the frontend type-check**. Validate frontend changes locally: `npx tsc -p ./app/assets/tsconfig.json --noemit` in `node:$(cat .node-version)`.
- `npm install` re-resolves the whole legacy tree — use the `npm ci` then `npm install <dep>` trick above.

See [05 — Runbooks](05-runbooks.md) for the concrete step-by-step of each upgrade.
