# templates/

Reference starter templates for new Terraform work. **Two ways to use them — pick what fits:**

| You want… | Use |
|---|---|
| A brand-new repo, pre-wired, with one click | The standalone **template repo**: [`thorvath-slower/terraform-template`](https://github.com/thorvath-slower/terraform-template) → "Use this template" (or `gh repo create <name> --template thorvath-slower/terraform-template`). Self-contained, has its own `validate` CI. |
| To copy a stack/layout into an existing repo, or just read the canonical shape | This mirror: **`templates/terraform-stack/`** (below). Copy the bits you need. |

> The standalone repo is the **canonical** source; `terraform-stack/` here is a kept-in-sync mirror for the copy-into-existing-repo case. Renovate keeps both current. If they ever diverge, the standalone repo wins.

## `terraform-stack/`
The canonical Terraform stack layout: `.terraform-version` (version SSOT), `_shared/versions.tf` (provider SSOT, symlinked into stacks), an example `envs/dev/example/` stack wired to the `czid-tfstate-<account>-<region>` state foundation, a `validate` workflow, and `renovate.json`. See `terraform-stack/README.md` for the full walkthrough.

The canonical **conventions** (how we work, Terraform usage, upgrade runbooks) live once in **[`docs/platform/`](../docs/platform/README.md)** — the templates only carry the minimal seed files and point here.
