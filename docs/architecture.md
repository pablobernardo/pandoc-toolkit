# Architecture — Multi-Repository PDF Generator (Pandoc)

This document describes the toolkit **as built**. The design it originated from
was a proposal; since version 1.0.0 it is the implemented architecture, and
this file keeps it up to date with the code.

## 1) Problem solved

The original pipeline (a local `.pandoc/` directory) worked but was coupled to
local conventions (`chapters/`, `output/`, fixed paths inside the Lua
filters). That made it hard to reuse in other repositories and to maintain at
scale.

The solution, implemented and published since v1.0.0, is a **versioned global
toolkit** with declarative configuration per consuming repository, with no
local coupling.

## 2) Configuration contract (per repository)

Each consuming repository keeps a `pdf.config.yaml` file. The single source of
truth for the contract is `schemas/pdf-config.schema.json`; there is no
defaults baseline to merge. The example below mirrors
`examples/ohmyfake/pdf.config.yaml`:

```yaml
version: 1

project:
  name: sample-project
  base_dir: .

document:
  title: "Project Technical Documentation"
  subtitle: "Compliance and Operations"
  publisher: "ACME Corp"
  author: "Engineering Team"
  date: "2026-04-21"
  rights: "Internal Use"
  language: "en"
  titlepage: true
  metadata:
    keywords: "compliance, operations"

input:
  chapters_dir: "chapters"
  glob: "*.md"
  order: natural
  explicit_files: []

output:
  dir: "output"
  suffix: "${date:YYYYMMDD}"
  keep_merged_markdown: true

pandoc:
  pdf_engine: xelatex
  toc: true
  toc_depth: 2
  number_sections: true
  template: "templates/default.tex"
  metadata_file: "metadata.yaml"
  resource_path:
    - "chapters"
    - "chapters/media"
    - "output/emoji"

filters:
  emoji:
    enabled: true
    emoji_dir: "output/emoji"
    include_ballot_icons: true
  mermaid:
    enabled: true
    output_dir: "output/mermaid"
    background: transparent
  extra_lua_filters: []

runtime:
  required_commands:
    - pandoc
    - python3
    - curl
    - mmdc
  strict: true

compat:
  legacy_clearpage_between_h1: true
```

All nine sections (`version`, `project`, `document`, `input`, `output`,
`pandoc`, `filters`, `runtime`, `compat`) are required by the schema.

### Contract rules

1. **`version` is mandatory**, so the contract can evolve without breaking
   older repositories.
