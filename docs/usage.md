# Usage — Pandoc PDF Toolkit

This guide explains how to consume the toolkit from any repository.

> Before you start: see `docs/install.md` to get `pandoc-pdf` on your PATH.

## 1) Minimum requirements

- `pandoc`
- a TeX engine compatible with your template (for example `xelatex`)
- `python3`
- a YAML parser available (`PyYAML` or Ruby's stdlib YAML)
- `curl`
- `mmdc` (if you use the Mermaid filter)

> Recommendation: always run `pandoc-pdf doctor` before `render`.

## 1.1) Examples in this repository

Each example is runnable and demonstrates a different corner of the contract, so
together they cover it instead of repeating it:

| Example | What it shows |
| --- | --- |
| `examples/ohmyfake/` | Defaults: `glob` plus `order: natural`, `toc_depth: 2`, a cover built from `document.*`, merged Markdown kept, the name as a slug of the title |
| `examples/manual/` | The other branch: `input.explicit_files`, `toc_depth: 3`, `keep_merged_markdown: false`, an explicit `file_prefix` and `document.metadata` |
| `examples/test/` | The smallest valid configuration, with `titlepage: false` to show the cover switch |

`examples/toPDF.sh` renders all three. The content is original and released under
CC0: it is there to exercise the toolkit, not to be read as product documentation.

## 2) Configuration contract

Each consumer repository defines its own `pdf.config.yaml`.

There is no hidden baseline: the contract is exactly what `schemas/pdf-config.schema.json` validates. The toolkit does not merge any defaults file, so everything the render needs is declared in your `pdf.config.yaml`. Use `examples/ohmyfake/pdf.config.yaml` as a starting template.

The only values the renderer applies on its own are historical in-code fallbacks for missing keys (engine `xelatex`, TOC enabled, template `templates/default.tex`); a valid config does not depend on them because the schema forces those keys to be declared.

Expected minimum fields:

- `version`
- `project`
- `document`
- `input`
- `output`
- `pandoc`
- `filters`
- `runtime`
- `compat`

### 2.1) Semantics of the declarative fields

These fields are required in `schemas/pdf-config.schema.json` and the runtime actually applies them. When they are missing, the renderer and the preflight use the defaults listed below (which match `examples/ohmyfake/pdf.config.yaml`).

`input.order` — chapter ordering:

- `natural`: compares numeric runs as numbers, so `chapter-2.md` comes before `chapter-10.md`.
- `alphabetical`: lexicographic order by file name.
- Any other value is rejected in `render` with a localized message listing the accepted values (`natural`, `alphabetical`); it does not sort silently.
- It only applies when `input.explicit_files` is empty: an explicit list is respected as-is.

`output.keep_merged_markdown` — fate of the merged Markdown:

- `true` (default): keeps the intermediate `.md` next to the PDF.
- `false`: deletes it after a successful pandoc render. If pandoc fails, the `.md` is kept for diagnosis.

`document.*` — metadata and cover page:

- With `pandoc.metadata_file` empty, the non-empty `title`, `subtitle`, `publisher`, `author`, `date` and `rights` fields are passed to pandoc as template variables (`-V field=value`) and fill the cover page of `templates/default.tex`.
- With `pandoc.metadata_file` set, they are **not** passed: the metadata file takes precedence (see `docs/architecture.md` §2, rule 4 «Contract rules»).
- The output file name is a **slug**: `output.file_prefix` when declared, otherwise `document.title`. Lowercase, ASCII, dashes; accents are transliterated (`Informe Ñandú` becomes `informe-nandu`), so a name never needs quoting and can never escape the output directory.
- `pandoc.metadata_file` is **optional**: without it, `document.*` is what reaches the template, so a project needs no side YAML file.
- `document.language` (`en`, `es`, `pt`, `gl`) selects the babel language and applies even when a metadata file provides the cover. The default is the Spanish the template used to hardcode.
- `document.titlepage` enables or disables the cover. It is a typesetting decision, so it also applies with a metadata file.
- `document.metadata` is a free-form map of scalar keys (`keywords`, `subject`, any template variable), passed only when no metadata file wins.

`filters.emoji.include_ballot_icons` — Markdown task checkboxes:

- `true` (default): `☐` (U+2610), `☑` (U+2611) and `☒` (U+2612) are replaced with their image from the emoji set.
- `false`: they are left as characters, without replacement.

`runtime.strict` — preflight severity:

- `true` (default): `doctor` fails with exit 1 if a command from `runtime.required_commands` or the TeX engine is missing.
- `false`: it reports them as warnings and exits with exit 0, **except the TeX engine**: without it there is no PDF, so its absence always fails even when `strict` is `false`.

## 3) CLI commands

Optional `make` shortcuts:

```bash
make doctor
make validate CONFIG=pdf.config.yaml
make render CONFIG=pdf.config.yaml
make bootstrap-yes
make bootstrap-ci
```

Check the CLI version:

```bash
pandoc-pdf --version
```

Show toolkit environment information:

```bash
pandoc-pdf info
pandoc-pdf info --json
```

Manage the CLI locale:

```bash
pandoc-pdf locale show
pandoc-pdf locale set es
pandoc-pdf locale set pt
pandoc-pdf locale set gl
pandoc-pdf locale set --project es
```

Currently supported locales: `en`, `es`, `pt`, `gl`.

`locale set <lang>` saves the global language in `~/.config/pandoc-pdf/config.env` (or `XDG_CONFIG_HOME/pandoc-pdf/config.env`) so it applies by default in future runs.

`locale set --project <lang>` writes `.pandoc-pdf.env` in the directory you run it from, so each consuming repository keeps its own language. The CLI looks for that file from the current directory upwards, which means running it from a subdirectory still finds the repository's setting. `PANDOC_PDF_PROJECT_ENV` overrides the path when you need it.

Check whether there is a new stable version of the toolkit:

```bash
pandoc-pdf update --check
pandoc-pdf update
pandoc-pdf update --to v1.2.3
```

`update --check` reports the local version, the latest stable version and whether an update is available.

`update` installs the latest stable version for the current platform.

`update --to <tag>` installs a specific version (for example `v1.2.3`).

Layout managed by the updater:

- Toolkit versions under `~/.local/share/pandoc-pdf/versions/<tag>/`
- Active pointer at `~/.local/share/pandoc-pdf/current`
- Entrypoint at `~/.local/bin/pandoc-pdf`

Notes:

- `pandoc-pdf-dev` is reserved for local development and **does not allow** installation with `update`.
- You can customize the managed root with `PANDOC_PDF_UPDATE_HOME`.

Useful flags:

- `--yes`: skips the interactive confirmation.
- `--dry-run`: shows the plan without writing to disk.
- `--install-dir <path>`: sets the installation path.

For private GitHub repositories, export a token before running update:

```bash
export PANDOC_PDF_UPDATE_TOKEN=<your_token>
# or alternatively
export GH_TOKEN=<your_token>
```

Validate the environment and dependencies:

```bash
pandoc-pdf doctor
```

Validate the configuration:

```bash
pandoc-pdf validate-config -c pdf.config.yaml
```

`validate-config` applies strict contract validation (required, types and disallowed fields), aligned with `schemas/pdf-config.schema.json`, plus functional validation of critical paths (`input.chapters_dir`, `pandoc.template`, `pandoc.metadata_file` when set, `filters.extra_lua_filters`). `input.order` is additionally validated against its `enum`: a value other than `natural` or `alphabetical` is rejected here, before it reaches the render.

The validator implements an explicit subset of JSON Schema (`type`, `properties`, `required`, `additionalProperties`, `items`, `minItems`, `minLength`, `minimum`, `enum`). A test fails if the schema starts using any other keyword, so one can never be silently ignored.

`pandoc.template` is optional: if it is not set, the render uses `templates/default.tex`.

Render the PDF:

```bash
pandoc-pdf render -c pdf.config.yaml
```

Inspect the render plan without executing anything:

```bash
pandoc-pdf render -c pdf.config.yaml --dry-run
pandoc-pdf render -c pdf.config.yaml --dry-run --json
```

`--dry-run` prints the human-readable plan (chapters in effective order, merged markdown, output PDF and the pandoc invocation) and **writes nothing**: it creates no directories, generates no merged markdown, prepares no emojis and invokes no pandoc.

`--dry-run --json` emits the same plan as JSON on stdout (the validation banner goes to stderr, so stdout stays clean) with this shape:

```json
{
  "plan_version": 1,
  "toolkit": { "version": "1.2.0", "root": "/path/toolkit" },
  "config": { "path": "/path/pdf.config.yaml", "base_dir": "/path/project" },
  "chapters": ["/path/project/chapters/chapter-2.md"],
  "pandoc": {
    "target": { "markdown": "...", "pdf": "..." },
    "argv": ["pandoc", "..."],
    "cwd": null
  },
  "env": {
    "PANDOC_EMOJI_DIR": "...",
    "PANDOC_EMOJI_BALLOT_ICONS": "1",
    "PANDOC_MERMAID_OUTPUT_DIR": "...",
    "PANDOC_MERMAID_BACKGROUND": "transparent"
  },
  "side_effects": {
    "keep_merged_markdown": true,
    "clearpage_between_h1": true,
    "emoji": { "enabled": true, "dir": "...", "missing_svg": "...", "prepare_argv": ["python3", "..."] },
    "mermaid": { "enabled": true, "dir": "...", "background": "transparent" }
  }
}
```

The plan is the verifiable contract of the render: it is what makes it possible to compare render implementations without reading code, and it is the foundation for a future conformance suite.

## 4) Recommended flow

1. Prepare/update `pdf.config.yaml`.
2. Run `doctor` to check dependencies.
3. Run `validate-config` to catch contract errors.
4. Run `render`.
5. Run `update --check` periodically to review new stable versions.

## 5) Conventions for consumer repositories

- Resolve relative paths against `project.base_dir`.
- Avoid hardcodes in local wrappers.
- Keep style overrides in your own templates, not in the core.

## 6) Quick troubleshooting

- `doctor` fails: install the missing dependencies before retrying.
- `validate-config` fails: fix required fields / the YAML structure.
- `render` fails with Mermaid: `mmdc` is on PATH but cannot launch a browser. `mermaid-cli` needs a Chromium that Puppeteer can find, and its own download is separate from the npm package. `pandoc-pdf doctor` renders a test diagram and reports the exact fix:
  - install the browser Puppeteer expects: `npx puppeteer browsers install chrome-headless-shell`;
  - or point it at a browser you already have: `export PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"`.
  A dropped diagram is not ignored: the merged markdown keeps the code block, `render` reports which diagrams failed and exits non-zero. To drop diagrams on purpose, set `filters.mermaid.enabled: false`. See `docs/install.md` for which of the two browser options to use and what not to hardcode.

## 6.1) Configuration security

- Do not run `render` or `doctor -c` with a `pdf.config.yaml` from an untrusted source.
- Pay special attention to `runtime.required_commands` and `filters.extra_lua_filters`.
- See the security policy in `.github/SECURITY.md`.

## 7) CI integration

Suggested sequence:

1. `pandoc-pdf doctor`
2. `pandoc-pdf validate-config -c pdf.config.yaml`
3. `pandoc-pdf render -c pdf.config.yaml`

If `runtime.strict: true` (default), any missing dependency must fail the pipeline.

With `runtime.strict: false`, `doctor` downgrades missing dependencies to warnings: it still prints them and exits with exit 0. The only exception is the TeX engine: its absence always fails, because without it the PDF cannot be generated. Use it only in pipelines where the auxiliary dependency is resolved later (for example an image that installs it in a subsequent step).

## 8) OpenCode integration (agents)

So that models use it consistently:

1. Make sure the OpenCode process has `pandoc-pdf` on PATH.
2. State in the repository instructions that the official entrypoint is `pandoc-pdf`.
3. Recommended sequence for agents:
   - `pandoc-pdf doctor`
   - `pandoc-pdf validate-config -c pdf.config.yaml`
   - `pandoc-pdf render -c pdf.config.yaml`
4. For structural toolkit changes, use the local skill:
   - `.agents/skills/pandoc-toolkit-maintainer/SKILL.md`

## 9) CLI tests

Current smoke/contract test suite:

```bash
tests/run.sh
```

Local integration runners:

```bash
bash tests/l2-local.sh
bash tests/l3-local.sh
```

Notes:
- `l2-local.sh` runs semi-real integration (without the full Mermaid stack).
- `l3-local.sh` requires `mmdc` and Chromium (`PUPPETEER_EXECUTABLE_PATH` if it is not auto-detected).

Current suite coverage:

- help and unknown-command handling
- `doctor` in an OK scenario and with a missing dependency
- `validate-config` with a valid and an invalid case
- `render -c` in native mode (checks output/environment)
- explicit rejection of legacy flags (`--legacy`)
- advanced render integration (extra_lua_filters, resource_path, optional metadata)
- render errors for non-existent `explicit_files`
- render plan: valid JSON, no side effects, readable `--dry-run`
- emoji filter: plain headings do not emit `\\texorpdfstring`
- contract behavior (since 1.2.0):
  - `input.order` with `natural` and `alphabetical` values, and rejection of an unsupported value naming the field and the supported values
  - `output.keep_merged_markdown` set to `false` (deletes the `.md`) and `true` (keeps it), with a PDF produced in both cases
  - `document.*` reaches pandoc as `-V` variables, and a `pandoc.metadata_file` takes precedence over them
  - `include_ballot_icons` toggles `PANDOC_EMOJI_BALLOT_ICONS` between `1` and `0`
  - `runtime.strict` set to `false` (warning, exit 0) and `true` (failure)
- release artifact: the generated package contains no Python bytecode (`__pycache__`, `.pyc`)
- locale message with no destination: names `--project`, not `--team`

In addition, this suite runs automatically in CI (GitHub Actions) for PR/push on a macOS/Linux matrix as **L1**.

CI levels:

- **L1 (fast, mandatory on PR/push):** `tests/run.sh`.
- **L2 (semi-real, manual):** real render on Ubuntu against integration fixtures.
- **L3 (full, manual or scheduled):** integration with the extended stack (includes the Mermaid CLI).
  - includes a real Mermaid fixture in `tests/integration/l3-mermaid-project/`.

Workflow and manual inputs:

- Workflow: `.github/workflows/ci.yml`
- `run_render_integration=true` to run **L2**
- `run_render_full=true` to run **L3**

Run from the CLI:

```bash
gh workflow run ci.yml -f run_render_integration=true
# or
gh workflow run ci.yml -f run_render_full=true
```
