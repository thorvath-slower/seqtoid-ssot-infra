# Reproducible builds -- preserve dependencies + toolchain (CZID-393)

**Status:** OPTIONS doc -- evaluate GitHub vs AWS, then implement (post-GA). No code/config
change.
**Goal:** guarantee we can **always rebuild every repo** with the exact dependencies AND
tools, independent of upstream availability (npm/RubyGems/PyPI/Docker Hub outages, yanks,
deleted packages, rate limits, moved images).
**Related:** **CZID-205** (single FOSS source -- the "one endpoint" angle) and its options
doc `FOSS-DEPENDENCY-SOURCE-OPTIONS.md`; **CZID-579** (EPIC: Internal Artifact Management +
Tooling Cache, T1-T16, design in `ARTIFACT-MANAGEMENT-DISCOVERY-2026-07-08.md`); CZID-377
(CodeArtifact npm); the fork-deps-as-private-repo pattern; the build-versioning ticket.

---

## 1. TL;DR and how this differs from CZID-205

CZID-205 asks "**one source** every build pulls from." This ticket (CZID-393) asks the
**reproducibility guarantee**: given only our stores + git, can we **rebuild any repo,
byte-for-byte, offline** even if every upstream vanished? The single-source store is the
*vehicle*; reproducibility adds two more requirements on top of it:

1. **Digest/lockfile pinning discipline** -- every input pinned by content hash, not a
   movable tag/range, so "the same commit builds the same bytes."
2. **Toolchain capture** -- ruby/node/tofu/helm/aws-cli/go and OS bases mirrored and pinned,
   not just referenced, so the *tools* are as reproducible as the deps.

**Recommendation:** **AWS-native durable stores as the archive of record**
(ECR + S3 + CodeArtifact retention), **GitHub for GH-native build ergonomics only**
(Actions cache is a *speed* cache, not the archive), plus **strict digest-pinning across
all input types** and a CI **"can we build offline from our mirrors?"** gate. This is the
reproducibility view of the CZID-579 architecture. The decision is Tom's.

---

## 2. What reproducibility requires (gap vs today)

From the CZID-579 inventory, current pinning is uneven:

| Input type | Today | Reproducibility gap |
|---|---|---|
| Language deps (npm/pip/gems) | mostly lockfile-pinned | pip is `==` without hash-mode; workflow-infra pip has fuzzy `~=`; resolves from public registries (yank breaks rebuild) |
| Container bases | mix digest / tag-only | seqtoid-web `ruby:3.3.6-slim` runtime, `python:3.8`, `node:18`, `ubuntu:*` are **tag-only** (mutable) |
| Raw binaries / .debs / tarballs | version-pinned, **unverified** | ~30 bio-tools + node/chamber/samtools no checksum; **mysql `.deb` over HTTP**; `blast LATEST` unpinned |
| GitHub Actions | partially SHA-pinned | first-party `actions/*` tag-pinned; federation `chanzuckerberg/*@main` (mutable branch) x18 |
| Toolchain (ruby/node/tofu/helm/aws-cli/go) | version-declared, upstream-fetched | not mirrored -- an upstream outage blocks the build even if deps are cached |

Reproducibility = close all five: pin every input by content, and mirror both deps **and**
tools into durable stores we own.

---

## 3. Options

### Option A -- GitHub-native (Packages + Actions cache + Artifacts)

Preserve build inputs on GitHub: GitHub Packages (npm/gem/pypi/containers proxy+host),
Actions cache for restored deps, build Artifacts for outputs; retention configured up.

- **Pros**
  - Same platform as code + CI; integrated OIDC auth; least new infra.
  - Actions cache makes warm rebuilds fast; Artifacts capture per-run outputs.
- **Cons**
  - **Retention/quota limits and egress-on-restore** -- Actions cache evicts (7-day idle /
    10 GB per repo) and Artifacts expire; it is a **speed cache, not a durable archive**.
  - Ties long-term reproducibility to **GitHub availability** -- fails the "independent of
    upstream" bar (GitHub is itself an upstream here).
  - Weak/absent coverage for raw binaries, `.debs`, and the ~30 bio-tools -- the least
    reproducible surface stays unaddressed.
  - Not aligned with the private-network / in-account direction for runtime image pulls.

### Option B -- AWS-native durable archive (ECR + CodeArtifact + S3) (RECOMMENDED core)

Make in-account AWS stores the archive of record: **ECR** (+ pull-through cache, immutable
digests) for images, **CodeArtifact** (retains every resolved package version) for
npm/pip/gems, **versioned S3 + Object Lock** for raw binaries **and the toolchain**
(ruby/node/tofu/helm/aws-cli/go installers, OS base tarballs), all checksum-verified.

- **Pros**
  - **Durable, immutable, in-account** -- Object Lock + versioning + ECR immutable tags give
    a real archive, not an evictable cache; survives any upstream deletion/yank/outage.
  - CodeArtifact **keeps prior versions indefinitely** -> a yanked package is still
    resolvable -> the same lockfile rebuilds.
  - Covers the **toolchain**, not just deps -- the S3 tool-mirror holds the installers, so
    `terraform init` / a ruby/node bootstrap is offline-safe too.
  - Same stores as CZID-205 Option 1 and the CZID-579 design -- one build-out serves both
    "single source" and "reproducibility."
  - VPC endpoints -> offline-from-public rebuild is literally testable.
