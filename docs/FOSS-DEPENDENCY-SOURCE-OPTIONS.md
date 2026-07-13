# Single FOSS dependency-source -- options (CZID-205)

**Status:** OPTIONS doc -- analysis now, implementation POST-GA. No code/config change.
**Goal:** one internal source that every build and job pulls dependencies from, instead of
reaching the public internet directly (PyPI, npm, RubyGems, Docker Hub, ghcr, quay,
GitHub releases, `nodejs.org`, `repo.mysql.com`, and ~30 bioinformatics tool origins).
**Related:** **CZID-579** (EPIC: Internal Artifact Management + Tooling Cache, T1-T16) and
its design doc `ARTIFACT-MANAGEMENT-DISCOVERY-2026-07-08.md`; CZID-377 (wire seqtoid-web
npm through CodeArtifact); CZID-393 (reproducible-builds angle); CZID-23; the
fork-deps-as-private-repo pattern; the existing ECR BuildKit registry cache.

---

## 1. TL;DR

The platform pulls from a wide surface of public origins; any one going down,
rate-limiting, yanking, or being MITM-tampered can break a build or deploy (the mysql
`.deb` is still pulled over **plain HTTP**). We want a **single internal resolve endpoint
per dependency class** that proxies/caches the public origin under our control.

This spike **overlaps CZID-579**, which already selected and detailed a target
architecture. This doc's job is to record the **option comparison behind that choice** and
confirm the recommendation, so implementation (post-GA) proceeds from an explicit decision.

**Recommendation:** the **AWS-native, per-class hybrid** already blueprinted in CZID-579 --
- container images -> **Amazon ECR + ECR pull-through cache**,
- npm/pip/gems -> **AWS CodeArtifact** (single resolve endpoint, upstream proxies),
- raw binaries/.debs/tarballs -> **versioned S3 "tool-mirror"** with checksum verify,
- GitHub Actions -> **SHA-pin + private thorvath-slower mirrors**.

Not a single monolithic Artifactory/Nexus. The decision is Tom's.

---

## 2. Why "one source" (the problem)

From the CZID-579 dependency inventory:

- **Container bases** on `docker.io` / `ghcr` / `quay` / `public.ecr.aws` -- mix of
  digest-pinned and tag-only; docker.io pull limits.
- **~30 raw bio-tool downloads** (diamond, STAR, blast, kallisto, picard, samtools, ...)
  from GitHub releases, bitbucket, academic hosts (`unafold.org`, `opengene.org`,
  `drive5.com` -- some **HTTP**), NCBI/OSUOSL FTP, and public S3 buckets. Almost all
  **version-pinned but unverified at fetch** (no checksum).
- **mysql-community-client 5.7.42 `.deb`** over **`http://repo.mysql.com`** -- an active
  MITM hole; amd64-only.
- **Language deps** (npm/pip/gems) mostly lockfile-pinned (good) but resolving from the
  **public registries directly** -- an npm/PyPI/rubygems outage or yank stalls `npm ci` /
  `bundle install` / `pip install`.
- **GitHub Actions** partially SHA-pinned; federation-server pulls `chanzuckerberg/*@main`
  (a mutable upstream branch) 18+ times.

The intermittent build/job failures CZID-205 was filed against come from this surface.

---

## 3. Options (whole-platform "single source" strategies)

### Option 1 -- AWS-native per-class hybrid (ECR + CodeArtifact + S3) (RECOMMENDED)

Each dependency class maps to exactly one AWS-native store; nothing resolves from a public
origin directly. This is the CZID-579 target.

- **Images:** ECR with a **pull-through cache** rule per upstream registry (docker.io via
  Docker Hub creds, `public.ecr.aws`, ghcr, quay). First pull populates ECR; later builds
  pull from ECR even if upstream is down. The existing BuildKit registry cache (mode=max)
  and the `${BASE_REGISTRY}` FROM-hook (already in 3 Dockerfiles) are reused.
