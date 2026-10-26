# Single-source config defaults (P4)

Branch `feature/config-contract-alignment`. Work landed in PR #11, squash `9cb7211`; the landed record is in `CHANGELOG.md`. Removes `defaults/default.yaml` so that `schemas/pdf-config.schema.json` becomes the single source of truth of the contract: today the schema requires the 9 sections and `render` validates the user's config, so the baseline is unreachable through the validated path.

## Specs

**S1 — Authorization (translated from Spanish)**
> do what you recommend

**S2 — Applied decision (translated from the accepted recommendation)**
> My recommendation is **(b)** for this toolkit: a single place to read the contract from, and the consumer already has `examples/pdf.config.example.yaml` as a starting template.

**S3 — The baseline disappears**
`defaults/default.yaml` is removed from the repository and from the distribution tree. No runtime reads it: not the renderers, not `package-release.sh`, not `install-local.sh`.

**S4 — No hidden defaults in the renderer**
A config that omits a key receives no value from the toolkit: the renderer only applies the historical code fallbacks (engine `xelatex`, `toc` on, `templates/default.tex`, etc.). In particular, without `pandoc.resource_path` no `--resource-path` is emitted. The valid contract is the one the schema validates.

**S5 — `pandoc-pdf info` stops advertising the baseline**
`defaults_path` / `defaults_exists` are removed from the text output and from `info --json`, because the file no longer exists. Documented as an output change.

**S6 — No behavior loss in valid configs**
Every config that passes `validate-config` today renders the same: the keys the baseline supplied are required by the schema, so the user already declares them. The previous suite (210 assertions) must stay green except for the ones testing the baseline itself.

**S7 — Documentation and trail**
`docs/usage.md`, `docs/architecture.md` (tree), `docs/migration.md`, `CHANGELOG.md` and `CONTEXT.md` reflect the removal and what to do if a consumer depended on the baseline.

## Tasks

| ID | S# | Task | Path | Status | Commit |
| --- | --- | --- | --- | --- | --- |
| T1 | S3-S4 | Tests: no baseline and no hidden defaults | inline | pending | pending |
| T2 | S3-S4 | Remove the merge from both renderers and delete `defaults/` | inline | pending | pending |
| T3 | S3-S5 | `package-release.sh`, `install-local.sh`, `info` | inline | pending | pending |
| T4 | S7 | Docs, CHANGELOG, migration, CONTEXT | inline | pending | pending |

## Log

**L1 — Request (translated from Spanish)**
> do what you recommend

**L2 — Evidence of the inconsistency**
- `schemas/pdf-config.schema.json` requires 9 sections and `runtime.required_commands`, `pandoc.resource_path`, `output.keep_merged_markdown`, `compat.legacy_clearpage_between_h1`, etc.
- `bin/pandoc-pdf render` runs `validate-config` against the **user's** config before rendering.
- The only test that exercised the merge (`run_render_defaults_merge_test`) called `render-native.rb` directly, bypassing the CLI: it was the proof that the baseline was unreachable through the supported path.
- Valid configs: the baseline never contributed anything, because the schema already forces those keys to be declared. A config without `pandoc.resource_path` fails validation, so the baseline's `[chapters]` default was dead code.

**L3 — Scope of the change**
- Renderers: `deep_merge` and the baseline load are gone (`deepcopy` is no longer used).
- `bin/pandoc-pdf info`: `defaults_path`/`defaults_exists` are gone (text and `--json`).
- `scripts/package-release.sh` and `scripts/install-local.sh`: the directory copy is gone.
- `defaults/default.yaml`: deleted (5 weeks of history in git if we ever need to go back).
