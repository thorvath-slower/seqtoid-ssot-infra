# Security Scanning — Usage Guide

How the CZ ID stack's automated security gates work, how to run them locally,
and how to triage what they find. Introduced in `improvement-#010`.

- **Scope:** the IaC repos — `czid-infra`, `cypherid-web-infra`,
  `cypherid-workflow-infra`. (App repos can adopt the same `gitleaks`/`trivy`
  jobs later.)
- **Where:** each repo's `.github/workflows/security.yml`.
- **Companion:** point-in-time findings inventory in
  [`SECURITY-FINDINGS-2026-06-11.md`](./SECURITY-FINDINGS-2026-06-11.md).

---

## 1. The four tools

| Tool | License | What it scans | Role |
|------|---------|---------------|------|
| **gitleaks** | MIT | Committed secrets, across **git history** | Catch leaked credentials |
| **Trivy** | Apache-2.0 | CVEs (deps), **IaC misconfig**, secrets, SBOM | Broad security scanner |
| **tflint** | MPL-2.0 | Terraform/Terraform correctness + provider best-practice | Lint (not security) |
| **Checkov** | Apache-2.0 | Deep IaC policy-as-code (1000+ policies) | Exhaustive policy pass |

All four are free/OSS. There is **no paid tier required**; Aqua (Trivy) and
Palo Alto/Prisma (Checkov) sell SaaS platforms, but the CLIs used here are fully
free.

> **gitleaks licensing gotcha:** the gitleaks **CLI binary** is MIT and free with
> no key. The official **`gitleaks-action`** GitHub Action requires a (free)
> `GITLEAKS_LICENSE` for *organization* accounts. We deliberately install and run
> the **CLI binary** in CI to avoid that requirement entirely.

---

## 2. Posture — gates are calibrated per repo