- **npm/pip/gems:** one **CodeArtifact** domain (`seqtoid`) with `npm-store` / `pypi-store`
  / `gems-store` repos, each with an **upstream proxy** to the public registry. Every
  resolved version is cached forever, so a yank/outage cannot break a rebuild; bad versions
  can be quarantined. CI points `.npmrc` / `PIP_INDEX_URL` / `bundle config mirror` at
  CodeArtifact. (CZID-377 already wires seqtoid-web npm through it.)
- **Raw binaries/.debs/tarballs:** a **versioned S3 "tool-mirror"** bucket (Object Lock),
  the canonical origin for node, chamber, samtools, the mysql `.deb`, and the ~30 bio-tools.
  Dockerfiles fetch from S3 over a VPC endpoint (no internet egress) and **verify sha256**.
- **GitHub Actions:** finish **SHA-pinning** + **private thorvath-slower mirrors** for the
  most-depended third-party actions.

- **Pros**
  - Builds on assets we already own (ECR, BuildKit cache, the FROM/NPM hooks, the private-
    fork pattern) -- "no new control plane."
  - In-account, durable, works with the private-network direction; VPC endpoints mean
    builds/runtime need no public egress.
  - Per-class fit: content-addressed package cache (CodeArtifact), digest-preserving image
    cache (ECR), and immutable versioned objects with per-tool rollback (S3) -- each store
    is the right tool for its class.
  - Aligns exactly with CZID-579's already-designed ingest-verify gate and per-component
    fallback model.
- **Cons**
  - Multiple services to stand up and own (three stores + IAM + VPC endpoints).
  - Not a single pane across image+package+binary; provenance/reporting spans three
    services.
  - CodeArtifact has per-request/token ergonomics (12h auth token) to wire into CI.

### Option 2 -- GitHub Packages / GHCR-centric

Use GitHub Packages (proxy+host for npm/gem/pypi/containers), GHCR for images, Actions
cache/artifacts for build outputs -- one platform, same as the code.

- **Pros**
  - Same platform as source + CI; integrated OIDC auth; minimal new infra.
  - GHCR already in the picture for some flows.
- **Cons**
  - **Retention/quota limits and egress on restore** -- weak as a durable archive; not a
    supply-chain vault.
  - Pulls the platform's dependency availability back under **GitHub** availability -- does
    not satisfy "independent of upstream" as well as in-account AWS stores, and runtime
    (EKS pods) pulling images from GHCR is against the private-network direction.
  - GitHub Packages' proxy coverage across all our ecosystems (esp. raw binaries / .debs /
    the ~30 bio-tools) is poor-to-nonexistent -- raw tools still need an S3-style mirror
    anyway, so this does not actually give "one source."

### Option 3 -- Self-hosted Artifactory / Nexus (single pane)

One self-hosted universal repository manager proxying every ecosystem (npm, pypi, gems,
docker, raw/generic, apt) behind a single URL.

- **Pros**
  - **True single source / single pane** across every class, including raw/generic and apt
    -- the cleanest fit to the literal CZID-205 ask.
  - Mature proxy/caching, retention, and RBAC; one place for provenance and policy.
- **Cons**
  - **A new control plane to run, patch, scale, secure, and back up** -- directly against
    the "no new control plane" preference; it becomes a critical-path SPOF we operate.
  - Licensing cost (Artifactory Pro; Nexus Pro for some features) or the ops burden of the
    OSS tiers.
  - Duplicates capabilities AWS already gives us in-account (ECR/CodeArtifact) with less
    native IAM/VPC integration.

### Option 4 -- Simple S3 + checksum mirror for everything

Skip managed proxies; mirror **every** dependency (packages included) into a versioned S3
bucket with published checksums, and repoint all resolvers at S3.

- **Pros**
  - One primitive (S3), maximal durability + object-lock immutability, cheapest to run,
    trivial to reason about; perfect for raw binaries (and it is the chosen store for that
    class in Option 1).
