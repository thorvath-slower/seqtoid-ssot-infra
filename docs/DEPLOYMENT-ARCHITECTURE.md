# CZ ID — Deployment Architecture: SaaS · MSP · Appliance

**Status: Draft / design.** How one codebase ships as three deployment models —
a multi-tenant **SaaS**, a fleet-managed **MSP** offering, and a self-hostable
**Appliance** (the "simple binary on customer infra"). Informs build slices
**6** (artifacts), **7** (provisioning), **8** (portability), **9**
(observability), **10** (multi-tenancy).

---

## 1. The three models on one axis

The models sit on an **isolation ↔ efficiency** spectrum. The same application
must serve all three; the difference is *where the boundaries are drawn*.

| | SaaS | MSP | Appliance |
|---|---|---|---|
| Who operates it | Us | Us (managed), per customer | The customer |
| Isolation boundary | **Logical** (row-level) | **Instance** (per-customer stack) | **Physical** (their infra) |
| Infra | One shared cloud estate | Many silos + central control plane | One self-contained node/cluster |
| Tenancy mode | `pooled` (RLS) | `single` per instance | `single` |
| Cost / efficiency | Highest | Medium | N/A (customer pays infra) |
| Data sovereignty | Ours | Configurable | Customer's |
| Connectivity | Online | Online | **Air-gap capable** |

> The hard rule: **build once, deploy three ways.** Forking the codebase per
> model is the failure mode. The unifier is a *deployment profile* + a backend
> *abstraction layer* + *GitOps* as the universal delivery substrate.

---

## 2. The unifying architecture (applies to all three)

```
                ┌──────────────────────────────────────────────┐
                │   One codebase  (seqtoid-web, graphql, workflows) │
                │   One Helm umbrella chart                      │
                └───────────────────────┬──────────────────────┘
                                        │  profile = saas | msp | appliance
            ┌───────────────────────────┼───────────────────────────┐
            ▼                            ▼                           ▼
   Adapter set: AWS-native      Adapter set: AWS-native      Adapter set: portable
   tenancy: pooled (RLS)        tenancy: single (per silo)   tenancy: single
            │                            │                           │
            ▼                            ▼                           ▼
   Shared EKS + Argo CD         Fleet: Argo CD app-of-apps    k3s + Argo CD/Helm
                                across customer clusters       (or plain Helm)
```

Three mechanisms make this work:

**A. Ports & adapters (the key enabler).** Every AWS-coupled capability sits
behind a stable interface with two adapters — an AWS-native one (SaaS/MSP) and a
portable one (appliance). The app and charts target the *port*, never the vendor.

| Capability (port) | AWS-native adapter | Portable adapter | Interface |
|---|---|---|---|
| Orchestration | EKS | **k3s** (single binary) | Kubernetes API |
| Object storage | S3 | **MinIO** | S3 API (unchanged) |
| Relational DB | RDS/Aurora **Postgres** | **CloudNativePG** (in-cluster) | Postgres wire |
| Secrets | OpenBao + SSM/chamber | **OpenBao** (in-cluster) | OpenBao / External Secrets |
| Container registry | ECR | in-cluster registry / **Harbor** | OCI |
| Package proxy | CodeArtifact | **Artifactory / offline mirror** | npm/pypi/maven endpoints |
| **Pipeline engine** | AWS **Batch + Step Functions** | **Argo Workflows** (or Cromwell/miniwdl-on-k8s) | a WDL-runner port |
| Identity | Auth0 (Organizations) | Auth0 or self-hosted **Keycloak** (OIDC) | OIDC |
| Ingress / LB | ALB + AWS LB Controller | **Traefik / MetalLB** (k3s) | K8s Ingress/Gateway |
| Delivery | Argo CD + Argo Rollouts | Argo CD + Rollouts (or Helm) | (same) |
| Observability | OTel → CloudWatch/Grafana | OTel → in-cluster Grafana/Loki | OTel (same) |