Not every repo enforces every gate on day one. A repo with a large backlog of
pre-existing findings runs the misconfig/lint scanners in **report mode**
(surface, don't block) and **ratchets** to hard-fail as the backlog is burned
down. **Secret scanning always hard-fails** (unambiguous).

| Repo | gitleaks | trivy | tflint | checkov |
|------|----------|-------|--------|---------|
| **czid-infra** (clean foundation) | hard-fail | **hard-fail** (HIGH/CRIT) | **fail on error** | opt-in, report |
| **cypherid-workflow-infra** (legacy) | hard-fail | report (`exit-code: 0`) | report (`continue-on-error`) | opt-in, report |
| **cypherid-web-infra** (large legacy) | hard-fail | report | report | opt-in, report |

**The ratchet:** as findings in a legacy repo are fixed or triaged, flip
`trivy.exit-code` `0 → 1` and remove `continue-on-error` from `tflint`. The
goal is every repo eventually matching czid-infra's hard-fail posture.

---

## 3. How the CI jobs are wired

`security.yml` runs on `push` / `pull_request` / `merge_group`, plus a
`workflow_dispatch` with a `run_checkov` boolean.

- **gitleaks** — installs the pinned CLI binary, then `gitleaks git . --redact
  --no-banner --exit-code 1`. `fetch-depth: 0` so the **full history** is scanned.
- **trivy** — `aquasecurity/trivy-action`, `scan-type: fs`,
  `scanners: vuln,misconfig,secret`, `severity: HIGH,CRITICAL`,
  `ignore-unfixed: true`. Honors `.trivyignore`.
- **tflint** — `setup-tflint` + `tflint --recursive`. Core ruleset (no cloud
  plugin, so no token needed); add the AWS ruleset later for deeper checks.
- **checkov** — `bridgecrewio/checkov-action`, **only** when dispatched with
  `run_checkov = true`. `soft_fail: true` (report-only) — reserved for
  full-suite / pre-prod review, not every push.

### Running the optional Checkov full-suite pass
GitHub → **Actions → security → Run workflow** → tick **`run_checkov`**.
(Or `gh workflow run security.yml -f run_checkov=true`.) Use it before a prod
cut or during a hardening sprint; it does not run on ordinary pushes.

---

## 4. Run the scanners locally (Docker — no host installs)

From a repo root. (The volume mount must be quoted — the workspace path has a
space.)

```sh
REPO="$PWD"

# gitleaks — secrets over history
docker run --rm -v "$REPO":/work -w /work ghcr.io/gitleaks/gitleaks:latest \
  git /work --redact --no-banner --exit-code 1

# trivy — vuln + IaC misconfig + secret (HIGH/CRITICAL), honoring .trivyignore
docker run --rm -v "$REPO":/work -w /work aquasec/trivy:latest \
  fs --scanners vuln,misconfig,secret --severity HIGH,CRITICAL \
     --ignore-unfixed --exit-code 1 /work

# trivy — RAW (see findings that .trivyignore is currently suppressing)
docker run --rm -v "$REPO":/work -w /work aquasec/trivy:latest \
  fs --scanners misconfig,secret --severity HIGH,CRITICAL --ignorefile /dev/null /work

# tflint — recursive lint (fail on errors only)
docker run --rm --entrypoint tflint -v "$REPO":/work -w /work \
  ghcr.io/terraform-linters/tflint:latest --recursive --minimum-failure-severity=error

# checkov — deep IaC policy pass (terraform)
docker run --rm -v "$REPO":/work -w /work bridgecrew/checkov:latest \
  -d /work --framework terraform --compact --quiet
```

---

## 5. Triage — the suppression ledgers

When a finding is a **false positive** or an **accepted risk**, record it (with a
reason + date) so the gate stays green *and* the decision is auditable. Never
suppress a real, unaddressed finding silently.

### Trivy → `.trivyignore` (repo root)
Auto-loaded by Trivy. One check ID per line; `#` comments. Group by status:

```
# --- ACCEPTED (by design) ---
# AWS-0164: public subnet's map_public_ip_on_launch=true is intentional (NAT GW
# / public LBs live here). Reviewed + accepted 2026-06-11.
AWS-0164

# --- OPEN / pending decision (NOT accepted — re-evaluate, then remove) ---
# AWS-0040/0041: EKS API endpoint defaults to public 0.0.0.0/0 — real gap, needs
# an ops decision. Ignored only so the gate is usable. Remove once fixed.
AWS-0040
AWS-0041
```

### gitleaks → `.gitleaks.toml` (repo root)
Auto-loaded by gitleaks. Extend the default rules, then allowlist FPs **narrowly**
(prefer a line-regex over a whole-file path so a real future secret still trips):

```toml
title = "CZ ID gitleaks config"
[extend]
useDefault = true

[[allowlists]]
description = "FP: _get_params_from_ssm reads FROM SSM; parameter_keys is a list of names, not a secret."
regexTarget = "line"
regexes = ['''Names=parameter_keys''']
```

You can also suppress a single line in source with a trailing `# gitleaks:allow`
comment — but note that does **not** suppress the same secret in *history*, so
`gitleaks git` still flags it; the config allowlist is the robust option.

### tflint → `.tflint.hcl` + inline
Disable a rule in `.tflint.hcl` (`rule "..." { enabled = false }`) or annotate a
line with `# tflint-ignore: <rule>`.

### Checkov → inline `# checkov:skip=CKV_AWS_NN: reason` or `.checkov.yaml` (`skip-check:`)

---

## 6. Maintenance

- **Versions:** the pinned action/tool versions (`trivy-action`,
  `setup-tflint`, `checkov-action`, the gitleaks release) are kept current by
  **Renovate** (`improvement-#009`, the *github actions* group). Don't hand-bump.
- **Air-gapped / appliance edition (slice 8):** the vendor packages the scanner
  binaries + their vulnerability DBs; the CI that invokes them is unchanged.
  (Trivy pulls its vuln DB at runtime — mirror it in the offline build.)
- **Adding a repo:** copy `security.yml`; start legacy repos in report mode,
  add a `.gitleaks.toml`/`.trivyignore` as FPs surface, then ratchet.
