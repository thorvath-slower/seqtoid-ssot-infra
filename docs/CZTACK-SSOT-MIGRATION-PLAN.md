# cztack SSOT Migration Plan (CZID-424)

Status: PLAN / gated. Prod-touching. No apply happens as part of adopting this plan.
Decision: Tom, 2026-07-08 -- Option B (SSOT consolidation). Consolidate cztack to the single
`seqtoid-ssot-infra/modules/cztack/` copy and repoint all consumers to it via a PUBLIC git source,
then remove the per-repo vendored copies.

Related: #424 (this decision), #403 (per-repo vendoring), #404 (SSOT trim to consumed set),
#140 (version SSOT), #322 / PR #37 (eks endpoint param added to SSOT), #213 (straggler versions).

---

## 1. The unblocker: public git source, no credentials

`seqtoid-ssot-infra` is a PUBLIC repo. Consumers can therefore reference its modules over public
HTTPS with NO credentials, SHA-pinned:

```hcl
source = "git::https://github.com/thorvath-slower/seqtoid-ssot-infra.git//modules/cztack/<module>?ref=<sha>"
```

This removes the private-repo git-auth wall that #403 cited as the reason to vendor per-repo.

PROVEN (pilot, CZID-424): `dev/maintenance` `module.assets-cert` repointed from
`../../../modules/aws-acm-certificate-v0.104.2` to
`git::https://github.com/thorvath-slower/seqtoid-ssot-infra.git//modules/cztack/aws-acm-certificate?ref=3703d33`.
`terraform init -backend=false` -- run with git credential helpers disabled (`credential.helper=""`)
and `GIT_TERMINAL_PROMPT=0` -- downloaded the module anonymously from the public repo, and
`terraform validate` passed. Pilot PR: cypherid-web-infra#228 (DO NOT MERGE).

Pinning / bumping: pin `?ref=` to a full 40-char commit SHA (not a branch) so the fetch is
immutable and reproducible. To bump, land the module change in `seqtoid-ssot-infra` main, then
bump the `?ref=` SHA in the consumer in a separate PR with plan review. (An annotated tag such as
`v0.104.2-seqtoid.N` on the SSOT repo is an acceptable alternative ref and is more readable; SHA is
the safe default.)

---

## 2. Inventory: who vendors cztack today

Sole per-repo cztack consumer across the fleet: **cypherid-web-infra**.