- **Cons**
  - S3 is **not a package index** -- it cannot serve npm/pip/gem/docker protocol semantics
    (dependency resolution, metadata, ranges). Making it do so means rebuilding a registry
    by hand (mirror scripts + index generation) for every ecosystem = large, brittle, and
    reinventing CodeArtifact/ECR.
  - No upstream-proxy "resolve-then-cache on first use" -- every needed version must be
    pre-mirrored, so first use of a new transitive dep fails until someone mirrors it.

---

## 4. Comparison

| Criterion | 1. AWS hybrid | 2. GitHub Pkgs | 3. Artifactory/Nexus | 4. S3-only |
|---|---|---|---|---|
| Covers all classes (img/pkg/raw/actions) | yes (per-class) | partial (raw weak) | **yes (one pane)** | raw only |
| Durability / archive | high (in-account) | medium (quota/egress) | high | **highest** |
| New control plane to operate | no (managed) | no | **yes (SPOF)** | no |
| Fits private-network direction | **yes (VPC endpoints)** | weak (GH egress) | self-managed | yes |
| Reuses what we already have | **most** (ECR/cache/hooks) | some | little | some |
| Auth model | AWS IAM/OIDC | GitHub OIDC | own RBAC | AWS IAM |
| Package resolution semantics | native (CodeArtifact) | native | native | **none (manual)** |
| Cost profile | pay-per-use AWS | quota/egress | license + ops | lowest |
| Effort to stand up | medium | low | high | medium-high |
| Alignment with CZID-579 design | **exact** | partial | divergent | partial (its raw tier) |

---

## 5. Recommendation

**Adopt Option 1 -- the AWS-native per-class hybrid** already designed in CZID-579:
ECR + pull-through cache for images, CodeArtifact for npm/pip/gems, versioned S3
tool-mirror + checksum for raw binaries, SHA-pin + private mirrors for Actions.

Why not the alternatives:
- **Option 3 (Artifactory/Nexus)** is the only literal "one URL for everything," but it
  introduces a new critical-path control plane we must run and secure -- the opposite of our
  "no new control plane" preference -- and duplicates ECR/CodeArtifact.
- **Option 2 (GitHub Packages)** is low-effort but ties dependency availability to GitHub,
  is weak for raw binaries (still needs an S3 mirror), and runtime image pulls from GHCR
  fight the private-network direction. Keep GHCR/Actions-cache only for GH-native build
  flows, not as the platform's dependency vault.
- **Option 4 (S3-only)** is right for the raw-binary class (and is Option 1's raw tier) but
  cannot serve package-registry semantics without rebuilding a registry.

"Single source" is best read as **one resolve endpoint per class, all in-account**, not one
server for all classes. Each Dockerfile `FROM`, `.npmrc`/pip/bundler config, and raw fetch
resolves from our store; a public outage/yank/MITM cannot stall a build.

### Sequencing (per CZID-579; POST-GA for the AWS applies)

- **Analysis now (this doc).** Implementation is **post-GA**.
- **Dev-actionable, no AWS apply (CZID-579 T1-T9):** add sha256 verify to raw fetches,
  HTTPS+GPG for the mysql `.deb`, digest-pin remaining bases, finish Actions SHA-pinning,
  author the ingest-verify reusable workflow, and extend the `${BASE_REGISTRY}`/`${NPM_REGISTRY}`
  hooks so the cutover is a config flip.
- **Authored-and-HELD AWS applies (T10-T16):** ECR pull-through cache, CodeArtifact domain,
  S3 tool-mirror + SSM + VPC endpoints, then flip dev over and prove a clean offline build;
  mirror to staging/prod as gated.

---

## 6. The decision Tom needs to make

1. **Endorse Option 1 (AWS-native per-class hybrid)** as the single-source strategy, or
   direct a different option (notably: is a single-pane Artifactory/Nexus wanted despite the
   control-plane cost?).
2. Confirm **post-GA** timing and that only the **dev-actionable, no-apply** hardening
   (CZID-579 T1-T9) may proceed before GA, with all AWS applies held.
3. Confirm this spike (CZID-205) is treated as **subsumed by CZID-579** -- i.e. close/park
   CZID-205 against the epic rather than run a parallel design.

No code or config is changed by this doc.
