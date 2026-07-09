# Taxon Index Across Envs -- Snapshot/Restore vs Remote Reindex vs Rebuild

Ticket: Forgejo #479 (CZID) -- "Taxon index across envs: evaluate
snapshot/restore or remote reindex". Surfaced during the first seqtoid-web
deploy onto dev EKS (czid-dev-eks) via Argo CD, 2026-07-04.
Related: #476 (guard the rebuild), #477 (bulk-load tuning), #478 (parallelize),
#528 (full vs slice lineage), #551/#549/#550 (429 backoff + Ruby-3-safe rebuild).

Status: evaluation only. No code/config changed, no AWS apply. The DECISION
(which option, and whether to build any cross-env machinery at all) stays Tom's.

Placement note: this doc lives in `seqtoid-ssot-infra/docs/` rather than
`seqtoid-web/docs/` because the question is a cross-environment INFRA/platform
concern (OpenSearch domains, S3 snapshot repos, per-account isolation, per-env
SSM endpoints) that spans the app AND the infra repos. ssot-infra is the platform
SSOT and the right home for a cross-env decision record. It consolidates and
formalizes the earlier spike `TICKET-479-ES-SNAPSHOT-EVAL.md`.

---

## 1. Problem

The taxon-lineage OpenSearch index is rebuilt from the MySQL `taxon_lineages`
table in EVERY environment (dev/staging/prod), each rebuild taking ~53 min on
first deploy. Because the envs mirror one another, indexing the identical data
three times is redundant. Question: can we build the index once and load it into
the other envs via (a) an OpenSearch snapshot to S3 + restore, or (b) a remote
`_reindex`, instead of a from-scratch rebuild -- and how does that compare to
(c) just keeping the per-env rebuild?

---

## 2. How taxon indexing works today (investigation)

Two SEPARATE OpenSearch surfaces exist. Do not conflate them -- different
source-of-truth, builder, and sizing. This ticket is about surface A.

| | A. Taxon lineage index | B. Heatmap indices |
|---|---|---|
| Index name | `taxon_lineages_alias` (alias over `taxon_lineages_<version>`) | `scored_taxon_counts`, `pipeline_runs` |
| Source of truth | MySQL `taxon_lineages` | MySQL `taxon_counts` + `contigs` + `pipeline_runs` |
| Builder | Rails rake task (in-app `_bulk`) | AWS Lambda (Chalice/Python) + concurrency-manager + Glue |
| Trigger | Deploy-time Helm PreSync Job | Lazy, on heatmap view |
| ~53-min rebuild | THIS one | No |

Both point at the SAME per-env domain (`czid-<env>-heatmap-es`) via `ES_ADDRESS`
/ `HEATMAP_ES_ADDRESS`.

### Surface A -- the lineage index (the subject of #479)

- Model: `seqtoid-web/app/models/taxon_lineage.rb` -- `index_name
  'taxon_lineages_alias'` (`include Elasticsearch::Model`, guarded by
  `ELASTICSEARCH_ON`).
