# Usage — Skelepress

This guide explains how to consume the toolkit from any repository.

> Before you start: see `docs/install.md` to get `skelepress` on your PATH.

## Minimum requirements

- `pandoc`
- a TeX engine compatible with your template (for example `xelatex`)
- `python3`
- a YAML parser available (`PyYAML` or Ruby's stdlib YAML)
- `curl`
- `mmdc` (if you use the Mermaid filter)

> Recommendation: always run `skelepress doctor` before `render`.

## Examples in this repository

Each example is runnable and demonstrates a different corner of the contract, so
together they cover it instead of repeating it:

| Example | What it shows |
| --- | --- |
| `examples/ohmyfake/` | Defaults: `glob` plus `order: natural`, `toc_depth: 2`, a cover built from `document.*`, merged Markdown kept, the name as a slug of the title |
| `examples/manual/` | The other branch: `input.explicit_files`, `toc_depth: 3`, `keep_merged_markdown: false`, an explicit `file_prefix` and `document.metadata` |
| `examples/no-titlepage/` | The smallest valid configuration, rendered in both formats, with `titlepage: false`: the document opens on the table of contents instead of a typeset title page |
| `examples/documentation/` | The toolkit's own documentation: an explicit reading order over the six top-level guides in `docs/` (excluding the navigation README), with `base_dir` at the repository root, no filters and a numbered table of contents |
| `examples/book-kit/` | One tool, two book shapes: a single-volume project without `series.yaml` and a two-volume series with it, sharing series defaults with per-volume overrides, a `chapter_start` that continues the chapter numbering across volumes, and generated mode files (`\mainmatter`, `\appendix`) so the content files carry no LaTeX markers. Built by the shipped tool `scripts/tools/bookkit/build.py` through the `skelepress book` subcommand |

`examples/toPDF.sh` renders every example: the four configuration-driven ones
(`ohmyfake`, `manual`, `no-titlepage` and `documentation`) through
`skelepress render`,
and the book example through `skelepress book`, because its volumes are declared
as manifests rather than as a configuration. The
content examples (`ohmyfake`, `manual`, `no-titlepage` and `book-kit`) are
original and released under CC0: they exercise the toolkit rather than serve
as product documentation. The `documentation` example renders the repository
documentation, which is MIT licensed.

### Command help

`skelepress help`, `skelepress -h` and `skelepress --help` show the command
summary, purpose descriptions and how to discover more detail. For book inputs,
options and examples, run `skelepress book --help` (or `skelepress book -h`).
Book help follows `SKELEPRESS_LANG` or the process locale; its existing options
and argument forwarding are unchanged. Other command details are documented in
this guide; not every command accepts its own `--help` flag.

Book inputs can be one or more volume directories with `manifest.yaml` or series
directories with `series.yaml`. `--check` validates and emits configurations
without rendering. By default, output goes to `.skelepress` relative to the
working directory and the template is the builtin `book`; `--out` and
`--template` override them.

### Books

A book is the same renderer with a `book`-class template and, when the volumes
are declared as manifests, one configuration per volume. The whole story —
manifests, the volume layout, `skelepress book`, the fields that shape a book,
the cover image and how the contents is separated — is
[`books.md`](books.md).

In short:

```bash
skelepress book --check examples/book-kit/single   # validate and emit the configurations
skelepress book --out ../.output examples/book-kit/single examples/book-kit/series
```

The field reference for a manifest lives with the tool, in
[`scripts/tools/bookkit/README.md`](https://github.com/pablobernardo/skelepress/blob/main/scripts/tools/bookkit/README.md).

## Configuration contract

Each consumer repository defines its own `skelepress.config.yaml`.

There is no hidden baseline: the contract is exactly what `schemas/skelepress-config.schema.json` validates. The toolkit does not merge any defaults file, so everything the render needs is declared in your `skelepress.config.yaml`. Use `examples/ohmyfake/skelepress.config.yaml` as a starting template.

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

`compat` is optional; its default is listed below.

### Semantics of the declarative fields

These fields are required in `schemas/skelepress-config.schema.json` and the runtime actually applies them. When they are missing, the renderer and the preflight use the defaults listed below (which match `examples/ohmyfake/skelepress.config.yaml`).

`input.order` — chapter ordering:

- `natural`: compares numeric runs as numbers, so `chapter-2.md` comes before `chapter-10.md`.
- `alphabetical`: lexicographic order by file name.
- Any other value is rejected in `render` with a localized message listing the accepted values (`natural`, `alphabetical`); it does not sort silently.
- It only applies when `input.explicit_files` is empty: an explicit list is respected as-is.

Cross-references between chapters — `[migration](migration.md)`:

- Chapters become sections of one document, so a link to another selected chapter file is rewritten to an internal anchor instead of pointing at a file the publication does not contain. It works in the PDF and in the EPUB, where the link resolves to the right spine document.
- Only the chapters something actually links to get an anchor, and a project with no cross-references produces exactly the same merged Markdown as before.
- A link to a file that is not part of the selection is left as written, and a fenced code block is never rewritten, so a chapter documenting the link syntax keeps its example.

`output.keep_merged_markdown` — fate of the merged Markdown:

- `true` (default): keeps the intermediate `.md` next to the PDF.
- `false`: deletes it only after all requested formats succeed. If any format fails, the `.md` is kept for diagnosis.

`output.formats` — what the renderer produces:

```yaml
output:
  # Keep your other output fields.
  formats: [pdf, epub]
```

- Omitted, or `[pdf]`: the typeset PDF described in the rest of this guide.
- `[epub]`: an EPUB3 publication with the same base name and an `.epub` suffix.
- `[pdf, epub]` (or the reverse order): both files in one invocation. Formats run in declared order; repeated formats run only once.
- The list must be nonempty and contain only `pdf` and `epub`. The unreleased singular `format` field is rejected; replace `format: epub` with `formats: [epub]`.
- Preflight checks the union of requirements before rendering: any selection containing PDF requires its TeX engine. Explicit `runtime.required_commands` always apply.
- After preflight, all formats are attempted even if one fails. Successful files are retained; any failure returns exit 1 and identifies the failed format. This is not an atomic multi-file transaction.
- EPUB is assembled by pandoc, not typeset, so **no TeX engine is required**: `doctor` stops demanding one for these configurations, while every command declared in `runtime.required_commands` is still enforced. `pandoc.pdf_engine` and `pandoc.template` are PDF-only and are not applied.
- `--dry-run --json` keeps the existing version-1 plan for one unique format. Multiple formats use `{"plan_version": 2, "jobs": [...]}` with ordered version-1 jobs. Each job names its own artifact (`pdf` or `epub`); an EPUB command carries no engine, template, LaTeX-only variable or generated `\clearpage`.
- EPUB keeps Pandoc's default content styling and split chapters, but overrides the forced page break on each document's initial heading (including title and navigation). This targets redundant blank pages in Apple Books; reader acceptance remains a manual check.
- The internal EPUB title page has a centered, reflowable typographic layout: title/subtitle, separated credits, and smaller rights text. Spacing scales with text size; reader fonts and colors remain selectable. This is not an image cover and does not change PDF styling.
- EPUB tables use normal table layout, not horizontal scroll containers, so readers can paginate them. Long cell text and code keys may wrap within columns. PDF tables are unchanged; actual reader pagination still requires manual acceptance.
- EPUB uses real metadata: title, author and the other document text fields reach the publication, or `pandoc.metadata_file` takes precedence when configured. `document.language` remains authoritative in either case. PDF template variables and the cover switch remain PDF-only.
- An **existing** cover image is supported through `cover-image` in the metadata file, or through `document.metadata` when no file is configured. Nothing generates a cover. In the EPUB, Pandoc writes the image cover first and keeps its typographic title page after it, so a reader opens on the image and then shows the text page. The PDF prints the same image page; see `cover-image` under `document.*` below.
- Relative assets resolve from `project.base_dir`, which every render appends **last** to the resource path: a declared `pandoc.resource_path` keeps its priority, and a project-relative image resolves no matter which directory you run the command from. A relative `cover-image` is resolved by the renderer against `base_dir` for **both** formats, because neither Pandoc's EPUB writer nor LaTeX's `\includegraphics` reads the pandoc resource path.
- The emoji filter works in EPUB with one deliberate difference: an emoji inside a **heading** stays a character, while emoji in paragraph text still becomes an SVG image. The navigation document reuses headings, and EPUB requires a link to contain text, so an image there is invalid; Pandoc also writes its path relative to the text directory, which escapes the package from the navigation root. A reader renders emoji natively, so nothing is lost, and PDF output keeps its images. Mermaid diagrams are embedded as PNG resources either way.
- Ballot-box emojis come from the versioned `filters/emoji/` directory; other emojis are fetched once by the emoji preparation step.
- A diagram is embedded with the configured `filters.mermaid.background`. The PNG is cached by diagram content, not by background, so changing that setting only affects diagrams that were not rendered before. With the default `transparent`, a diagram can be hard to read in a reader's dark mode.
- No EPUB carries LaTeX-only markup: the `\clearpage` inserted between chapters for the PDF is never added to an EPUB, whatever `compat.legacy_clearpage_between_h1` says.

`document.*` — metadata and cover page:

- With `pandoc.metadata_file` empty, the non-empty `title`, `subtitle`, `publisher`, `author`, `date` and `rights` fields are passed to pandoc as template variables (`-V field=value`) and fill the cover page of `templates/default.tex`.
- With `pandoc.metadata_file` set, they are **not** passed: the metadata file takes precedence (see 'Contract rules' in `docs/architecture.md`).
- The output file name is a **slug**: `output.file_prefix` when declared, otherwise `document.title`. Lowercase, ASCII, dashes; accents are transliterated (`Informe Ñandú` becomes `informe-nandu`), so a name never needs quoting and can never escape the output directory.
- `pandoc.metadata_file` is **optional**: without it, `document.*` is what reaches the template, so a project needs no side YAML file.
- `document.language` (`en`, `es`, `pt`, `gl`) selects the babel language and applies even when a metadata file provides the cover. The default is **English**.
- `document.titlepage` enables or disables the **typeset title page**. It is a typesetting decision, so it also applies with a metadata file. It does not affect the image cover page: a cover is not a title page, and a document that suppresses the typeset page usually still wants its cover.
- `cover-image` declares an **image cover page** for the PDF. Write it in the metadata file or in `document.metadata` (the same key the EPUB already reads — no new configuration field): `cover-image: "assets/cover.png"`. The shipped templates print the image on a full-bleed page **before** the typographic title page, scaled to fit the sheet with `keepaspectratio` through a `\newgeometry`/`\restoregeometry` pair, and the page prints even with `titlepage: false`. A relative path resolves against `project.base_dir`; an absolute path is left as declared. Without the key, nothing changes.
- `document.metadata` is a free-form map of scalar keys (`keywords`, `subject`, any template variable), passed only when no metadata file wins.

`filters.emoji.include_ballot_icons` — Markdown task checkboxes:

- `true` (default): `☐` (U+2610), `☑` (U+2611) and `☒` (U+2612) are replaced with their image from the emoji set.
- `false`: they are left as characters, without replacement.

`runtime.strict` — preflight severity:

- `true` (default): `doctor` fails with exit 1 if a command from `runtime.required_commands` or the TeX engine is missing.
- `false`: it reports them as warnings and exits with exit 0, **except the TeX engine**: without it there is no PDF, so its absence always fails even when `strict` is `false`.

### Optional settings and their defaults

A setting is required only when something reads it. These are optional, and the
renderer applies the value in the middle column when they are absent:

| Setting | Default | Matters when |
| --- | --- | --- |
| `compat` (whole section) | `legacy_clearpage_between_h1: true` | you want different page-break behaviour |
| `filters.emoji.emoji_dir` | `output/emoji` under `project.base_dir` | the emoji filter is enabled |
| `filters.emoji.include_ballot_icons` | `true` | the emoji filter is enabled |
| `filters.mermaid.output_dir` | `output/mermaid` under `project.base_dir` | the mermaid filter is enabled |
| `filters.mermaid.background` | `transparent` | the mermaid filter is enabled |
| `pandoc.metadata_file` | absent: `document.*` reaches the template | always |
| `pandoc.top_level_division` | absent: Pandoc's own choice | the template typesets top-level headings differently from Pandoc's default |
| `output.file_prefix` | a slug of `document.title` | always |
| `output.formats` | `[pdf]` | you want EPUB or multiple formats |

A filter that is disabled does not need its settings: `enabled: false` is a
complete declaration. That is why the documentation example, which renders no
diagrams and no emoji, says only that both filters are off.

## CLI commands

Optional `make` shortcuts:

```bash
make doctor
make validate CONFIG=skelepress.config.yaml
make render CONFIG=skelepress.config.yaml
make bootstrap-yes
make bootstrap-ci
```

Check the CLI version:

```bash
skelepress --version
```

Show toolkit environment information:

```bash
skelepress info
skelepress info --json
```

Manage the CLI locale:

```bash
skelepress locale show
skelepress locale set es
skelepress locale set pt
skelepress locale set gl
skelepress locale set --project es
```

Currently supported locales: `en`, `es`, `pt`, `gl`.

`locale set <lang>` saves the global language in `~/.config/skelepress/config.env` (or `XDG_CONFIG_HOME/skelepress/config.env`) so it applies by default in future runs.

`locale set --project <lang>` writes `.skelepress.env` in the directory you run it from, so each consuming repository keeps its own language. The CLI looks for that file from the current directory upwards, which means running it from a subdirectory still finds the repository's setting. `SKELEPRESS_PROJECT_ENV` overrides the path when you need it.

Check whether there is a new stable version of the toolkit:

```bash
skelepress update --check
skelepress update
skelepress update --to v1.2.3
skelepress update --install-dir <path>
```

`update --check` reports the local version, the latest stable version and whether an update is available.

`update` installs the latest stable version for the current platform.

`update --to <tag>` installs a specific version (for example `v1.2.3`).

Layout managed by the updater (default paths):

- Toolkit versions under `~/.local/share/skelepress/versions/<tag>/`
- Active pointer at `~/.local/share/skelepress/current`
- Entrypoint at `~/.local/bin/skelepress`

Notes:

- `skelepress-dev` is reserved for local development and **does not allow** installation with `update`.
- The managed root comes from `SKELEPRESS_UPDATE_HOME`, then `SKELEPRESS_INSTALL_HOME` (the variable `install.sh` and `make install-local` already honour), then `~/.local/share/skelepress`.
- The binary directory comes from `--install-dir`, then `SKELEPRESS_INSTALL_DIR`, then the directory of the `skelepress` found on `PATH` when it is writable, then `~/.local/bin`. A declared location beats the `PATH` heuristic: the updater never relocates an installation that declared where it lives.

Useful flags:

- `--yes`: skips the interactive confirmation.
- `--dry-run`: shows the plan without writing to disk.
- `--install-dir <path>`: writes the entrypoint symlink into `<path>`. It does **not** move the managed root, which comes from `SKELEPRESS_UPDATE_HOME` or `SKELEPRESS_INSTALL_HOME` (default `~/.local/share/skelepress`); an isolated run needs the binary directory **and** the managed root declared, or the update acts on the real installation.

No token is needed: the update reads the public release metadata and downloads the
asset from the public release URL. Anonymous requests to the GitHub API are limited
to **60 per hour per address**, which a check uses one of.

If `update` reports that quota as exhausted, wait for it to reset. A private mirror
of the releases is not supported by this updater.

Validate the environment and dependencies:

```bash
skelepress doctor
```

Validate the configuration:

```bash
skelepress validate-config -c skelepress.config.yaml
```

`validate-config` applies strict contract validation (required, types and disallowed fields), aligned with `schemas/skelepress-config.schema.json`, plus functional validation of critical paths (`input.chapters_dir`, `pandoc.template`, `pandoc.metadata_file` when set, `filters.extra_lua_filters`). `input.order` is additionally validated against its `enum`: a value other than `natural` or `alphabetical` is rejected here, before it reaches the render.

The validator implements an explicit subset of JSON Schema (`type`, `properties`, `required`, `additionalProperties`, `items`, `minItems`, `minLength`, `minimum`, `enum`, `anyOf`), shared with the bookkit tool through `scripts/runtime/schema_runtime.py`. A test fails if the schema starts using any other keyword, so one can never be silently ignored.

`pandoc.template` is optional. Omitted, the render uses the toolkit's `templates/default.tex`. A **bare name — no path separator and no dot — selects a template that ships with the toolkit**: `book` resolves to `templates/book.tex`, which travels in the artifact, so the same configuration works in a checkout and in an installation. An unknown bare name fails naming the valid ones instead of being read as a path; anything else is a path resolved against `project.base_dir`.

`pandoc.top_level_division` is optional and **PDF-only**. It maps one to one to Pandoc's own `--top-level-division` flag, so a top-level Markdown heading becomes the LaTeX command you name: `section` (Pandoc's default), `chapter` or `part`. `default` and an absent field pass no flag at all, so existing configurations keep Pandoc's behaviour. Any other value is rejected by `validate-config` naming the four valid ones.

**`default` is not equivalent to `chapter`.** It is `chapter` that makes the `book` class typeset a top-level heading as `\chapter` — the one that prints "Chapter 1" and lists the entry in the contents with a chapter number. `default` only lets Pandoc infer the division from the class, which does not guarantee a `\chapter`: a template that expects chapters must say `top_level_division: chapter` explicitly, the way `templates/book.tex` relies on the value the bookkit adapter emits.

Templates that expect chapters — the builtin `book` — pair with `top_level_division: chapter`; `templates/book.tex` relies on that and defines no heading commands of its own. The valid values, the error message and how a value becomes an argument live in one shared module (`scripts/runtime/top_level_division_runtime.py`), so `validate-config` and the renderer cannot disagree.

Render the PDF:

```bash
skelepress render -c skelepress.config.yaml
```

Inspect the render plan without executing anything:

```bash
skelepress render -c skelepress.config.yaml --dry-run
skelepress render -c skelepress.config.yaml --dry-run --json
```

`--dry-run` prints the human-readable plan (chapters in effective order, merged markdown, output PDF and the pandoc invocation) and **writes nothing**: it creates no directories, generates no merged markdown, prepares no emojis and invokes no pandoc.

`--dry-run --json` emits the same plan as JSON on stdout (the validation banner goes to stderr, so stdout stays clean) with this shape:

```json
{
  "plan_version": 1,
  "toolkit": { "version": "2.0.0", "root": "/path/toolkit" },
  "config": { "path": "/path/skelepress.config.yaml", "base_dir": "/path/project" },
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

## Recommended flow

1. Prepare/update `skelepress.config.yaml`.
2. Run `doctor` to check dependencies.
3. Run `validate-config` to catch contract errors.
4. Run `render`.
5. Run `update --check` periodically to review new stable versions.

## Conventions for consumer repositories

- Resolve relative paths against `project.base_dir`.
- Avoid hardcodes in local wrappers.
- Keep style overrides in your own templates, not in the core.

## Quick troubleshooting

- `doctor` fails: install the missing dependencies before retrying.
- `validate-config` fails: fix required fields / the YAML structure.
- **Code that will not wrap.** Both highlighted and untagged fenced blocks wrap
  at spaces and after `/`, `.`, `,` and `=`, rather than between arbitrary letters.
  Inline code has break opportunities after `/`, `.` and `=`. A single identifier
  wider than the available space can still overflow; it is not split at `_` or
  `-`. PDF text extraction can introduce line breaks, so check copied commands
  before running them.
- **Words split across lines.** The default template disables automatic syllable
  hyphenation in prose: a word such as `because` moves whole to the next line.
- **Headings at the bottom of a page.** The default template reserves space for
  headings and the start of their content, moving them to the next page when
  needed. This covers H1–H5, including H4/H5's paragraph-style headings. Pandoc's
  LaTeX writer emits H6 as plain text, not as a section heading; it does not get
  the same protection. To exercise page boundaries with prose, consecutive
  headings, lists, tables and code, run
  `python3 tests/integration/check-heading-pagination.py` (requires Pandoc,
  XeLaTeX and `pdftotext`). The review PDF stays under `examples/.output/`.
- **Symbols like ☐ ☑ ☒ ✅ ❌ ⚠ are blank in the PDF.** The default prose and mono
  faces do not contain those glyphs. The template maps exactly those six, and
  only those six, to GNU FreeSerif when it exists, in prose, inline code,
  untagged fenced code and highlighted fenced code: prose and code stay in
  their usual fonts, code remains textual, and the fallback does not depend on
  the emoji filter. The symbols appear as monochrome text glyphs, not as
  color emoji. Install the font to get them (Debian/Ubuntu:
  `fonts-freefont-ttf`; TeX Live/MacTeX normally ship it); without it — or
  without the `newunicodechar` package — the PDF degrades to the previous
  behavior and keeps the Missing-character warnings. Text extraction keeps the
  base symbols but not the invisible presentation selector: an input `⚠️`
  extracts as `⚠`.
- `render` fails with Mermaid: `mmdc` is on PATH but cannot launch a browser. `mermaid-cli` needs a Chromium that Puppeteer can find, and its own download is separate from the npm package. `skelepress doctor` renders a test diagram and reports the exact fix:
  - install the browser Puppeteer expects: `npx puppeteer browsers install chrome-headless-shell`;
  - or point it at a browser you already have: `export PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"`.
  A dropped diagram is not ignored: the merged markdown keeps the code block, `render` reports which diagrams failed and exits non-zero. To drop diagrams on purpose, set `filters.mermaid.enabled: false`. See `docs/install.md` for which of the two browser options to use and what not to hardcode.

## Configuration security

- Do not run `render` or `doctor -c` with a `skelepress.config.yaml` from an untrusted source.
- Pay special attention to `runtime.required_commands` and `filters.extra_lua_filters`.
- See the security policy in `.github/SECURITY.md`.

## CI integration

Suggested sequence:

1. `skelepress doctor`
2. `skelepress validate-config -c skelepress.config.yaml`
3. `skelepress render -c skelepress.config.yaml`

If `runtime.strict: true` (default), any missing dependency must fail the pipeline.

With `runtime.strict: false`, `doctor` downgrades missing dependencies to warnings: it still prints them and exits with exit 0. The only exception is the TeX engine: its absence always fails, because without it the PDF cannot be generated. Use it only in pipelines where the auxiliary dependency is resolved later (for example an image that installs it in a subsequent step).

## CLI tests and CI levels

How the suite is organised, what each level covers and how to trigger L2 or L3 by
hand are in `CONTRIBUTING.md`: it is material for whoever changes the toolkit, not
for whoever uses it.