2. Paths resolve against `project.base_dir` (which itself resolves relative to
   the config file's directory).
3. If `explicit_files` is not empty, it takes priority over `glob`.
4. If `pandoc.metadata_file` is set and exists, it takes priority over the
   `document.*` fields; otherwise `document.*` values are passed as pandoc
   variables. `document.language` and `document.titlepage` are typesetting
   decisions and apply either way.
5. Filters (`emoji`, `mermaid`) can be disabled per document via their
   `enabled` flags.

### Example conventions in this toolkit

- Use neutral names (`sample-project`, `ACME Corp`).
- Avoid client- or repository-specific paths and naming.
- Keep examples reproducible on any standard structure.

## 3) Toolkit structure (as built)

```text
pandoc-toolkit/
  bin/
    pandoc-pdf               # main CLI
  templates/
    default.tex
  filters/
    emoji.lua
    emoji/
    mermaid.lua
  scripts/
    bootstrap.sh
    install.sh
    install-local.sh
    package-release.sh
    preflight.sh
    preflight.py
    validate-config.py
    render-native.py         # the single renderer
    prepare-emojis.py
    i18n.sh
    i18n_runtime.py
    check-i18n.py
    enforce-security-thresholds.py
  schemas/
    pdf-config.schema.json
  i18n/
    locales/                 # en.json, es.json, gl.json, pt.json
    schema/
  examples/
    pdf.config.example.yaml
    metadata.yaml
  docs/
    install.md
    usage.md
    migration.md
    ...
  tests/
    run.sh
    l1/
    integration/
```

### Principles

- **Stable core + config per repository.**
- **Semantic versioning** of the toolkit (`v1.x`).
- **No hardcoded paths** inside filters: every path arrives from the config,
  resolved against `project.base_dir`.
- **Explicit preflight** of dependencies before rendering (`doctor` /
  `preflight`).

## 4) Render pipeline

There is exactly one renderer: `scripts/render-native.py`. YAML is read with
PyYAML when available and otherwise through Ruby's stdlib in a subprocess.

`pandoc-pdf render -c <config>` validates the config against the schema and
renders. There is no `defaults/default.yaml` and no baseline merge: the schema
is the only source of truth, and the renderer applies only its historical
code-level fallbacks for absent keys.

`pandoc-pdf render -c <config> --dry-run [--json]` computes a pure plan
(nothing is written or created) with `plan_version: 1`, containing the
selected chapters, output targets, the exact pandoc `argv`, and the filter
environment. `scripts/render-native.py` is split into `build_plan` (pure),
`execute_plan` (the single point with side effects) and `print_plan`.

The plan is a conformance contract: four recorded cases in `tests/conformance/`
cover minimal settings, metadata precedence, explicit chapter order, and custom
templates/resources/filters. Run `python3 scripts/check-plan-conformance.py` to
compare normalized plans, or add `--update` to refresh expectations after an
intentional contract change. Set `PANDOC_PDF_BIN` to compare another implementation;
an optional positional root selects a different tree of cases and expectations.
Machine-local paths are normalized as documented in the checker's docstring;
object key order is ignored, but array order and all non-path values are checked.

## 5) Migration (executed plan)

The original three-phase migration plan was executed:

1. **Harden locally** — routes in `emoji.lua` and `mermaid.lua` were
   parameterised (read from metadata/vars), emoji preparation was consolidated
   in `scripts/prepare-emojis.py`, and preflight was completed.
2. **Extract the toolkit** — scripts, filters and templates moved to this
   repository and published by tag (v1.0.0 onwards). Each consuming repository
   keeps a `pdf.config.yaml` and invokes the toolkit through `bin/pandoc-pdf`.
3. **Reuse across repositories** — the toolkit is consumed by tag/version;
   per-repository customisation is limited to `pdf.config.yaml` plus an
   optional template, and breaking changes are governed by the `version` of
   the config contract (see `docs/migration.md`).

## 6) Decision record

### Option A — Global toolkit (CHOSEN AND IMPLEMENTED)
- ✅ Better maintainability and scalability
- ✅ Upgrades controlled by version
- ⚠️ Required designing the config contract up front (done: see
  `schemas/pdf-config.schema.json`)

### Option B — Git submodule of `.pandoc` (rejected)
- ✅ Fast to implement
- ⚠️ Operational friction in teams
- ⚠️ Less flexibility for fine-grained overrides

### Option C — Copy per repository (rejected)
- ✅ Low initial cost
- ❌ Guaranteed technical drift
- ❌ High future maintenance cost

## 7) Production criteria — what must keep holding

These were the "definition of done" criteria for 1.0.0. They now act as
invariants that future changes must preserve:

- [x] A single entry point (`bin/pandoc-pdf`).
- [x] Config validated against the JSON schema (`pandoc-pdf validate-config`,
      enforced by `render` before every run).
- [x] 100% declarative paths (no hardcoded paths in scripts, filters or
      templates).
- [ ] Compatibility proven in at least two repositories with different
      structures. The test suite covers three integration fixtures with
      different structures (`tests/integration/minimal-project/`,
      `tests/integration/enabled-filters-project/`,
      `tests/integration/l3-mermaid-project/`), and this criterion is stated
      in `AGENTS.md` as a delivery criterion, but adoption by external
      consuming repositories cannot be verified from this repository alone.
- [x] Migration and legacy fallback documented (`docs/migration.md`).
