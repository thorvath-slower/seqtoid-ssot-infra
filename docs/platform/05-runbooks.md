# 05 — Runbooks

Copy-paste procedures for the common maintenance tasks. Every one assumes you've read [02 — Working conventions](02-working-conventions.md) (forks only, small PRs, validate-before-merge).

Common preamble for any repo change:
```bash
cd <repo>
git fetch && git checkout origin/main -b czid-NNN-short-slug
# … make the change …
git commit --no-verify -m "CZID-NNN: <imperative> "   # body: what/why/validation
git push -u origin czid-NNN-short-slug                 # to the thorvath-slower fork
gh pr create --repo thorvath-slower/<repo> --base main --head czid-NNN-short-slug
# confirm `gh pr checks` all green, then:
gh pr merge <n> --squash --delete-branch
git checkout main && git reset --hard origin/main
```

---

## Bump the Terraform version
1. Edit `.terraform-version` (e.g. `1.12.1` → `1.13.0`) in the repo.
2. Regenerate the provider lockfile (next runbook) — provider constraints may resolve differently.
3. `terraform init && terraform validate` locally; the CI `terraform fmt + validate` gate confirms it.
4. Repeat per IaC repo (each has its own `.terraform-version`). Nothing else hardcodes the version — `setup-terraform@v2` reads the file.

## Regenerate a provider lockfile
```bash
cd <stack-or-repo-root>
# (workflow-infra: run codegen first) make package-lambdas
terraform providers lock \
  -platform=linux_amd64 \   # CI runner
  -platform=darwin_amd64    # add darwin_arm64 / linux_arm64 only if every provider has that build
git add .terraform.lock.hcl
# verify it's stable:
terraform init -input=false      # must report "no need for changes"
```
Commit the lockfile. Confirm CI no longer reports lockfile drift.

## Bump a GitHub Action across repos (Node-runtime / version)
1. **Find every instance:** `grep -rn "uses: <owner>/<action>@" */.github/workflows/`.
2. **Check the target runtime:** read the new version's `action.yml` `runs.using` (must be `node24`, `composite`, or `docker` — not node16/20). Fetch it from the action's repo at the tag.
3. **One PR per repo** (single concern): bump `@old` → `@new` at every call site in that repo. Keep the pin identical across call sites (SSOT).
4. Leave any version file (e.g. `terraform_version`) untouched — only the action ref changes.
5. Validate: the repo's gate re-runs; confirm the deprecation annotation is gone.
- *Worked example:* `hashicorp/setup-terraform@v1` (node16/20) → `@v2` (node24) across the 3 IaC repos (CZID-199).

## Refresh an EOL base image (Docker)
1. Find the current pin: `grep -rn "^FROM" <repo>/**/Dockerfile`.
2. Pick the current image + **digest-pin** it: `image:tag@sha256:…` (CZID-4). Remember Docker Hub `jupyter/*` is frozen → use `quay.io/jupyter/*`.
3. Expect base-OS/Python jumps to break old pins — **fix forward** (bump the broken deps), don't pin the base back. Common breakers on a newer base:
   - apt: 24.04 uses the deb822 sources layout (`/etc/apt/sources.list` may not exist).
   - Python 3.13 removed the stdlib `cgi` module (breaks old `boto3`/`botocore`); old C-extensions (`markupsafe==2.0.1`) won't build.
4. **Build + smoke-test locally:**
   ```bash
   cd seqtoid-workflows
   make build WORKFLOW=<name>
   docker run --rm czid-<name> bash -lc "python --version; python -c 'import <pkg>'"
   ```
5. Production-pipeline images additionally need the **WDL benchmarks** (Bucket B) to confirm tool-output parity before merge; analysis/harness images can merge on local build-green. (CZID-44 + children.)

## Add / upgrade an application dependency
- **Python (workflows):** edit `requirements*.txt` / a package's `setup.py`; rebuild the image; `bin/ci-local <workflow>`.
- **Ruby (seqtoid-web):** edit `Gemfile`, `bundle install`, commit `Gemfile.lock`; `make ci-local`.
- **npm (seqtoid-web frontend):** `npm ci` (lock-respecting) **then** `npm install <dep>` so you don't float the whole tree; commit `package-lock.json`; validate `npx tsc -p ./app/assets/tsconfig.json --noemit`.
- If a dep needs a newer runtime, **bump the version file forward** (`.node-version` etc.), don't pin the dep back. File a ticket for the toolchain bump if it's separable.

## Bring a third-party action in-house
> Use this when an upstream action is unmaintained on an EOL runtime but we want to keep it.
```bash
# 1. standalone PRIVATE repo (NOT gh repo fork)
gh repo create thorvath-slower/<action> --private
git clone https://github.com/<upstream>/<action>.git && cd <action>
git remote set-url origin https://github.com/thorvath-slower/<action>.git

# 2. modernize (e.g. action.yml runs.using: node16 -> node24), commit

# 3. push history + create the SSOT moving tag
git push origin HEAD:main
git tag -f v2 && git push -f origin v2      # the single-source moving tag

# 4. allow other thorvath-slower repos to use the private action
gh api -X PUT /repos/thorvath-slower/<action>/actions/permissions/access -f access_level=user

# 5. repoint consumers to @v2 (one PR per consuming repo)
```
**Never** `gh repo fork` (creates a public fork linked to the upstream). Scrub any leaked `gh` token from `.git/config` afterward.

## Triage a security finding (Trivy / Brakeman / Checkov)
1. Reproduce + confirm it's real (not a false positive / already-mitigated).
2. **Fix forward** if you can (bump/patch). If it's a justified non-issue, add a scoped, *commented* suppression (`checkov:skip=…:reason`, brakeman ignore) explaining *why* — never a blanket ignore.
3. If the fix mutates a live resource (e.g. KMS key policy on a live bucket), it's apply-gated (**Bucket B**) — author + validate now, hold the merge, label `bucket-b`, link CZID-167.
4. Document root cause + fix on the ticket; close.