Verified to NOT vendor or reference any cztack module:
- cypherid-workflow-infra (`terraform/modules/` holds only bespoke pipeline modules)
- czid-infra (`infra/state-foundation/foundation/modules/` holds only eks/network/openbao/registries)
- seqtoid-web, seqtoid-workflows, seqtoid-graphql-federation-server (no terraform cztack)
- seqtoid-ssot-infra itself -- holds the SSOT copy but its own stacks source NO cztack module (the
  SSOT copy currently has zero direct consumers; #404 comment).

cypherid-web-infra footprint:
- 38 vendored cztack module directories under `terraform/modules/aws-*-v<ver>/`
- 117 `source =` call-sites referencing those vendored copies, of which 23 are intra-module refs
  (one vendored module sourcing another, e.g. `ecs-cluster` -> `aws-cloudwatch-log-group`,
  `cloudfront-access-logs` -> `aws-s3-private-bucket`).

Because cypherid-web-infra is the only consumer, this migration is single-repo in scope. The
"repo-by-repo" phasing below is really "env-by-env within cypherid-web-infra"; other repos need no
work unless they later adopt cztack.

---

## 3. Per-module repoint feasibility (cypherid-web-infra vendored copy -> SSOT)

The SSOT copy (post-#404 trim) carries the **v0.104.2** generation of each module (26 modules,
unversioned directory names). Feasibility splits three ways:

### 3a. GREEN -- v0.104.2 vendored copy with a matching SSOT module (repoint now, SHA-pin)

| vendored copy (web-infra) | SSOT module path |
|---|---|
| aws-acm-certificate-v0.104.2      | modules/cztack/aws-acm-certificate      |
| aws-aurora-v0.104.2               | modules/cztack/aws-aurora               |
| aws-aurora-mysql-v0.104.2         | modules/cztack/aws-aurora-mysql         |
| aws-cloudwatch-log-group-v0.104.2 | modules/cztack/aws-cloudwatch-log-group |
| aws-ecr-repo-v0.104.2             | modules/cztack/aws-ecr-repo             |
| aws-ecs-job-v0.104.2              | modules/cztack/aws-ecs-job              |
| aws-eks-cluster-v0.104.2          | modules/cztack/aws-eks-cluster (*)      |
| aws-firehose-s3-archiver-v0.104.2 | modules/cztack/aws-firehose-s3-archiver |
| aws-iam-instance-profile-v0.104.2 | modules/cztack/aws-iam-instance-profile |
| aws-iam-password-policy-v0.104.2  | modules/cztack/aws-iam-password-policy  |
| aws-iam-policy-cwlogs-v0.104.2    | modules/cztack/aws-iam-policy-cwlogs    |
| aws-iam-policy-dynamodb-rw-v0.104.2 | modules/cztack/aws-iam-policy-dynamodb-rw |
| aws-iam-policy-ecr-writer-v0.104.2 | modules/cztack/aws-iam-policy-ecr-writer |
| aws-iam-role-github-action-v0.104.2 | modules/cztack/aws-iam-role-github-action |
| aws-iam-service-account-eks-v0.104.2 | modules/cztack/aws-iam-service-account-eks |
| aws-param-v0.104.2                | modules/cztack/aws-param                |
| aws-params-reader-policy-v0.104.2 | modules/cztack/aws-params-reader-policy |
| aws-params-secrets-setup-v0.104.2 | modules/cztack/aws-params-secrets-setup |
| aws-redis-replication-group-v0.104.2 | modules/cztack/aws-redis-replication-group |
| aws-s3-private-bucket-v0.104.2    | modules/cztack/aws-s3-private-bucket    |
| aws-ssm-params-writer-v0.104.2    | modules/cztack/aws-ssm-params-writer    |

(*) aws-eks-cluster: the SSOT copy already carries the in-house `cluster_endpoint_*` param
(#322 / PR #37); confirm the SSOT module content matches the fork tag `v0.104.2-seqtoid.1` before
repointing the eks stacks (these touch prod cluster access -- highest-care repoint).

21 modules. These are byte-identical vendored v0.104.2 code, so a repoint should produce a
`terraform plan` with NO resource changes (module source change only). That no-op plan is the
per-module acceptance gate.

### 3b. YELLOW -- older-version vendored copies (SSOT has only v0.104.2)

Each needs version reconciliation FIRST (either upgrade the consumer to v0.104.2 with plan review,
or vendor the specific older version into SSOT under a versioned path). Do NOT silently repoint an
older-version consumer to the v0.104.2 SSOT module -- that is a version bump, plan it as one.

| vendored copy | note |
|---|---|
| aws-acm-certificate-v0.41.0      | prod/maintenance |
| aws-cloudwatch-log-group-v0.41.0 | via ecs-cluster-v2.2.1 chain |
| aws-cloudwatch-log-group-v0.43.1 | via ecs-cluster-v2.2.1 chain |
| aws-ecs-job-v0.41.0              | resque (x-env), ~6 call-sites |
| aws-iam-instance-profile-v0.60.0 | via ecs-cluster-v2.2.1 |
| aws-iam-policy-cwlogs-v0.43.1    | via ecs-cluster-v2.2.1 |
| aws-param-v0.26.1                | |
| aws-params-reader-policy-v0.41.0 | |
| aws-redis-replication-group-v0.91.1 | |
| aws-s3-private-bucket-v0.73.0    | idseq-dev sra_s3 (commented) |
| aws-ssm-params-writer-v0.41.0    | |

### 3c. RED -- vendored modules with NO SSOT equivalent (public source does NOT work yet)

The SSOT set does not contain these modules at all, so the public-git-source approach cannot be
used until the module is first re-vendored into SSOT (from the in-house fork) or the consumer is
migrated to an equivalent that is in SSOT. Flagged per the task:

| vendored copy | resolution |
|---|---|
| aws-elasticsearch-v0.199.1        | add to SSOT (re-vendor) or keep per-repo |
| aws-elb-access-logs-bucket-v0.420.0 | add to SSOT or keep per-repo |
| aws-env-v4.0.0                    | add to SSOT or keep per-repo |
| aws-iam-ecs-task-role-v0.41.0     | add to SSOT (older gen) or keep per-repo |
| aws-iam-policy-s3-reader-v0.420.0 | add to SSOT or keep per-repo |
| aws-iam-policy-s3-writer-v0.66.0  | add to SSOT or keep per-repo (12 call-sites -- highest RED volume) |

### 3d. Out of scope (non-cztack external dep, flagged in passing)

5 call-sites still reference `git@github.com:chanzuckerberg/shared-infra//terraform/modules/aws-batch-env?ref=...`
over SSH (upstream CZI public repo, not cztack). Separate supply-chain item -- not part of this
cztack consolidation, but note it uses SSH (needs a deploy key in CI) and could later be vendored
into SSOT the same way.

---

## 4. Phased repoint order

Guiding rule: dev -> staging -> prod, GREEN modules before YELLOW/RED, leaf consumers before
shared/intra-module ones. Every phase is gated on a clean `terraform plan` (module-source-only
change => zero resource diff) and Tom's sign-off before any apply. Dev-only is actionable now;
staging/prod are authored-and-held per the current operating envelope.

- Phase 0 (DONE): pilot -- dev/maintenance aws-acm-certificate, PR #228 (proof, DO NOT MERGE).
- Phase 1 (dev, GREEN): repoint all dev-env GREEN v0.104.2 consumers module-by-module. One module
  family per PR (e.g. all aws-acm-certificate dev refs), each with a no-op plan attached.
- Phase 2 (staging, GREEN): same set, staging env. Authored + held.
- Phase 3 (prod, GREEN): same set, prod env. Authored + held; aws-eks-cluster and aws-aurora* get
  extra care (stateful / cluster-access). Apply-gated on Tom.
- Phase 4 (YELLOW): version-reconcile each older-version consumer (upgrade-to-v0.104.2 with plan
  review, or vendor the exact older version into SSOT under a versioned path), then repoint. One
  version bump per PR.
- Phase 5 (RED): decide per module -- re-vendor into SSOT from the in-house fork (preferred, keeps
  Option B whole) or consciously leave per-repo. Then repoint the re-vendored ones.
- Phase 6 (cleanup): once a vendored copy has zero remaining `source =` references in web-infra,
  delete the `terraform/modules/aws-*-v<ver>/` directory. Verify with a repo-wide grep before
  deleting. This is where the DRY payoff lands.

Intra-module refs (3a's 23 sub-module call-sites, e.g. inside `ecs-cluster-*`,
`cloudfront-access-logs`, `happy-env-eks`, `web-acl-regional`) are repointed in the same phase as
their module family; a vendored copy can only be deleted (Phase 6) after BOTH its root-stack and
intra-module referrers are repointed.

---

## 5. Keeping the in-house fork as the re-vendor source

`thorvath-slower/cztack@v0.104.2-seqtoid.1` (PRIVATE in-house fork) stays the canonical upstream for
re-vendoring INTO the SSOT. SSOT's `modules/cztack/` is a frozen snapshot of that fork; consumers
never reference the fork directly. To update a module: re-vendor from the fork at a new tag into
`seqtoid-ssot-infra/modules/cztack/`, land it, then bump consumer `?ref=` SHAs (Phase-style, plan
per consumer). This keeps a single upgrade point (SSOT) and a single re-vendor source (fork), and
the fork being private is fine because only maintainers pull from it -- consumers only hit the
PUBLIC SSOT.

---

## 6. Validation & apply-gating per phase

- Per repoint PR: `terraform init` (proves the public fetch) + `terraform validate` + `terraform plan`.
  GREEN acceptance = plan shows module source change with NO resource add/change/destroy.
- No apply without Tom's explicit sign-off. Dev applies only after a clean dev plan; staging/prod
  authored-and-held.
- Keep `.terraform.lock.hcl` provider pins unchanged (repoint touches module source, not providers).
- CI git-auth: none required for GREEN/YELLOW (public SSOT). Only the out-of-scope shared-infra SSH
  ref (3d) needs a CI deploy key, and only if/when it is touched.

---

## 7. Consumers where the public source does NOT work (summary)

- 3c RED modules (6): not present in the SSOT set, so no public path exists until they are
  re-vendored into SSOT or the consumer is migrated. Highest-volume: aws-iam-policy-s3-writer (12
  call-sites).
- 3d shared-infra `aws-batch-env` (5 call-sites): not cztack; SSH source; out of scope here.

Everything else (GREEN 21 modules + YELLOW after version reconciliation) works over the public,
credential-free, SHA-pinned git source proven by the pilot.
