# TODO — czid-infra (foundation / state)

Outstanding work for the foundation repo. Forward-looking companion to the
program-level `SESSION-ACCOMPLISHMENTS` (done). This repo is new in the overhaul,
so it is not in the jslower review; its items come from our own security scans.

**Status:** OPEN · PARTIAL · BLOCKED. **Priority:** P0 · P1 · P2 · P3.

## Security (from improvement-#010 scanners)
- [ ] **(P0) EKS API endpoint is public to `0.0.0.0/0`** — `endpoint_public_access=true`, `eks_public_access_cidrs` default `["0.0.0.0/0"]`. Decide: restrict to office/VPN CIDRs, or private endpoint + bastion; confirm Argo CD / kubectl access paths. Then remove `AWS-0040`/`AWS-0041` from `.trivyignore`. `foundation/modules/eks` (+ `foundation/variables.tf`). *(spawned task)*
- [ ] (P1/P2) Burn down the **17 Checkov + 1 Trivy** foundation findings (the gate is hard-fail with 2 OPEN ignores): EKS control-plane logging (`CKV_AWS_37`), VPC flow logs (`CKV2_AWS_11`), default-SG lockdown (`CKV2_AWS_12`), S3 public-access-block + access logging on the tfstate buckets, DynamoDB lock table PITR + CMK, KMS key policies, S3 lifecycle. → `docs/SECURITY-FINDINGS-DETAILED.md`. Low-risk (greenfield, no live state) and high-leverage (every env inherits the foundation).
- [x] `AWS-0164` (public subnet public IP) accepted by design (`.trivyignore`). *(done)*

## Lint
- [ ] (P3) Remove the 5 unused locals in `consumers/seqtoid-web/remote_state.tf` (`vpc_id`, `private_subnets`, `eks_cluster_name`, `oidc_provider`, `openbao_address`) — clears the tflint warnings.

## Done this session, awaiting merge/push (nothing pushed)
- `feature-#001-shared-state-backend` (base) · `improvement-#004-ci-automation` · `improvement-#009-renovate` · `improvement-#010-security-scanning`

## Note
`main` carries no `.tf` — the foundation IaC lives on `feature-#001-shared-state-backend`. Branch new work off that, not `main`.