The foundation `registries` module already encodes this idea ("the appliance
edition ships an Artifactory/registry mirror instead … selected out of the
appliance profile upstream; the published endpoints keep the same shape").

**B. Deployment profile.** One Helm umbrella chart with
`values-{saas,msp,appliance}.yaml` selecting the adapter set + tenancy mode +
sizing. The blue/green chart (`feature-#002`, app-owned + multi-source values)
is the first brick of this.

**C. GitOps everywhere.** Argo CD app-of-apps is the delivery mechanism for all
three: one cluster (SaaS), many clusters from a central plane (MSP), in-cluster
or Helm-only (appliance). Argo Rollouts gives every model the same safe
blue/green + smoke-gated promotion.

---

## 3. Tenancy model (the SaaS ↔ single-tenant switch)

A single `TENANCY_MODE = pooled | single`. **Single-tenant is a degenerate case
of pooled** (the tenant id is fixed), so one code path serves all models.

- **`pooled` (SaaS):** shared Postgres with **Row-Level Security**. Every
  tenant-owned row carries `tenant_id`; RLS policies enforce it; the Rails app
  sets `SET app.current_tenant = '<id>'` per request (from the Auth0
  org/claim). Object storage = per-tenant S3 prefix (+ optional per-tenant KMS);
  pipeline runs tagged by tenant for isolation + cost attribution. **Isolation
  must be *proven*** (negative tests: tenant A can never read/influence tenant
  B) before ship — the slice-10 mandate.
- **`single` (MSP/Appliance):** the whole instance is one tenant. No RLS needed;
  isolation is the instance/account/physical boundary (strongest). The same RLS
  code runs harmlessly with a single fixed tenant.

Auth: Auth0 **Organizations** map 1:1 to tenants in SaaS; in single-tenant they
collapse to one org (or a self-hosted OIDC in the appliance).

---

## 4. Per-model architecture

### 4a. SaaS (multi-tenant, pooled)
Our current direction, extended. One shared EKS estate, `pooled` RLS, Auth0 orgs,
a shared ALB routing by subdomain/org to the (blue/green) active Service,
per-tenant S3 prefixes + cost tags, shared Batch queues with tenant-tagged jobs.
Most efficient; blast radius = the shared DB, mitigated by RLS + tested isolation
+ per-tenant KMS for the most sensitive data.
*Adds:* slice-10 tenant model + RLS + isolation proof; per-tenant quotas/billing.

### 4b. MSP (fleet-managed silos)
Per-customer **dedicated stack** (`single` profile) — strong isolation — plus a
**central control plane** the MSP runs:
- **Fleet GitOps:** a management Argo CD with an app-of-apps per customer
  cluster (the registered-clusters pattern). Upgrades roll across the fleet by
  bumping a chart version; each customer is a target.
- **Central observability:** federated metrics/logs (slice 9) — one pane across
  all customer instances, per-customer SLOs.
- **Provisioning automation:** slice-7 one-button stands up a new customer
  silo (cluster + profile + DNS + secrets) from a template.
- **Hosting choice (decision):** customer's cloud account (best
  sovereignty/isolation, harder ops) vs the MSP's account
  (namespace/cluster-per-customer, easier ops). Likely *both*, per contract.
*Reuses:* the appliance/silo profile + slice 7 + slice 9 + GitOps multi-cluster.

### 4c. Appliance (self-hostable binary)
The "simple binary on customer infra," air-gap capable:
- **Substrate:** **k3s** — Kubernetes as a single binary; one node or a small
  HA set. (k3s *is* the "binary"; the appliance wraps it.)
- **Everything in-cluster:** CloudNativePG, MinIO, OpenBao, in-cluster registry,
  Argo CD/Rollouts, Traefik ingress, Grafana/Loki — all from the portable
  adapter set, one umbrella chart.
- **Offline supply chain:** a bundled, **signed** image + package mirror
  (Artifactory/`distribution`), produced by slice 6; no internet required. Ties
  directly to the `bug-#012` digest-pinning + cosign signing.
- **Installer / form factor (decision):** a single `czid install` binary (wraps
  k3s + the bundle + `helm install`) and/or a prebuilt OVA/ISO. Target: one
  command (or one boot) to a working instance.