- Builder: `seqtoid-web/lib/tasks/taxon_lineage_slice.rake`
  - `import_data_from_s3`: reads a versioned CSV from S3
    (`S3_DATABASE_BUCKET`, e.g.
    `ncbi-indexes-prod/2024-02-06/index-generation-2/taxon_lineages_2024_slice.csv`),
    chunked `insert_all` into MySQL `taxon_lineages`. Fast.
  - `create_taxon_lineage_slice_es_index`: `es.create_index!(force: true)` then
    custom `find_in_batches` + `es.client.bulk` (bypasses the broken
    elasticsearch-model 7.1.1 `import` proxy on Ruby 3.3). Tunable via
    `TAXON_ES_BULK_BATCH` (5000) and `TAXON_ES_BULK_CONCURRENCY` (1); disables
    `refresh_interval`/replicas/translog during load (#477). This is the ~53-min
    step.
  - `load_slice_if_needed`: the deploy-hook entrypoint. Idempotent -- skips DB
    import if rows present, and only rebuilds the ES index when it is missing or
    doc-count != DB count (the #476 guard). ES rebuild is best-effort; failure
    does not fail the deploy (lineage lookups fall back to MySQL).
  - `reload_from_s3`: one-command full reload.
- Zero-downtime rebuild variant:
  `seqtoid-web/lib/tasks/update_tables_for_index_gen.rake` builds into a NEW
  index then `swap_es_alias` atomically repoints `taxon_lineages_alias` (via
  `ElasticsearchQueryHelper.swap_index_for_alias`), with a revert path. The
  alias-swap mechanism ALREADY EXISTS and any option below can reuse it.
- Deploy trigger:
  `seqtoid-web/deploy/charts/seqtoid-web/templates/taxon-load-job.yaml` --
  Argo `hook: PreSync`, `sync-wave: "1"`, running
  `rake taxon_lineage_slice:load_slice_if_needed` on every deploy. Guarded, so
  it is a no-op when the index is already in sync.
- Client/endpoint: `seqtoid-web/config/initializers/elasticsearch.rb` --
  `host: ENV['ES_ADDRESS']`, wrapped in an `OpensearchCircuit` breaker.
- Consumers: `seqtoid-web/app/helpers/elasticsearch_helper.rb` (`taxon_search`,
  `prefix_match` autocomplete) used by samples / phylo-tree controllers. This is
  the taxon typeahead when building heatmaps / phylo trees.

### Data facts that constrain the answer

- **Stack:** AWS OpenSearch Service (managed), engine `OpenSearch_2.7`. App uses
  `elasticsearch-ruby` 7.10.1 / `elasticsearch-model` 7.1.1.
- **Size:** ~4.75M docs, flat lineage fields (no large text bodies) -- on-disk
  primary size is a few GB. Well inside snapshot/restore's sweet spot. (The slice
  is smaller; #528 allows loading the full lineage.)
- **Source of truth is already in S3:** the lineage CSV originates from the
  `ncbi-indexes` bucket that every env can already read. The DB load is fast; the
  ~53 min is the OpenSearch indexing.
- **Account isolation (Decision D5, [[no-cross-account-isolated-envs]]):** each
  env is in its OWN AWS account (dev 491013321714, staging 030998640247, prod
  separate), self-sufficient, NO cross-account Terraform providers and NO
  standing cross-account network path between the OpenSearch domains. This is the
  single most important constraint and it decides between the options.

### Infrastructure today (cypherid-web-infra)

- Domain module `terraform/modules/aws-elasticsearch-v0.199.1/main.tf`:
  `aws_elasticsearch_domain "es"`, encrypt-at-rest + node-to-node, VPC, zone
  awareness. Snapshots: ONLY `snapshot_options { automated_snapshot_start_hour =
  3 }` -- AWS-managed automated snapshots, which are domain-internal and NOT
  restorable to another domain/account. There is NO manual S3 snapshot
  repository, NO snapshot/restore IAM role anywhere in the module.
- Per-env: `terraform/envs/<env>/heatmap-optimization/esdomain.tf`, domain
  `czid-<env>-heatmap-es`. Sizing SSOT in `esdomain_sizing.tf`: dev/sandbox
  `t3.small` x2 (burstable), staging `m6g.large` x4, prod `m6g.large` x8. Envs
  mirror in SHAPE (same module/vars) but diverge in SCALE by design.
- Endpoint per env: `.../heatmap-optimization/main.tf` writes SSM
  `/idseq-<env>-web/ES_ADDRESS` + `HEATMAP_ES_ADDRESS` =
  `https://<domain-endpoint>`. The taxon Lambda reads the same via SSM keyed on
  `DEPLOYMENT_ENVIRONMENT`.

### What does NOT exist today

No `_reindex`, no manual S3 snapshot repository, no restore, in any repo. The
only "reindex" is the app-side rebuild-from-MySQL. The only snapshots are
AWS-managed automated (non-portable). So cross-env promotion today IS
option (c): rebuild-from-source per env. Options (a) and (b) are both net-new.

---

## 3. The options

### Option A -- OpenSearch snapshot to S3 + restore

How it works on AWS OpenSearch Service:
1. Register a MANUAL snapshot repository on the source domain (an S3 bucket + an
   IAM role the domain assumes; a one-time signed `PUT _snapshot/<repo>`).
2. `PUT _snapshot/<repo>/<snap>?wait_for_completion` on the source -> segment
   files written to S3.
3. On each target domain, register a repo pointing at a bucket holding those
   files, `POST _snapshot/<repo>/<snap>/_restore` into a fresh index name, then
   alias-swap with the existing `swap_index_for_alias`. Restore is essentially a
   FILE COPY from S3 -- minutes, not ~53 min, because no per-doc indexing happens.

Pros:
- **Fastest cross-env load.** A few-GB segment copy vs re-indexing 4.75M docs.
- **Reuses the existing alias-swap** for zero-downtime cutover.
- **Preserves D5 isolation IF done right:** snapshot once (in a build/dev env),
  copy the snapshot OBJECTS into each env's OWN account bucket (`aws s3 cp` /
  S3 Batch / a one-shot scoped bucket policy), register the repo LOCALLY per env,
  restore locally. No standing cross-account API or network trust.

Cons:
- **Net-new infra to own:** snapshot repo registration + IAM role + S3 bucket
  PER ENV + an object-copy step + version-compat checks. Not a code one-liner.
- **Version coupling:** restore requires target OpenSearch/ES version >= source
  and within one major; index mapping must match. Becomes a release-time gate.
- **If done the lazy way** (every env reads one shared bucket in another account)
  it WOULD introduce the cross-account trust D5 forbids -- must be resisted.

### Option B -- Remote reindex (`_reindex` with a remote source)

How it works: the target domain pulls documents directly from the source domain
over HTTPS (`POST _reindex` with `source.remote.host`); the source host must be
in the target's `reindex.remote.whitelist` (a domain-level setting).

Pros:
- No S3 snapshot machinery; a single API call once connectivity exists.
- Faster than a cold rebuild (no S3->MySQL->index; sources docs directly).

Cons:
- **Requires cross-account/VPC networking + credentials** between the isolated
  domains -- precisely the coupling D5 forbids. This is disqualifying on its own.
- **Slower than snapshot/restore:** `_reindex` still performs per-document
  indexing ON THE TARGET (it only sources docs remotely), so the target still
  pays indexing cost, streamed over the network.
- Domain-level whitelist change on every target -- standing config, not one-shot.

Verdict: worse than A on every axis that matters here (isolation, speed, moving
parts). Do not adopt.

### Option C -- Rebuild-from-source per env (status quo)

How it works: each env runs `taxon_lineage_slice:load_slice_if_needed` as the
Argo PreSync Job -- S3 CSV -> MySQL -> `_bulk` into OpenSearch.

Pros:
- **Zero new infra.** Already built, already deployed, already guarded.
- **Fully isolation-clean:** each env reads only its own account's S3 + DB. No
  cross-env access of any kind.
- **The #476 guard already makes it rare:** the rebuild is SKIPPED when the index
  doc-count matches the DB, so it is not a per-deploy cost -- only a first-time /
  version-change cost.
- **#477/#478 attack the 53 min directly:** async translog + `replicas=0` +
  bounded `_bulk` parallelism. For a few-GB / 4.75M-doc index these are very
  likely to bring the rebuild well under an acceptable deploy budget.

Cons:
- Each env pays the (tuned) index cost once. The dominant driver is the
  UNDER-PROVISIONED dev domain (`t3.small` burstable -- CPU-credit cliff), not
  the algorithm; right-sizing dev off `t3` removes most of the pain
  (see `OPENSEARCH-INDEXING-SPEEDUP-EVAL-2026-07-04.md`).
- "Rare" still means a slow first build per env / per version bump.

---

## 4. Comparison

| Axis | A. Snapshot/restore | B. Remote reindex | C. Rebuild-from-source |
|---|---|---|---|
| Cross-env load time | Best (minutes, file copy) | Medium (still indexes on target) | Slowest cold (~53 min, tunable) |
| D5 isolation | OK if per-env bucket copy | VIOLATES (cross-acct network) | Cleanest (own account only) |
| New infra to build | Repo + IAM + bucket/env + copy | Whitelist + connectivity | NONE (exists) |
| Reuses alias-swap | Yes | Yes | Yes |
| Version coupling | Yes (source >= target, mapping) | Yes | None (rebuilds native) |
| Cost | S3 storage + copy egress | Cross-acct data transfer | Compute per rebuild |
| Ongoing ownership | Snapshot pipeline + version gate | Standing whitelist/trust | None beyond the rake task |

---

## 5. Recommendation

1. **Do NOT adopt Option B (remote reindex).** It needs cross-account network +
   credentials (violates D5) and is slower than snapshot/restore anyway.
2. **Stay on Option C for now, and first ship + measure #477 + #478.** Async
   translog (#477) and bounded parallelism (#478), plus the #476 guard that makes
   rebuilds rare, plus right-sizing dev off `t3` burstable, are very likely to
   bring the per-env rebuild under an acceptable deploy budget. Re-measure on dev
   EKS after these land BEFORE building any snapshot infrastructure.
3. **Only if the tuned rebuild is still too slow, pursue Option A (snapshot to
   S3 + restore)** -- in the isolation-preserving shape: snapshot once, copy the
   snapshot OBJECTS into each env's OWN account bucket, register the repo and
   restore locally, then alias-swap with the existing `swap_index_for_alias`.
   Gate it on an explicit source>=target version / mapping check at release time.
   Budget it as real infra work (snapshot repo module + IAM + bucket + copy
   automation, mirrored across all four envs per the infra-SSOT doctrine), not a
   code change.

Net: snapshot/restore is the correct TECHNICAL mechanism if a cross-env copy is
ever needed, but it is likely UNNECESSARY once #477/#478 + the #476 guard + dev
right-sizing reduce the rebuild time -- and it should not be built until the
tuned rebuild is measured and found wanting.

### Complementary (not competing) follow-ons

- **Scheduled CronJob refresh** (instead of deploy-only): with the #476 guard a
  scheduled run is a no-op when in sync, so it is cheap and keeps data fresh.
  Needs a version-advance mechanism -- the slice version is currently hardcoded
  `CURRENT_VERSION = "2024-02-06"` in `taxon_lineage_slice.rake`; "always fresh"
  requires detecting/rolling to newer NCBI index versions, tracked separately.
- **Decouple build-from-serve:** whether via snapshot (A) or a throwaway build
  domain, the goal is to remove the slow index build from the deploy hot path.

---

## 6. Decision points for Tom

- **Build any cross-env machinery at all?** The default recommendation is NO --
  ship #477/#478, right-size dev off `t3`, re-measure, and likely close #479 as
  "not needed, tuned rebuild is fast enough."
- **Convert #479 to an infra ticket only on evidence:** if the post-#477/#478
  measurement on dev EKS still exceeds the deploy budget, convert #479 into the
  Option A snapshot/restore pipeline (in the per-env-bucket, isolation-preserving
  shape above). Keep #479 open and blocked on that measurement until then.
- **Right-size dev domain:** confirm moving dev/sandbox off `t3.small` burstable
  to `m6g.large` (staging parity) -- this alone likely removes most of the 53-min
  cliff and is a one-time blue/green migration (Tom applies).
- **Scheduled-refresh + version-advance:** confirm whether to pursue the CronJob
  + NCBI-version-advance freshness path as its own ticket, independent of #479.
