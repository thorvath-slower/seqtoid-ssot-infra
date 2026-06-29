# CZ ID Platform — Management & Maintenance Guide

This is the operator's guide to the CZ ID platform **after the modernization overhaul**. It is written so that an engineer new to the project can run, manage, and maintain the system from these docs alone — no tribal knowledge required.

> **Status:** v1 (started 2026-06-18, CZID-206). Living document — expand as the platform changes.

## Who this is for
- Engineers maintaining the platform day-to-day (the primary audience).
- New joiners who need a mental model + concrete procedures.
- Anyone making a change to infrastructure, dependencies, or CI.

## Read in this order
1. **[01 — Platform overview](01-platform-overview.md)** — the repos, what each does, how they fit together.
2. **[02 — Working conventions](02-working-conventions.md)** — governance, forks, PRs, the Linear lifecycle, Bucket A vs B. **Read before making any change.**
3. **[03 — Terraform / IaC](03-terraform-iac.md)** — how we run infrastructure-as-code, the state foundation, accounts/envs, validate→plan→apply.
4. **[04 — Dependencies & versions](04-dependencies-and-versions.md)** — the single-source-of-truth (SSOT) model and how we upgrade anything.
5. **[05 — Runbooks](05-runbooks.md)** — copy-paste procedures for the common maintenance tasks.
6. **[06 — Local validation](06-local-validation.md)** — how to test changes locally before pushing (CI is the final gate, not the dev loop).
7. **[07 — Functional change inventory](07-functional-change-inventory.md)** — everything the overhaul changed, by area, with ticket references.

## The five rules you must never break
1. **Push and open PRs only to `thorvath-slower/*` forks.** Never to `jsims-slower`, `chanzuckerberg`, `IT-Academic-Research-Services`, or any other upstream. (See [02](02-working-conventions.md).)
2. **One ticket → one branch → one PR, single concern.** If a change needs an "and also", split it.
3. **Document the outcome on the ticket (root cause + PR + validation) before marking it Done.**
4. **Every tool/runtime version is pinned once in a version file; CI reads the file, never hardcodes it.** (SSOT — see [04](04-dependencies-and-versions.md).)
5. **Never downgrade a dependency to dodge a conflict — pull the toolchain forward and file a ticket.**

## Glossary
- **SSOT** — Single Source Of Truth: a version/value defined in exactly one place that everything else reads.
- **State foundation** — the bootstrapped S3 backend (`czid-tfstate-<account>-<region>`) that holds all Terraform state. Lives in `czid-infra`.
- **Bucket A / Bucket B** — work that can be done in this dev environment (A) vs. work that needs live AWS / admin / credentials (B). See [02](02-working-conventions.md).
- **Component / stack** — one independently-applied unit of Terraform (e.g. `envs/dev/db`).
