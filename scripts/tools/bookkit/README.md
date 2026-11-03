# bookkit — build books with the pandoc-pdf toolkit

`scripts/tools/bookkit/build.py` turns declarative book manifests into
standard `pdf.config.yaml` files and renders them through the public
`pandoc-pdf` CLI. It is a shipped, versioned tool: a consuming repository
uses it as-is instead of writing its own adapter, and the book format it
reads is governed by this tool's own contract, not by `pdf.config.yaml`.

## The model

A **book project** is a directory that is one of two shapes:

- **Single volume** — a directory with a `manifest.yaml` and no
  `series.yaml`. The project directory is itself the volume, and its
  manifest carries every field: there are no defaults to merge.
- **Series** — a directory with a `series.yaml` holding the shared facts
  (collection, author, publisher, rights, language) and an ordered
  `volumes` list of volume directory names. Each volume directory has its
  own `manifest.yaml`, which may override any shared field.

A project without `series.yaml` is a single volume: one adapter handles
both shapes. The manifests describe **what** each volume contains, never
how it is rendered: no engine, no output settings. The tool turns that
model into one standard `pdf.config.yaml` per volume and calls
`bin/pandoc-pdf render`. The toolkit never learns that manifests or series
exist.

## The folder convention

A volume's content conventionally lives in:

- `content/front-matter/` — pages before the numbered chapters;
- `content/chapters/` — the numbered chapters;
- `content/back-matter/` — pages after the chapters.

**This layout is a convention, not a contract.** The manifest names each
file explicitly, so a project can use any folder names it likes; the tool
never validates the layout. Only `chapters_dir` has a default
(`content/chapters`), and only because the `ordered` chapters keyword needs
somewhere to look.

## `series.yaml` (series shape only)

Validated against `scripts/tools/bookkit/series.schema.json`.

| Field | Rule |
| --- | --- |
| `manifest_version` | Required integer, `1`. The version of this contract, independent of both the toolkit `VERSION` and the `pdf.config.yaml` `version`. |
| `collection` | Name of the series; passed to pandoc as the `collection` metadata variable. |
| `author`, `publisher`, `rights`, `language` | Shared defaults; a volume's manifest overrides each of them. `language` must be one of the toolkit's supported codes (`en`, `es`, `pt`, `gl`). |
| `volumes` | Required, at least one entry. Ordered list of volume directory names relative to the series directory; the order is the build and reading order. |

## `manifest.yaml` (one per volume)

Validated against `scripts/tools/bookkit/manifest.schema.json`.

| Field | Rule |
| --- | --- |
| `manifest_version` | Required integer, `1`. |
| `profile` | Required string, `book` — the only profile that exists. Any other value is rejected. |
| `title` | Required, non-empty. Names the volume and, by the toolkit's slug rule, the PDF file. |
| `subtitle`, `date` | Optional; passed through to the document. |
| `isbn` | Optional; passed to pandoc as the `isbn` metadata variable so a consumer's own template can print it. |
| `audience`, `description` | Optional; passed as `document.metadata` entries in the generated configuration. |
| `collection` | Optional; in the single-volume shape the manifest may declare it, in the series shape `series.yaml` provides the default. |
| `author`, `publisher`, `rights`, `language` | Optional overrides of the `series.yaml` defaults; in the single-volume shape the manifest is their only source. |
| `chapter_start` | Optional integer, 1 or more. The volume's first chapter prints with that number: the generated mode file sets the LaTeX chapter counter to `chapter_start - 1`. |
| `chapters` | Required, non-empty: either the keyword `ordered` or an ordered list of entries. |
| `chapters_dir` | Optional string, default `content/chapters`. Only read when `chapters` is `ordered`. |
| `front_matter`, `back_matter` | Optional ordered maps of **logical name to entry**; the render order follows the manifest order. |

Every path in a manifest is relative to **the volume directory**.

### `chapters: ordered`

The keyword form means: the chapters are every `*.md` file inside
`chapters_dir` (default `content/chapters`), taken in the toolkit's
**natural order** (digit runs compare numerically, so `02` comes before
`10`). A directory that does not exist, or that contains no `*.md` files,
fails the build. The explicit list form names the files and their order
directly and does not read `chapters_dir`.

### Entries

An entry is either a path string, or a mapping with:

| Key | Rule |
| --- | --- |
| `file` | Required path, relative to the volume directory. |
| `print` | Optional boolean, default `true`. `false` excludes the entry from the PDF silently: it is not read, not checked and not mentioned. |
| `optional` | Optional boolean, default `false`. `true` means the file may be absent: the tool skips it with a warning instead of failing. |

The three entry rules, exactly:

1. A declared entry whose printable file is missing **fails** the build with
   the volume, the logical name and the path in the message:
   `volume 'volume-1': chapters entry '2' declares a missing file: content/chapters/02-the-tower.md`
2. An `optional: true` entry whose file is missing is **skipped with a
   warning** and the volume still plans (and renders).
3. A `print: false` entry is excluded **silently**.

## How the mode files work

A book needs three LaTeX mode commands: `\mainmatter` before the numbered
chapters, `\appendix` before the lettered back matter, and, when a volume
continues a series, `\setcounter{chapter}{N-1}` so its first chapter prints
as chapter N. **The tool generates them into the run output**, so the
content files carry no LaTeX markers at all and stay PDF/EPUB-neutral
prose:

- `generated/00-mainmatter.md` — contains `\mainmatter`, plus
  `\setcounter{chapter}{N-1}` when the volume declares `chapter_start`;
- `generated/01-appendix.md` — contains `\appendix`; written only when the
  volume has printable back matter.

They are inserted into the reading order at the right places as ordinary
`input.explicit_files` entries. Generated files live in the run output,
never inside the content directories. A consequence: the rendered document
is PDF-only, and the generated configuration declares `formats: [pdf]`.

## The tool and `pdf.config.yaml`

The tool emits a standard `pdf.config.yaml` per volume and nothing else:
the configuration contract (`schemas/pdf-config.schema.json`, `version: 1`)
is untouched, and the book manifest contract is separate — it has its own
schemas in this directory and its own `manifest_version`. Changing the book
format never changes the toolkit's configuration contract, and the tool can
be versioned without touching the CLI.

## Usage

```bash
# Validate the manifests and emit the generated configurations, no render:
python3 scripts/tools/bookkit/build.py --check path/to/book-project

# Validate, generate and render one or more projects:
python3 scripts/tools/bookkit/build.py path/to/single path/to/series

# Output directory (default: ./.output/bookkit):
python3 scripts/tools/bookkit/build.py --out path/to/out path/to/project

# A book-class LaTeX template of your own:
python3 scripts/tools/bookkit/build.py --template path/to/book.tex path/to/project
```

Without `--template`, the generated configurations carry the builtin name
`book`: the toolkit ships `templates/book.tex` inside the artifact, so the
same project builds from a checkout and from an installation. Pass
`--template` with a book-class LaTeX template of your own — a path relative
to the working directory, or absolute — when your book needs its own design.

## Requirements

The same as any `pandoc-pdf` render (`pandoc`, a TeX engine, `python3`),
plus one YAML parser for the shared loader: PyYAML when importable,
otherwise Ruby's stdlib YAML through a subprocess — exactly like the
toolkit's own fallback. Without either, the tool fails with a clear
message.
