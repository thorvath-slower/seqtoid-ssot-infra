# security-#001 — Foundation IaC hardening (greenfield Checkov fixes)

Branch `security-#001-foundation-hardening` off `feature-#001`. Burns down the
low-risk, greenfield Checkov findings on the state-foundation IaC — pure config
hardening, no behavioural change to what the foundation provisions.

## Baseline → result (live Checkov, framework=terraform)
- **Before:** 177 passed, **17 failed**, 0 skipped.
- **After:** 188 passed, **5 failed**, **1 skipped**.
- `tofu fmt` clean; `tofu validate` **Success** on both `bootstrap/` and `foundation/`.

## Fixed in this slice (11 findings)
| Check | What | Where |
|-------|------|-------|
| CKV2_AWS_64 ×4 | Explicit KMS key policy (root grant → IAM governs use) | `bootstrap/main.tf` (tfstate), `bootstrap/dr.tf` (tfstate_dr), `foundation/main.tf` (app), `modules/openbao/main.tf` (unseal) |
| CKV_AWS_119 | DynamoDB lock table encrypted with the state CMK | `bootstrap/main.tf` (tflock) |
| CKV_AWS_28 | DynamoDB lock table point-in-time recovery | `bootstrap/main.tf` (tflock) |
| CKV2_AWS_62 ×2 | S3 → EventBridge notifications on the state buckets | `bootstrap/main.tf`, `bootstrap/dr.tf` |
| CKV2_AWS_61 | S3 lifecycle on the DR state bucket | `bootstrap/dr.tf` |
| CKV2_AWS_12 | Default security group locked (no ingress/egress) | `modules/network/main.tf` |
| CKV_AWS_37 | EKS control-plane logging: all five log types | `modules/eks/main.tf` |

Notes: the openbao module had no `aws_caller_identity`/`aws_partition` data
sources in scope — added them for the key-policy ARN. KMS policies use a root
grant so the existing IAM role policies continue to govern actual key use.

## Accepted by design (1 — suppressed with justification)
- **CKV_AWS_130** `aws_subnet.public` auto-assigns public IPs. Intentional: the
  ALB and NAT gateways live in the public subnets; workloads/nodes run in the
  private subnets. Inline `checkov:skip` with rationale.

## Deliberately out of this slice (5 residual failures)
- **CKV_AWS_38 / CKV_AWS_39** — EKS public endpoint. Belongs to the **EKS
  private-endpoint slice** (Decision 1 / Option B): the default flip to
  `endpoint_public_access = false` must land *with* the SSM bastion or a future
  apply locks out the control plane. Not a config tweak.
- **CKV_AWS_18 ×2** (S3 server access logging) + **CKV2_AWS_11** (VPC flow logs)
  — these spawn their own log buckets / log groups + KMS grants. Carved into
  **security-#002 (foundation logging)** so the logging pipeline is one
  reviewable change rather than noise in this config pass.

## Verification (local, no live env)
- `docker run bridgecrew/checkov -d … --framework terraform`: 17 → 5 (all 5
  intentionally deferred above), 1 accepted-skip.
- `tofu init -backend=false && tofu validate`: Success on bootstrap + foundation.
- `tofu fmt -recursive`: no changes (formatting clean).

## Bucket B
- `tofu apply` to realise the changes (DynamoDB SSE/PITR, EventBridge wiring,
  default-SG adoption, KMS policy changes) and confirm no drift.

## Acceptance
- [x] 11 greenfield findings fixed; 1 accepted with justification.
- [x] Foundation still validates and formats clean.
- [x] Residual findings explicitly attributed to the endpoint + logging slices.
