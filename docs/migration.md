# Migration — Legacy `.pandoc` to `pandoc-pdf`

This guide describes how to migrate from locally coupled scripts to a reusable adoption of the toolkit.

## Goal of the migration

Move from pipelines hardcoded per repository to a declarative contract (`pdf.config.yaml`) + a versioned CLI (`pandoc-pdf`).

## Signals that you are in legacy mode

- Local legacy wrapper scripts with fixed paths (`chapters/`, `output/`, etc.).
- Lua filters coupled to specific folders.
- Manual dependency checks without a unified preflight.

## Recommended strategy (gradual)

### Phase 1 — Functional parity

1. Create `pdf.config.yaml` replicating the current behavior.
2. Adjust paths to declarative values (`project.base_dir`, `input`, `output`).
3. Run `pandoc-pdf doctor` and resolve dependencies.
4. Run `pandoc-pdf validate-config -c pdf.config.yaml`.
5. Run `pandoc-pdf render -c pdf.config.yaml` and compare the output with the legacy one.

### Phase 2 — Transition wrapper

Keep a local wrapper (for example `render-pdf.sh`) that internally invokes:

```bash
pandoc-pdf render -c pdf.config.yaml
```

This allows progressive adoption without breaking the team's habits.

### Phase 3 — Retiring the legacy

1. Remove path hardcodes from local scripts/filters.
2. Delegate validation to the `validate-config` command.
3. Consolidate documentation around the CLI (`doctor`, `validate-config`, `render`).

## Migration checklist

- [ ] `pdf.config.yaml` with `version` defined.
- [ ] Paths resolved from `project.base_dir`.
- [ ] Dependencies verified with `doctor`.
- [ ] Config validated against the schema.
- [ ] Render reproducible locally and in CI.
- [ ] Legacy wrapper documented (if applicable) and a retirement plan defined.

## Upgrading 1.1.x → 2.0.0

2.0.0 is a **major** release because defaults changed, not because the contract did: **no change to `pdf.config.yaml` is required**. The five affected fields were already required by the schema, none has been removed or renamed, and a valid 1.1.x configuration still validates. What changes is what the renderer does with it, and every section below says exactly what.

Behavior changes you can observe when upgrading:

- **`document.*` now reaches the template.** With `pandoc.metadata_file` empty, `title`, `subtitle`, `publisher`, `author`, `date` and `rights` are passed to pandoc as `-V` variables and fill the cover page. If your `templates/default.tex` (or your own template) expected those variables to be empty, the cover page changes: review the resulting PDF.
- **`input.order` only accepts `natural` or `alphabetical`.** Previously any value was ignored; now a different value fails in `render` with a message listing the accepted ones. Review the field in your configs.
- **`runtime.strict: false` makes `doctor` exit with exit 0** even when auxiliary dependencies are missing: it still prints them, but as warnings. The TeX engine is the exception and always fails. If your CI relied on the `doctor` exit code to detect incomplete environments, set `runtime.strict: true` (which is also the default).
- **`locale set --project` writes for the repository you are in.** It used to write `.pandoc-pdf.env` inside the toolkit installation, so every consuming repository shared one "project" locale. Run it from the repository you want to configure; an existing file in the old location is simply ignored now.

- **A render with a broken Mermaid no longer succeeds.** `mmdc` present but unable to launch a browser used to leave the diagrams as code blocks with exit 0; now `render` fails and names them, and `doctor` catches it first. Use `filters.mermaid.enabled: false` to drop diagrams on purpose.
- **`output.keep_merged_markdown: false` deletes the merged Markdown** after a successful render. If a later step of your pipeline read that `.md`, set it to `true` (default) or consume the PDF.
- **The Ruby renderer is removed** (see the section below).

Quick wins included in the same version:

- The error for a missing locale suggests `--project` (it previously mentioned `--team`, which does not exist).
- `--resource-path` is joined with the platform separator instead of a hardcoded `:`, so the path no longer breaks where the separator differs.
- The duplicate `filters/emoji/emoji_u*.svg` assets are gone; the renderer copies `2610/2611/2612.svg` on every run, so there is nothing to adjust for consumers.
- The release artifact no longer includes `scripts/__pycache__`.

### Removed configuration baseline

`defaults/default.yaml` no longer exists: the schema is the single source of truth and `render` does not merge any defaults file. If you validated your config, **you do not have to do anything** (the baseline keys were already required). If you invoked `scripts/render-native.*` directly with partial configs, declare the keys you expected to inherit; in particular `pandoc.resource_path` is no longer filled in for you.

`pandoc-pdf info` (and `info --json`) no longer shows `defaults_path` / `defaults_exists`.

### Emoji filter

`filters/emoji.lua` no longer rewraps text without emojis. If your minimal template did not load `graphicx` and `hyperref`, add them: they are needed for images and for headings with formatting. Before the change, any heading emitted `\\texorpdfstring` and the render failed even when there were no emojis.

## The default language is English (ships with 2.0.0)

Hyphenation and typographic conventions used to be Spanish by default, because
that was the language of the first consuming repository. They are English now.

If your documents are not in English, declare the language once:

```yaml
document:
  language: "es"
```

Supported values are `en`, `es`, `pt` and `gl`. Without this line, a Spanish
document hyphenates as English: the words still render, and the line breaks are
wrong in a way that is easy to miss and unpleasant to read.

## Output file names changed (ships with 2.0.0)

The PDF used to be named after `document.title`, spaces and accents included:
`Project Technical Documentation-20260101.pdf`. It is now a slug of
`output.file_prefix` when that field is set, and a slug of the title otherwise:
`project-technical-documentation-20260101.pdf`.

What to do if a script, a link or an index depends on the name:

1. Declare the name you want, without spaces: `output.file_prefix: "report"`
   produces `report-<suffix>.pdf`.
2. Or keep the slug of the title and update the reference.

Nothing else changes: the suffix, the directory and the merged Markdown follow
the same name.

## Removal of the Ruby renderer (ships with 2.0.0)

As of 2.0.0, `scripts/render-native.rb` no longer exists. The only renderer is `scripts/render-native.py`, which `pandoc-pdf render` always invokes.

- **You do not have to do anything** if you use the CLI (`pandoc-pdf render -c ...`).
- If you invoked the script directly, change the call to `python3 scripts/render-native.py <config> <toolkit_root> [--plan|--plan-json]` and keep a YAML parser available: PyYAML, or Ruby with stdlib YAML (the renderer uses it as a fallback).
- The JSON plan (`--dry-run --json`) keeps its shape: `plan_version` is still 1.

## Breaking change policy

If the migration requires a breaking change in CLI/contract/defaults:

1. Major version bump of the toolkit.
2. Explicit migration guide.
3. Update of reference examples.

## Common risks and mitigation

- **Risk:** output differs from the legacy pipeline.
  - **Mitigation:** parity by phases and comparison of artifacts.
- **Risk:** missing dependency in CI.
  - **Mitigation:** run `doctor` at the start of the pipeline.
- **Risk:** divergent configurations per repository.
  - **Mitigation:** versioned contract + schema validation + neutral examples.
