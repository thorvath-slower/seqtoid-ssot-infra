# TODO — czid-infra (foundation / state)

Outstanding work for the foundation repo. Forward-looking companion to the
program-level `SESSION-ACCOMPLISHMENTS` (done). This repo is new in the overhaul,
so it is not in the jslower review; its items come from our own security scans.

**Status:** OPEN · PARTIAL · BLOCKED. **Priority:** P0 · P1 · P2 · P3.

## Security (from improvement-#010 scanners)
- [ ] **[EKS private-endpoint slice] (P0) Make the EKS API endpoint private** — DECISION MADE (2026-06-11): private endpoint + SSM bastion, pull-based GitOps (see `docs/DEPLOYMENT-ARCHITECTURE.md`). Flip `endpoint_public_access=false` + drop the `0.0.0.0/0` default **in the same slice as the SSM bastion** (else a future apply locks out the control plane), then remove `AWS-0040`/`AWS-0041` + clears `CKV_AWS_38`/`CKV_AWS_39`. `foundation/modules/eks` + `foundation/variables.tf` + new bastion. User-facing data plane is unaffected (public ALB Ingress).
- [ ] **[security-#002 foundation logging] (P2) S3 server-access logs + VPC flow logs** — the 3 residual findings from `security-#001` (`CKV_AWS_18` ×2 on the tfstate buckets, `CKV2_AWS_11` on the VPC). Each needs supporting infra (access-log bucket(s) + KMS grant; flow-log group/role or S3 target), so they're their own slice. → `docs/SECURITY-001-FOUNDATION-HARDENING.md` §residual.
- [x] **[security-#001] Foundation config hardening — 11 greenfield Checkov fixes** (KMS key policies ×4, DynamoDB CMK+PITR, S3 EventBridge notifications ×2, DR S3 lifecycle, default-SG lockdown, EKS all-5 control-plane log types). Checkov 17→5 failed (5 = endpoint+logging, deferred above); `terraform validate`+`fmt` clean. *(done, branch `security-#001-foundation-hardening`)* → `docs/SECURITY-001-FOUNDATION-HARDENING.md`.
- [x] `CKV_AWS_130` / `AWS-0164` (public subnet public IP) accepted by design (inline `checkov:skip` + `.trivyignore`). *(done)*

## Lint
- [ ] (P3) Remove the 5 unused locals in `consumers/seqtoid-web/remote_state.tf` (`vpc_id`, `private_subnets`, `eks_cluster_name`, `oidc_provider`, `openbao_address`) — clears the tflint warnings.

## Done this session, awaiting merge/push (nothing pushed)
- `feature-#001-shared-state-backend` (base) · `improvement-#004-ci-automation` · `improvement-#009-renovate` · `improvement-#010-security-scanning`

## Note
`main` carries no `.tf` — the foundation IaC lives on `feature-#001-shared-state-backend`. Branch new work off that, not `main`.
