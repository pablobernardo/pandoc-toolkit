# Architecture — Multi-Repository PDF Generator (Pandoc)

This document describes the toolkit **as built**. The design it originated from
was a proposal; since version 1.0.0 it is the implemented architecture, and
this file keeps it up to date with the code.

## Problem solved

The original pipeline (a local `.pandoc/` directory) worked but was coupled to
local conventions (`chapters/`, `output/`, fixed paths inside the Lua
filters). That made it hard to reuse in other repositories and to maintain at
scale.

The solution, implemented and published since v1.0.0, is a **versioned global
toolkit** with declarative configuration per consuming repository, with no
local coupling.

## Configuration contract (per repository)

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
  # Optional: without it the name is a slug of document.title.
  file_prefix: "report"
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

The schema requires `version`, `project`, `document`, `input`, `output`,
`pandoc`, `filters` and `runtime`. The `compat` section is optional; when absent,
`legacy_clearpage_between_h1` defaults to `true`.

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

## Toolkit structure (as built)

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
    check-docs.py
    check-plan-conformance.py
    enforce-security-thresholds.py
  schemas/
    pdf-config.schema.json
  i18n/
    locales/                 # en.json, es.json, gl.json, pt.json
    schema/
  examples/
    documentation/pdf.config.yaml
    manual/                  # config + chapters
    ohmyfake/                # config + chapters
    test/                    # config + chapters
    toPDF.sh
  docs/
    README.md                # navigation index
    install.md
    usage.md
    architecture.md
    releasing.md
    dependency-policy.md
    i18n.md
  tests/
    run.sh
    l1/
    integration/
