# Security Findings Inventory — 2026-06-11

Point-in-time results from the `improvement-#010` security scanners (gitleaks,
Trivy, tflint, Checkov) across the three IaC repos. Severities are as reported
by the tools. See [`SECURITY-SCANNING.md`](./SECURITY-SCANNING.md) for how to
reproduce and triage.

**This file is the summary.** For **every individual finding (729)** — repo,
full path, line, resource, and remediation:
- [`SECURITY-FINDINGS-DETAILED.md`](./SECURITY-FINDINGS-DETAILED.md) — itemized
  register, grouped by repo → check type.
- `CZ-ID-Security-Findings-Register-2026-06-11.xlsx` (workspace root) — the same
  729 findings as a sortable/filterable spreadsheet (Findings + Remediation
  guide + Summary sheets).

> Scope: IaC misconfiguration, secrets, and lint. App-repo (`seqtoid-web` etc.)
> dependency CVEs are tracked separately (runtime upgrades / Renovate).
> All scans run with `init -backend=false`-equivalent static analysis — no live
> cloud access.

## Totals at a glance

| Repo | gitleaks (secrets) | Trivy HIGH/CRIT | Checkov failed / passed | tflint issues |
|------|--------------------|-----------------|-------------------------|---------------|
| czid-infra (clean foundation) | 0 | 3 | 17 / 177 | 5 (warnings) |
| cypherid-workflow-infra (legacy) | 1 → FP | 53 | 65 / 190 (32 distinct) | 132 |
| cypherid-web-infra (large legacy) | 6 → all FP | extensive¹ | 591 / 2023 (84 distinct) | 651 |

¹ web-infra Trivy wasn't separately tallied (very large/slow); Checkov's 591
findings across 460 resources is the fuller IaC-misconfig picture for it.

**Headline:** **0 real secrets** (all 7 gitleaks hits triaged as false positives).
The one **critical, real, actionable** finding is the **EKS public API endpoint
(`0.0.0.0/0`)** in czid-infra. Everything else is an IaC best-practice/hardening
backlog (encryption, logging, public-access-blocks, IAM scoping, tag immutability).

---

## 🔴 Priority findings (real, act on these)

| # | Finding | Where | Tools | Status |
|---|---------|-------|-------|--------|
| P1 | **EKS API endpoint public to `0.0.0.0/0`** | czid-infra `foundation/modules/eks` (defaults `endpoint_public_access=true`, `eks_public_access_cidrs=["0.0.0.0/0"]`) | Trivy AWS-0040/0041 (CRIT), Checkov CKV_AWS_38/39 | **OPEN** — spawned task; restrict CIDRs or go private endpoint |
| P2 | **Security-group rules allow unrestricted egress (`0.0.0.0/0`)** ×8 | cypherid-workflow-infra | Trivy AWS-0104 (CRIT), Checkov CKV_AWS_382 | Backlog (report mode) |
| P3 | **IAM policies use `*` resource / write without constraints** (×15 / ×14) | cypherid-web-infra | Checkov CKV_AWS_356 / CKV_AWS_111 | Backlog |
| P4 | **Unencrypted SNS/SQS; S3 public-access-block missing; IMDSv2 not enforced** | cypherid-workflow-infra | Trivy AWS-0095/0096/0086-0093/0130 | Backlog |

---

## czid-infra (clean foundation) — hard-fail gate

**gitleaks:** clean (8 commits scanned, 0 findings).

**Trivy (3 HIGH/CRITICAL):**
| ID | Sev | Finding | File | Status |
|----|-----|---------|------|--------|
| AWS-0040 | CRITICAL | EKS public access enabled | `foundation/modules/eks/main.tf` | OPEN (P1) — `.trivyignore` pending |
| AWS-0041 | CRITICAL | EKS open to public CIDR 0.0.0.0/0 | `foundation/modules/eks/main.tf` | OPEN (P1) — `.trivyignore` pending |
| AWS-0164 | HIGH | Subnet assigns public IP by default | `foundation/modules/network/main.tf` | **ACCEPTED** (public subnet by design) — `.trivyignore` |

**Checkov (17 failed / 177 passed):**
| Check | n | What | Notable resource |
|-------|---|------|------------------|
| CKV2_AWS_64 | 4 | KMS key Policy not defined | tfstate, tfstate_dr, app, openbao unseal keys |
| CKV2_AWS_62 | 2 | S3 event notifications | tfstate buckets |
| CKV_AWS_18 | 2 | S3 access logging | tfstate buckets |
| CKV_AWS_39 / CKV_AWS_38 | 1+1 | EKS public endpoint (same as P1) | foundation eks |
| CKV_AWS_37 | 1 | EKS control-plane logging disabled | foundation eks |
| CKV_AWS_130 | 1 | Subnet public IP (same as AWS-0164) | network |
| CKV2_AWS_11 | 1 | VPC flow logging not enabled | network VPC |
| CKV2_AWS_12 | 1 | Default SG doesn't restrict all traffic | network VPC |
| CKV_AWS_28 / CKV_AWS_119 | 1+1 | DynamoDB lock table: no PITR backup / not CMK-encrypted | tflock |
| CKV2_AWS_61 | 1 | S3 bucket lifecycle config | tfstate_dr |

**tflint (5 warnings):** unused locals (`vpc_id`, `private_subnets`, `eks_cluster_name`, `oidc_provider`, `openbao_address`) in `consumers/seqtoid-web/remote_state.tf` — dead-code cleanup candidate.