- **Cons**
  - Multiple services + IAM + VPC endpoints to stand up and own.
  - AWS applies -> staging/prod gated; more infra than Option A.

### Option C -- Hybrid: AWS durable archive + GitHub for GH-native flows (RECOMMENDED overall)

Option B is the **archive of record**; GitHub Actions cache/artifacts are kept purely as a
**build-speed** layer and for GH-native ephemeral outputs. GH Actions themselves are
preserved via **SHA-pin + private thorvath-slower mirrors** (already our pattern for cztack).

- **Pros**
  - Best of both: AWS durability for the guarantee, GitHub ergonomics/speed where they help,
    private mirrors make the *actions* immune to upstream tag-move/deletion.
  - Matches the CZID-579 phasing exactly (dev-actionable hardening now; AWS applies held).
- **Cons**
  - Two planes to reason about; must keep the boundary explicit ("GH cache is disposable;
    AWS is the archive") so nobody treats Actions cache as durable.

### Cross-cutting (required under ANY option) -- pinning + toolchain + offline gate

Independent of where things are stored, reproducibility needs:

- **Digest/lockfile pinning by content:** base images by `@sha256:` (fix the tag-only
  bases), npm/bundler locks kept, **pip hash-checking mode** enabled, `~=` tightened to
  `==`, `.terraform.lock.hcl` committed with provider hashes, **all raw binaries sha256-
  verified** (extend the one existing rustup `sha256sum -c` pattern), `blast LATEST` pinned.
- **Toolchain capture:** ruby/node/tofu/helm/aws-cli/go versions **mirrored** (not just
  declared) into the S3 tool-mirror, pinned by checksum.
- **Fork critical GH Actions to private repos**, pinned by SHA (federation
  `chanzuckerberg/*@main` is the priority).
- **CI "offline rebuild" check:** a job that builds with public egress blocked, resolving
  only from our mirrors -- the executable proof that reproducibility holds. This is the
  acceptance test for the whole effort.

---

## 4. Comparison

| Criterion | A. GitHub-native | B. AWS-native | C. Hybrid |
|---|---|---|---|
| Durable archive (survives upstream deletion) | **no** (cache/quota) | **yes** | **yes** |
| Independent of upstream availability | weak (GH is upstream) | strong | strong |
| Covers raw binaries + toolchain | poor | **yes** | **yes** |
| Package prior-version retention | limited | **yes (CodeArtifact)** | yes |
| Build speed (warm cache) | **best** | good (ECR/CA cache) | **best** (keeps GH cache) |
| New infra to own | least | most | medium |
| Offline-rebuild provable | no | **yes (VPC endpoints)** | **yes** |
| Fits private-network direction | weak | **yes** | yes |
| Alignment with CZID-579 / CZID-205 | partial | exact | **exact** |

---

## 5. Recommendation

**Adopt Option C (hybrid):** AWS-native durable stores (Option B: ECR + CodeArtifact + S3,
with the **toolchain** mirrored to S3) as the **archive of record**, GitHub Actions
cache/artifacts kept only as a disposable **speed** layer, and GH Actions preserved via
**SHA-pin + private mirrors**. Layer the **cross-cutting pinning + toolchain-capture +
offline-rebuild CI gate** on top -- these are mandatory and are what turn "single source"
(CZID-205) into "reproducible" (CZID-393).

Keep CZID-393 and CZID-205 consistent: **same stores, same phasing, one build-out.**
CZID-205 answers "*where do deps resolve from*"; CZID-393 adds "*pinned by content + tools
mirrored + provably offline-rebuildable.*" Neither should be implemented separately.

### Sequencing (per CZID-579; POST-GA for AWS applies)

- **Analysis now.** Implementation **post-GA**.
- **Dev-actionable, no apply (CZID-579 T1-T9 subset most relevant here):** sha256-verify all
  raw fetches (T1), HTTPS+GPG mysql `.deb` (T2), **digest-pin the tag-only bases** (T3),
  finish Actions SHA-pinning (T4) + private-mirror federation's `@main` (T5), pin `blast
  LATEST` (T6), enable pip hash-mode + tighten fuzzy pins. Add the **offline-rebuild CI
  check** as the acceptance gate.
- **Authored-and-HELD AWS applies (T10-T16):** ECR pull-through, CodeArtifact, S3 tool-mirror
  (incl. toolchain installers) + Object Lock; then run the offline-rebuild gate against the
  mirrors in dev; mirror to staging/prod as gated.

---

## 6. The decision Tom needs to make

1. **Endorse Option C** (AWS durable archive of record + GitHub for speed/native flows), or
   direct GitHub-native (A) / pure AWS (B).
2. Confirm the **toolchain** (ruby/node/tofu/helm/aws-cli/go + OS bases) is mirrored to S3
   as a first-class requirement, not just the language/binary deps.
3. Approve the **"offline rebuild from our mirrors" CI gate** as the acceptance test for
   reproducibility (block-on-fail once the mirrors exist).
4. Confirm **post-GA** timing, dev-only hardening before GA, all AWS applies held, and that
   CZID-393 is executed **jointly with CZID-205 under CZID-579** (not as a separate build-out).

No code or config is changed by this doc.
