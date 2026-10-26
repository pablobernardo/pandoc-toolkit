# AGENTS.md — Pandoc PDF Toolkit

## Mission

Build and maintain an **agnostic, versioned, reusable** toolkit for producing
PDFs with Pandoc across multiple consuming repositories.

## Architectural goal

Standardise the flow behind a stable CLI (`pandoc-pdf`) plus declarative
configuration (`pdf.config.yaml`) per consuming repository, with no local
coupling.

## Scope

This file defines the **stable** rules of the project.

Changing state (current phase, recent decisions, open tasks) lives in
`CONTEXT.md`, so strategy and day-to-day operation do not mix.

## Language policy

- **The repository is written in English**: code, comments, commit messages,
  documentation, and the working notes in `CONTEXT.md` and `odd/`.
- **The only Spanish in the tree is product surface**: the message catalogs in
  `i18n/locales/`, where `es.json` is a translation like any other.
- User-facing strings never live in code. They come from the catalogs, so
  adding a language means adding a catalog, not editing scripts.
- `CHANGELOG.md` history is translated too, but it describes what existed at the
  time; it is a record, not current documentation.

## Out of scope

- This repository does **not** hold business documentation for any specific
  client or consuming repository.
- Examples with private data, internal names, or organisation-specific structure
  are not accepted.

## Non-negotiables

1. No hardcoded paths in scripts, filters, or templates.
2. Configuration compatibility per contract version (`version` is mandatory).
3. A CLI usable by humans, CI, and automated integrations.
4. Mandatory preflight before rendering (`doctor` / `preflight`).
5. Safe migration without breaking adoption by consuming repositories.
6. Documentation and examples with no client data and no private structure.

## Core toolkit structure (implemented)

- `bin/pandoc-pdf`
- `Makefile`
- `filters/emoji.lua`, `filters/mermaid.lua`, `filters/emoji/`
- `scripts/bootstrap.sh`, `scripts/install.sh`, `scripts/install-local.sh`,
  `scripts/package-release.sh`
- `scripts/preflight.sh`, `scripts/preflight.py`
- `scripts/validate-config.py`, `scripts/render-native.py`,
  `scripts/prepare-emojis.py`
- `scripts/i18n.sh`, `scripts/i18n_runtime.py`, `scripts/check-i18n.py`
- `scripts/enforce-security-thresholds.py`
- `schemas/pdf-config.schema.json`
- `examples/pdf.config.example.yaml`, `examples/metadata.yaml`
- `templates/default.tex`
- `i18n/locales/`, `i18n/schema/`
- `tests/run.sh`, `tests/lib.sh`, `tests/l1/<area>.sh`, `tests/fixtures/`,
  `tests/integration/`
- `.agents/skills/<name>/SKILL.md`

There is exactly one renderer (`scripts/render-native.py`). YAML is read with
PyYAML when available and otherwise through Ruby's stdlib in a subprocess.

## Planned additions (target)

- Windows support: gated by the migration triggers recorded in `CONTEXT.md`. It
  cannot break the current CLI contract, and the current bash entry point is the
  blocker, not the scripts.

## Configuration contract (`pdf.config.yaml`)

`schemas/pdf-config.schema.json` is the single source of truth; there is no
defaults baseline to merge. The validator implements an explicit JSON Schema
subset (`type`, `properties`, `required`, `additionalProperties`, `items`,
`minItems`, `minLength`, `minimum`, `enum`), and a test fails if the schema starts
using any other keyword.

Required sections:

- `version`
- `project`
- `document`
- `input`
- `output`
- `pandoc`
- `filters`
- `runtime`
- `compat`

## Expected CLI commands

- `pandoc-pdf --version` / `pandoc-pdf version`
- `pandoc-pdf info` / `pandoc-pdf info --json`
- `pandoc-pdf locale show`
- `pandoc-pdf locale set <lang>`
- `pandoc-pdf locale set --project <lang>`
- `pandoc-pdf update --check`
- `pandoc-pdf update`
- `pandoc-pdf update --to <tag>`
- `pandoc-pdf doctor [-c <file>]`
- `pandoc-pdf validate-config -c <file>`
- `pandoc-pdf render -c <file> [--dry-run] [--json]`

## Breaking change policy

Any breaking change in the CLI, the configuration contract, or default behaviour
requires:

1. a major toolkit version bump,
2. an explicit migration guide,
3. updated examples and reference configuration.

## Delivery criteria (definition of done)

- One working entry point (`pandoc-pdf`).
- Configuration validated against the JSON schema.
- Declarative paths, with no coupling to specific folders.
- Compatibility proven on at least two repositories with different structures.
- Migration documented for consumers.

## Work protocol

1. Structural changes first: contract and schema.
2. Then the CLI (`render`, `validate-config`, `doctor`).
3. Then parameterised filters and scripts.
4. Documentation of usage and migration last.

## Implementation gate (before coding)

Before writing code:

1. Confirm which part of the configuration contract is affected.
2. Assess backward-compatibility impact.
3. Define the minimum tests or validations that cover the change.
4. Only then implement.

## Where to update what

- Stable toolkit rules: `AGENTS.md`
- Current operational context: `CONTEXT.md`
- Architecture and trade-offs: `docs/architecture.md`
- CLI installation and integration: `docs/install.md`
- Examples for consumers: `examples/` and `docs/usage.md`
- Operational skills for agents: `.agents/skills/<name>/SKILL.md`, versioned and
  reviewed in pull requests

### Generated directories (not versioned)

- `.atl/` is gentle-ai local state: the skill registry and its cache are
  regenerated per machine and contain the user's absolute paths. It is
  gitignored; it is neither versioned nor reviewed.