---

## cypherid-workflow-infra (legacy) — report mode

**gitleaks:** 1 finding → **FALSE POSITIVE** (allowlisted in `.gitleaks.toml`).
`generic-api-key` at `lambdas/taxon-indexing-eviction/chalicelib/config.py:103`
— `_get_params_from_ssm(parameter_keys, …)` *fetches* secrets from SSM
(`get_parameters(Names=parameter_keys, WithDecryption=True)`); `parameter_keys`
is a list of SSM parameter **names**, not a secret.

**Trivy (53 HIGH/CRITICAL):**
| ID | Sev | n | Finding |
|----|-----|---|---------|
| AWS-0031 | HIGH | 22 | ECR image tags are mutable |
| AWS-0104 | CRITICAL | 8 | SG rule allows unrestricted egress (P2) |
| DS-0002 | HIGH | 4 | Dockerfile runs as root |
| AWS-0130 | HIGH | 2 | IMDSv2 token not required |
| AWS-0095 / AWS-0096 | HIGH | 2+2 | SNS topic / SQS queue not encrypted |
| AWS-0086/0087/0091/0093 | HIGH | 2 ea | S3 public-access-block (acl/policy/ignore/restrict) |
| AWS-0132 | HIGH | 2 | S3 not encrypted with CMK |
| DS-0015 / DS-0029 | HIGH | 2+1 | Dockerfile `yum clean all` / `--no-install-recommends` missing |

**Checkov (65 failed / 190 passed; top of 32 distinct):** CKV_AWS_136 ×11 (ECR not KMS-encrypted), CKV_AWS_51 ×11 (ECR tags mutable), CKV_AWS_341 ×5 (launch-template metadata hop limit), plus Lambda hardening (CKV_AWS_117 VPC, 116 DLQ, 50 X-Ray, 115 concurrency, 272 code-signing, 173 env-var encryption), SG descriptions, CW log retention/KMS, Secrets Manager CMK.

**tflint:** 132 issues (lint/best-practice across the stacks; repo is pre-OpenTofu-conversion).

---

## cypherid-web-infra (large legacy) — report mode

**gitleaks:** 6 findings → **ALL FALSE POSITIVES** (allowlisted by path).
All `hashicorp-tf-password` in `terraform/envs/{dev,staging}/auth0/main.tf` — the
rule matched the OAuth grant-type token `"password"`/`"password-realm"` (partly
in **commented-out** lines) and `password_policy` connection config. Not
credentials; real auth0 secrets are provider/variable-sourced.

**Checkov (591 failed / 2023 passed; 84 distinct; top checks):**
| Check | n | What |
|-------|---|------|
| CKV_TF_1 | 121 | Terraform module sources not pinned to a commit hash |
| CKV2_AWS_6 | 21 | S3 bucket missing Public Access block |
| CKV2_AWS_62 | 21 | S3 event notifications not enabled |
| CKV_AWS_145 | 21 | S3 not KMS-encrypted by default |
| CKV_AWS_18 | 21 | S3 access logging not enabled |
| CKV_AWS_144 | 21 | S3 cross-region replication not enabled |
| CKV_AWS_23 | 18 | SG/rule missing description |
| CKV_AWS_356 | 15 | IAM policy allows `*` as resource (P3) |
| CKV_AWS_21 | 15 | S3 versioning not enabled |
| CKV_AWS_111 | 14 | IAM policy allows write without constraints (P3) |
| CloudFront (CKV_AWS_174/86/374/310/68, CKV2_AWS_32/47) | 14 ea | TLS<1.2, no access logging, no geo restriction, no origin failover, no WAF, no response-headers policy |
| CKV_AWS_158 | 9 | CloudWatch Log Group not KMS-encrypted |

**Trivy:** extensive HIGH/CRITICAL of the same families as workflow-infra
(not separately tallied here due to scan size).

**tflint:** 651 issues.

---

## Triage summary

- **Secrets:** 7 gitleaks hits → **7 false positives**, **0 real secrets**. All
  allowlisted with narrow, documented rules.
- **Accepted by design:** 1 (czid-infra AWS-0164 public subnet).
- **Open / real / actioned:** 1 critical (EKS public endpoint, P1) → spawned task.
- **Backlog (report mode, ratchet later):** ~700 IaC best-practice/hardening
  findings across the two legacy repos — encryption (S3/SNS/SQS/CW/ECR/KMS),
  logging (S3 access, VPC flow, CloudFront, EKS control plane), public-access
  blocks, IAM least-privilege, CloudFront WAF/TLS, tag immutability, and module
  commit-hash pinning. These overlap the planned prod-hardening and OpenTofu-
  conversion work.

## Suggested order of operations
1. **P1 — EKS endpoint** (critical, exposed surface) — decide + fix, drop the `.trivyignore` lines.
2. **P2–P4** — SG egress, IAM `*`/write, encryption + public-access-blocks (highest-risk of the backlog).
3. **Bulk best-practice** — S3 (logging/versioning/CRR/notifications), CloudFront, logging — often fixable with shared modules / wrapper defaults.
4. **Module commit-hash pinning** (CKV_TF_1 ×121) — supply-chain; align with the bug-#012 pinning ethos.
5. Ratchet each legacy repo's `trivy`/`tflint` to hard-fail as categories clear.
