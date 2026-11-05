# bookkit — build books with the skelepress toolkit

`scripts/tools/bookkit/build.py` turns declarative book manifests into
standard `skelepress.config.yaml` files and renders them through the public
`skelepress` CLI. It is a shipped, versioned tool: a consuming repository
uses it as-is instead of writing its own adapter, and the book format it
reads is governed by this tool's own contract, not by `skelepress.config.yaml`.

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
model into one standard `skelepress.config.yaml` per volume and calls
`bin/skelepress render`. The toolkit never learns that manifests or series
exist.

## The folder convention

A volume's content conventionally lives in:

- `front-matter/` — pages before the numbered chapters;
- `chapters/` — the numbered chapters;
- `back-matter/` — pages after the chapters.

The folders sit at the **volume root**, beside the `manifest.yaml`: there is no
extra `content/` level to carry into a project.

**This layout is a convention, not a contract.** The manifest names each file
explicitly, so a project can use any folder names it likes; the tool never
validates the layout. Only `chapters_dir` has a default (`chapters`), and only
because the `ordered` chapters keyword needs somewhere to look.


### `toc_separators`

The contents are a single list, so the front matter, the chapters and the
appendices run together. The adapter separates them where it already writes the
structural switches — before the first chapter and before the first appendix —
and the volume chooses the mark:

| Value | What the contents shows |
| --- | --- |
| `none` | Nothing; the list stays as it is. |
| `space` (default) | A vertical gap before each block. |
| `rule` | A gap and a thin horizontal rule. |
| `label` | A gap and a bold word, from `toc_labels`. |

The block is self-contained: it defines the LaTeX it uses before using it, so a
volume built with a `--template` of its own compiles without that template
declaring anything. `toc_labels` is only read by `label`, and a volume without
back matter needs no `appendices` entry.

## `series.yaml` (series shape only)

Validated against `scripts/tools/bookkit/series.schema.json`.

| Field | Rule |
| --- | --- |
| `manifest_version` | Required integer, `1`. The version of this contract, independent of both the toolkit `VERSION` and the `skelepress.config.yaml` `version`. |
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
| `chapters_dir` | Optional string, default `chapters`. Only read when `chapters` is `ordered`. |
| `front_matter`, `back_matter` | Optional ordered maps of **logical name to entry**; the render order follows the manifest order. |
| `toc_separators` | Optional, default `space`. Separates the contents into blocks at the two boundaries the adapter controls: none, space, a thin rule, or a bold label. |
| `toc_labels` | Optional map of `chapters` and `appendices` to the words `toc_separators: label` prints. Required by that style, and only for the boundaries the volume actually has. |

Every path in a manifest is relative to **the volume directory**.

### `chapters: ordered`

The keyword form means: the chapters are every `*.md` file inside
`chapters_dir` (default `chapters`), taken in the toolkit's
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
| `toc` | Optional boolean, default `true`. `false` prints the page but keeps it out of the table of contents: the adapter wraps the entry with the template's hide and show switches, so the page keeps its front-matter numbering and simply is not listed. |

The three entry rules, exactly:

1. A declared entry whose printable file is missing **fails** the build with
   the volume, the logical name and the path in the message:
   `volume 'volume-1': chapters entry '2' declares a missing file: chapters/02-the-tower.md`
2. An `optional: true` entry whose file is missing is **skipped with a
   warning** and the volume still plans (and renders).
3. A `print: false` entry is excluded **silently**.

`toc: false` is orthogonal to those three: the page still prints and only its
contents entry is dropped. A dedication usually wants `toc: false`; a prologue
usually does not, because readers navigate to it.

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

## The tool and `skelepress.config.yaml`

The tool emits a standard `skelepress.config.yaml` per volume and nothing else:
the configuration contract (`schemas/skelepress-config.schema.json`, `version: 1`)
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

The same as any `skelepress` render (`pandoc`, a TeX engine, `python3`),
plus one YAML parser for the shared loader: PyYAML when importable,
otherwise Ruby's stdlib YAML through a subprocess — exactly like the
toolkit's own fallback. Without either, the tool fails with a clear
message.
