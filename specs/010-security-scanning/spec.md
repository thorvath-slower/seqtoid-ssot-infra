# Improvement Specification: Security scanning CI (improvement-#010)

**Branch**: `improvement-#010-security-scanning`  ·  **Spec dir**: `specs/010-security-scanning/`

**Created**: 2026-06-11 · **Status**: Draft · **Repo**: `czid-infra` (base: `feature-#001-shared-state-backend`)

**Input**: Add automated security gates to the IaC CI — secret scanning, vulnerability + IaC-misconfiguration scanning, and Terraform linting — with an opt-in deep policy pass for full-suite/prod checks. All free/OSS tools.

## What this delivers — `.github/workflows/security.yml`

Four jobs (on push/PR/merge_group; Checkov on opt-in dispatch):

| Job | Tool | License | Posture |
|---|---|---|---|
| `gitleaks` | gitleaks (CLI binary) | MIT | **Hard-fail** on any secret, scans full git history. Uses the binary directly — sidesteps the org-license requirement of `gitleaks-action`. |
| `trivy` | Trivy (`fs`) | Apache-2.0 | **Hard-fail** on HIGH/CRITICAL vuln + IaC misconfig + secret; `ignore-unfixed`; honors `.trivyignore`. |
| `tflint` | tflint (`--recursive`) | MPL-2.0 | **Fail on errors**, warnings reported (`--minimum-failure-severity=error`). Core ruleset (no cloud plugin/token dependency). |
| `checkov` | Checkov | Apache-2.0 | **Opt-in** via `workflow_dispatch` `run_checkov` flag (reserved for full-suite / prod). **Report-only** (`soft_fail: true`) until findings are triaged. |

## Triage ledger — `.trivyignore`

Trivy findings on this repo, triaged:
- **Accepted (by design):** `AWS-0164` — the network module's *public* subnet sets `map_public_ip_on_launch = true` (that is what a public subnet is for; NAT gateway / public LBs live there, workloads run in private subnets).
- **OPEN / pending decision (NOT accepted):** `AWS-0040` + `AWS-0041` — the foundation EKS cluster defaults to a **public API endpoint open to `0.0.0.0/0`** (`endpoint_public_access = true`, `eks_public_access_cidrs` default `["0.0.0.0/0"]`). A real secure-by-default gap (Principle VII). Ignored only so the gate is usable; **needs an ops/arch decision** — restrict `public_access_cidrs` to office/VPN egress, or use a private endpoint + bastion — then remove the two ignore lines. Flagged separately.

## Verification (scanners run locally via Docker against this repo)

- gitleaks: **no leaks** (8 commits scanned).
- trivy: with the triaged `.trivyignore`, **exit 0** (no remaining HIGH/CRITICAL).
- tflint: 5 *warnings* only (unused locals in `consumers/seqtoid-web/remote_state.tf`) — non-blocking at error severity; a small cleanup candidate.
- `security.yml` is valid workflow YAML (4 jobs, triggers push/PR/merge_group/dispatch).

## Notes

- Renovate (improvement-#009 `github actions` group) keeps the pinned action/tool versions current.
- The AWS tflint ruleset (deeper provider checks) and tightening Checkov to hard-fail are documented follow-ups once findings are triaged.
- Air-gapped/appliance edition (slice 8): the vendor packages the scanner binaries; the CI that invokes them is unaffected.