```

### Principles

- **Stable core + config per repository.**
- **Semantic versioning** of the toolkit, independent of the configuration
  contract version.
- **No hardcoded paths** inside filters: every path arrives from the config,
  resolved against `project.base_dir`.
- **Explicit preflight** of dependencies before rendering (`doctor` /
  `preflight`).

## Render pipeline

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

`output.formats` selects an ordered list of artifacts (default `[pdf]`),
with duplicate formats rendered once. A single unique format retains the
version-1 plan: `pandoc.target` is `{markdown, pdf}` or `{markdown, epub}`.
Multiple formats use a version-2 envelope: `{"plan_version": 2, "jobs": [...]}`.
Each job is a full version-1 single-format plan, executed sequentially by the
same renderer. Preflight checks the union of requirements. Every job is
attempted; successful artifacts survive another job's failure, the overall
exit is nonzero on any failure, and intermediate Markdown is then retained.
There is no atomic multi-file transaction. Default PDF plans remain unchanged.

EPUB jobs omit TeX/template variables, use actual document metadata with
metadata-file precedence, and keep document.language authoritative. An
EPUB-only header overrides forced page breaks on initial headings without
replacing Pandoc's default CSS or affecting PDF. An existing cover image is
supported through `cover-image` in the metadata file or `document.metadata`;
Pandoc writes the image cover and keeps its typographic title page after it.
Relative assets resolve from `project.base_dir`, which every job appends last to
the resource path, and a relative `cover-image` is resolved the same way because
the EPUB writer reads the cover directly and ignores the resource path. No EPUB
plan carries `\clearpage`: the compatibility switch is a typesetting decision,
so it only applies to the PDF. Visual Apple Books acceptance is separate from
structural archive verification. The singular `output.format` was an unreleased
prototype and is replaced, not supported as a second alias; see
[migration](migration.md).

The plan is a conformance contract: four recorded cases in `tests/conformance/`
cover minimal settings, metadata precedence, explicit chapter order, and custom
templates/resources/filters. Run `python3 scripts/check-plan-conformance.py` to
compare normalized plans, or add `--update` to refresh expectations after an
intentional contract change. Set `PANDOC_PDF_BIN` to compare another implementation;
an optional positional root selects a different tree of cases and expectations.
Machine-local paths are normalized as documented in the checker's docstring;
object key order is ignored, but array order and all non-path values are checked.

## Portability and a possible binary implementation

The toolkit currently targets Linux and macOS. There is no Go migration planned;
the Bash entry point is the blocker for native Windows support, not a reason to
add another renderer today.

Reconsider a binary implementation if Windows becomes a real requirement, a
consumer cannot provide Python and a supported YAML parser, signed single-file
artifacts are needed, or maintaining the Bash updater costs more than a rewrite.

The frozen render plan and its conformance suite provide the comparison boundary
for a replacement implementation. Use `PANDOC_PDF_BIN` as described above rather
than defining a second rendering contract. Any migration must preserve the CLI
and configuration compatibility rules in `AGENTS.md`.

## Decision record

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

### Decisions taken during 2.0.0

| # | Decision |
| --- | --- |
| D1 | A single renderer (Python). Ruby stays only as an optional YAML parser in a subprocess; removing it entirely would require making PyYAML mandatory, and that was decided **against**. |
| D2 | `runtime.strict: false` waives auxiliary dependencies, never the TeX engine: without an engine there is no PDF, so it always fails. |
| D3 | `validate-config` rejects a missing `pandoc.metadata_file` and validates `input.order` against its `enum`. The validator implements a documented JSON Schema subset and a test fails if the schema uses any other keyword. |
| D4 | Shell i18n unified in `scripts/i18n.sh`: catalog loaded once, no fork per message, one precedence chain for both entry points. |
| D5 | Metadata precedence: when `pandoc.metadata_file` is set it wins and no `-V` variables are passed; when empty, the `document.*` fields become template variables. |
| D6 | The plan shape (`plan_version: 1`) is frozen as is: `cwd: null` (inherited), `env` with the toolkit's four variables, and `prepare_argv[0]` as the neutral `python3` token. Any shape change requires `plan_version: 2`. |
| D7 | `defaults/default.yaml` removed: the schema is the single source of truth. |
| D8 | Release postponed during the work and cut as **2.0.0**: a major release, because the output file name, the default typesetting language and the update path changed. Creating the tag triggers `release.yml`, a path no pull request exercises. |
| D9 | The repository is English, including this file and `odd/`; only the catalogs are translated. |
| D10 | Every action is pinned to a commit SHA with its tag in a comment. Dependabot tracks the `github-actions` ecosystem weekly, so the pins do not rot; a tag is a mutable pointer, and these workflows handle the token that publishes releases. |
| D11 | `mermaid-cli` is a **tested** version, not an enforced one: 10.9.1 is what the toolkit installs and CI renders with, any other version is accepted when `doctor` renders its test diagram, and this repository never pins a user's system-wide install. See `docs/dependency-policy.md`. |
| D12 | `pandoc.metadata_file` is optional: the legacy side file stays supported and wins when present, but a configuration can now carry the cover through `document.*`, plus `document.language`, `document.titlepage` and a free-form `document.metadata` map. The file name still comes from `document.title`, so no consumer's output is renamed. |
| D13 | Relative assets resolve from `project.base_dir`, never from the directory the command was invoked in. Every job appends `base_dir` **last** to the pandoc resource path, so a declared `pandoc.resource_path` keeps its priority and existing resolution is only widened. A relative `cover-image` is resolved against `base_dir` before Pandoc sees it, because the EPUB writer opens the cover directly and ignores the resource path. The plan keeps `cwd: null` as D6 requires: this is a resolution rule, not a plan shape change. No EPUB plan carries the generated `\clearpage`, which is LaTeX-only markup. |

## How we got here

The original three-phase migration plan was executed:

1. **Harden locally** — routes in `emoji.lua` and `mermaid.lua` were
   parameterised (read from metadata/vars), emoji preparation was consolidated
   in `scripts/prepare-emojis.py`, and preflight was completed.
2. **Extract the toolkit** — scripts, filters and templates moved to this
   repository and published by tag (v1.0.0 onwards). Each consuming repository
   keeps a `pdf.config.yaml` and invokes the toolkit through `bin/pandoc-pdf`.
3. **Reuse across repositories** — the toolkit is consumed by tag/version;
   per-repository customisation is limited to `pdf.config.yaml` plus an
   optional template. The toolkit and configuration contract are versioned
   independently; breaking changes follow the policy in `AGENTS.md`.

## Production criteria — what must keep holding

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
- [x] Consumer installation and CLI use documented (`docs/install.md`,
      `docs/usage.md`); future breaking changes require an explicit migration
      guide under `AGENTS.md`.