*This is slice 8 (feature-#007), and it is the cleanest forcing function for the
whole abstraction.*

---

## 5. The hard problems (rank-ordered)

1. **Pipeline engine portability — the crux.** AWS **Batch + Step Functions** is
   the deepest AWS coupling. The bioinformatics workflows are WDL (`miniwdl`),
   which is portable in principle. The appliance needs a non-AWS WDL runner —
   **Argo Workflows**, **Cromwell**, or **miniwdl's k8s backend**. This needs a
   spike; it gates the appliance and the MSP silo. Define a **WDL-runner port**
   so the app dispatches workflows the same way regardless of backend.
2. **Multi-tenant isolation proof (SaaS).** RLS is necessary but must be
   *tested adversarially* — automated negative tests + a review gate before any
   multi-tenant data lands. "Prove isolation before ship."
3. **Air-gapped supply chain.** A complete, signed offline mirror of every image
   + package (extends `bug-#012` / slice 6). Renovate/Trivy need mirrored DBs.
4. **Per-tenant cost attribution & metering (SaaS/MSP).** Tag every
   resource/job by tenant; aggregate for quotas + billing.
5. **Stateful data portability.** Postgres + object storage backup/restore that
   works identically across RDS↔CNPG and S3↔MinIO (for migrations + appliance
   updates).

---

## 6. Roadmap (mapping to the slices)

```
Phase 0  Abstraction layer + umbrella chart + profile system   (NEW prerequisite)
         └─ define the ports; AWS adapters first (we have them); profile values.
Phase 1  Appliance  (slice 8 + the portable adapters + WDL-runner port)
         └─ forces every AWS coupling to break; proves the abstraction; single-tenant.
Phase 2  SaaS multi-tenancy  (slice 10: tenant model + RLS + isolation proof)
         └─ can run in parallel with Phase 1 on the cloud path.
Phase 3  MSP  (slice 7 provisioning + slice 9 observability + fleet GitOps + silo profile)
         └─ composes the appliance/silo + a central control plane.
Underpins all:  slice 6 (signed golden images + offline mirror), the registries module.
```

**Recommended sequencing rationale:** do the **appliance second (Phase 1)** even
though SaaS is the current product — building the portable edition early is what
*forces* the AWS decoupling (especially the pipeline engine) and de-risks both
MSP (reuses the silo) and the abstraction itself. Multi-tenancy proceeds in
parallel on the SaaS branch.

---

## 7. Decisions needed (forks that change the design)

1. **SaaS tenancy depth:** `pooled` shared-DB + RLS (efficient, recommended) vs
   schema-per-tenant vs DB-per-tenant (stronger isolation, costlier). RLS is the
   default unless a customer/compliance need forces siloing.
2. **Appliance pipeline engine: DECIDED 2026-06-11 → `miniwdl-on-k8s`.**
   Rationale: our production runner (SWIPE, `cypherid-workflow-infra/terraform/
   swipe.tf`) *is* miniwdl wrapped on AWS Batch + Step Functions, so staying on
   miniwdl keeps the identical WDL dialect, call-cache semantics, and
   already-validated scientific output — the appliance port becomes "swap the
   compute backend (Batch → k8s Jobs)," not "re-platform the pipeline." This is
   the only option that preserves a *single* set of WDL workflows across SaaS and
   appliance (the portability thesis); it's also the lightest footprint (Python
   runtime, no JVM/DB engine). Argo Workflows is rejected *as the engine* (it
   doesn't speak WDL → a second pipeline definition = the fork we forbid), though
   it may serve as the executor *under* miniwdl. **Cromwell is the named fallback**
   if miniwdl's k8s backend proves too immature (real WDL engine with k8s
   backends, at the cost of JVM+DB weight and a workflow re-validation pass).
   The remaining risk — the k8s backend + the Step-Functions-equivalent control
   loop (submit/watch/retry/notify the `sfn_execution.rb` seam) — is exactly what
   the **green-lit-separately spike** must retire before Phase 1 scaffolding.
3. **MSP hosting:** in the customer's cloud account vs the MSP's account vs both.
4. **Appliance identity:** keep Auth0 (needs egress) vs self-hosted Keycloak
   (true air-gap).
5. **Appliance form factor:** installer binary/script vs OVA/ISO vs Helm-only.
6. **Appliance HA:** single-node (simplest) vs small HA k3s (resilient) as the
   default profile.

---

## 8. What we already have toward this
- **GitOps + blue/green** (`feature-#002`) — the universal delivery + safe
  rollout mechanism for all three models.
- **`registries` module** — the artifact-home abstraction (ECR/CodeArtifact ↔
  Artifactory mirror) already profile-aware.
- **EKS/network/OpenBao foundation modules** — the SaaS substrate; OpenBao is
  already portable. *API-endpoint posture DECIDED 2026-06-11 → private endpoint
  (`endpoint_public_access = false`), pull-based GitOps (in-cluster Argo CD never
  needs the API to be public), SSM bastion for one-time bootstrap + break-glass.*
  Chosen because it's lowest-maintenance (no CIDR allowlist drift), smallest
  attack surface, and the posture that generalizes to the air-gapped appliance —
  while leaving the **user-facing data plane (internet-facing ALB → Ingress →
  app pods; browser↔S3 presigned uploads/results) fully public and unaffected.**
  Implementation is a separate green-lit czid-infra security slice (flip the
  `endpoint_public_access`/`public_access_cidrs` defaults, add the SSM bastion,
  extend `enabled_cluster_log_types` to the full five) — not yet built; the
  default flip must land *with* the bastion to avoid a control-plane lockout.
- **Digest-pinned, soon-to-be-signed images** (`bug-#012`) — the basis for the
  golden-image + offline-mirror supply chain.
- **Postgres** (`improvement-#005`) — already off the AWS-only Aurora-MySQL path,
  which makes the RDS↔CloudNativePG swap realistic.
