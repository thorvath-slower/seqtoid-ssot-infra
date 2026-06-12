# Shared state backend + foundation inheritance

A single, backed-up home for **all** OpenTofu/Terraform state across the CZ ID
repos, with one **foundation** state that every other stack inherits from.

## The model (and why it isn't one giant state file)

One monolithic state for the whole platform is an anti-pattern: org-wide lock
contention, a huge blast radius, and slow plans. Instead:

```
                 s3://czid-tfstate-<acct>-<region>   (one shared, versioned bucket)
                 ┌──────────────────────────────────────────────────────┐
                 │ foundation/terraform.tfstate     ← MASTER (publishes   │
                 │ apps/seqtoid-web/terraform.tfstate    outputs)         │
                 │ apps/graphql-federation/terraform.tfstate              │
                 │ workflow-infra/terraform.tfstate                       │
                 │ ...one KEY per stack, never shared...                  │
                 └──────────────────────────────────────────────────────┘
        foundation  ──outputs──▶  data.terraform_remote_state.foundation  ──▶  downstream stacks
```

- **One shared backend** — every stack stores its state in the same bucket under
  its own `key`. One place to secure, version, and back up.
- **One foundation (master) state** — owns shared, long-lived infra (VPC, EKS,
  shared IAM, KMS, OpenBao, registries) and exposes it via `outputs.tf`.
- **Inheritance** — downstream stacks read those outputs with
  `data "terraform_remote_state"`. They consume the foundation; they don't own
  or duplicate it. `outputs.tf` is the contract — treat it as a stable API.

> `terraform_remote_state` can read **outputs only**, not arbitrary resources.
> If a downstream stack needs a value, the foundation must export it.

## Backup & durability ("as long as there's a backup")

- **Bucket versioning = the backup.** Every state write keeps the prior version;
  restore any point in time. Retention window is configurable
  (`state_backup_retention_days`, default 90).
- **Encryption** — SSE-KMS with a dedicated, rotated key.
- **TLS-only + public access fully blocked.**
- **`prevent_destroy`** on the bucket, lock table, and KMS key.
- **Locking** — DynamoDB table (works everywhere) *or* OpenTofu ≥ 1.10 native S3
  locking (`use_lockfile = true`, no DynamoDB).
- **Optional DR** — enable S3 Cross-Region Replication to a second-region bucket
  for full region-loss protection (snippet at the bottom).

## Bootstrap order (one-time)

The bucket must exist before any stack can use the S3 backend, so `bootstrap/`
runs with a **local** backend first.

```bash
cd bootstrap
tofu init                      # local backend
tofu apply                     # creates bucket + lock table + KMS key
tofu output backend_hcl        # copy into ../backend.hcl
# (optional) add a backend "s3" block and: tofu init -migrate-state
```

Then every other stack initializes against the shared backend:

```bash
cd ../foundation
tofu init -backend-config=../backend.hcl
tofu apply                     # stands up shared infra, publishes outputs

cd ../consumers/seqtoid-web
tofu init -backend-config=../../backend.hcl
tofu apply                     # inherits foundation outputs
```

## Portability (cloud vs appliance)

The backend is selected by deployment profile, so this works in the sellable
editions too:

| Profile            | State backend                                            |
|--------------------|----------------------------------------------------------|
| Cloud / MSP        | S3 (this scaffold) + KMS + versioning + lock             |
| Appliance (k3s)    | Local backend, or bundled **MinIO** via the same S3 block (S3-compatible), backed up to the customer's storage |

Same foundation/inheritance pattern either way — only the `backend.hcl` changes.

## Files

| Path | Purpose |
|------|---------|
| `bootstrap/`                         | Creates the shared bucket, lock table, KMS key (run once). |
| `bootstrap/dr.tf`                    | Cross-region replication for region-loss DR, gated behind `enable_dr` (off by default). |
| `backend.hcl`                        | Shared partial backend config; every stack adds only its `key`. |
| `foundation/backend.tf`              | Master state backend (`key = foundation/...`). |
| `foundation/main.tf`                 | Wires the modules + shared app KMS key, GitHub-OIDC provider, and shared least-privilege roles. |
| `foundation/variables.tf`            | Foundation inputs (region, CIDR, EKS sizing, GitHub OIDC, ECR repos). |
| `foundation/versions.tf`             | Provider requirements. |
| `foundation/outputs.tf`              | The inheritance contract. |
| `foundation/modules/network/`        | VPC, public/private subnets, IGW, NAT, routing (EKS-tagged). |
| `foundation/modules/eks/`            | EKS cluster, managed node group, IRSA OIDC provider, core addons. |
| `foundation/modules/openbao/`        | Auto-unseal KMS key, IRSA unseal role, published address. |
| `foundation/modules/registries/`     | ECR repos + CodeArtifact domain/repos with public-registry proxies. |
| `consumers/seqtoid-web/backend.tf`   | Example downstream backend (own `key`). |
| `consumers/seqtoid-web/remote_state.tf` | Example of inheriting foundation outputs. |

> The `foundation/` modules are **real** now — the inheritance contract in
> `outputs.tf` is backed by actual resources, not placeholders. The OpenBao
> *install* (Helm release, policies, dynamic DB-creds engine) is delivered later
> by the secrets workstream; the foundation only owns the infra it needs
> (auto-unseal key, IRSA role) and publishes a stable address.

## Cross-region replication (DR)

Region-loss DR is **committed code**, not a snippet — see `bootstrap/dr.tf`. It's
gated behind `enable_dr` (default `false`) so the base bootstrap still plans
clean with no destination required. Turn it on with:

```bash
cd bootstrap
tofu apply -var enable_dr=true -var dr_region=us-east-1
```

That stands up a versioned, encrypted, locked-down replica bucket + KMS key in
`dr_region`, the IAM role S3 assumes to replicate, and the replication rule on
the primary state bucket (KMS-encrypted objects included). Disabled by default
so nobody pays for a second-region bucket until they ask for it.
