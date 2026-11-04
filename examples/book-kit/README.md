# Book kit example

One tool, two book shapes. This example proves that a single-volume book
and a multi-volume series are the same pattern: a series is a book with more
than one volume, and both render through the same public `pandoc-pdf` CLI
with the same template, the same configuration shape and the same shipped
tool.

```bash
pandoc-pdf book --out ../.output/book-kit single series
```

The command above runs from this directory and writes everything into
`../.output/book-kit/` (gitignored): one `pdf.config.yaml` per volume, the
generated mode files, and one PDF per volume. From any other working
directory, pass the project paths and `--out` as you would to the tool
itself — the subcommand forwards them unchanged.

## The model

A **book project** is a directory with an optional `series.yaml` and one or
more volumes. A **volume** is a directory with a `manifest.yaml` and its
`content/`. There are two shapes:

- `single/` — no `series.yaml`: the project directory is itself the volume,
  and its `manifest.yaml` carries every field, with no defaults to merge.
- `series/` — `series.yaml` holds the shared facts and an ordered `volumes`
  list; each volume directory has its own `manifest.yaml`, which may
  override any shared field.

The manifests describe **what** each volume contains, never how it is
rendered. The shipped tool, `scripts/tools/bookkit/build.py`, turns that
model into one standard `pdf.config.yaml` per volume and calls
`bin/pandoc-pdf render`. The toolkit never learns that manifests or series
exist. The `pandoc-pdf book` subcommand is the front door to that tool: it
forwards every argument and reports the tool's own output and exit code.

## The folder convention

The volumes here use the convention the tool documents:
`content/front-matter/`, `content/chapters/` and `content/back-matter/`.

**The layout is a convention, not a contract.** The manifest names each
file, so a project can use any folder names it likes; the tool never
validates the layout.

## Fields

Every field, with its rule, is documented in the tool's own reference:
`scripts/tools/bookkit/README.md`. The manifests here are validated against
`scripts/tools/bookkit/manifest.schema.json` and `series.schema.json`
(`manifest_version: 1`, `profile: book`). The example is the complete
reference for the contract: the single manifest shows every optional field
(`subtitle`, `isbn`, `collection`, `audience`, ...), and the series shows
the shared defaults with per-volume overrides and `chapter_start`.

Every path in a manifest is relative to **the volume directory**.

### Entries

An entry is either a path string, or a mapping with `file` (required),
`print` (default `true`) and `optional` (default `false`).

The three rules, as exercised by this example:

1. A declared entry whose printable file is missing **fails** the build with
   the volume, the logical name and the path in the message:
   `volume 'volume-1': chapters entry '2' declares a missing file: content/chapters/02-the-tower.md`
2. An `optional: true` entry whose file is missing is **skipped with a
   warning** and the volume still renders. In `series/volume-2` the excerpt
   entry is declared `optional` and its file deliberately does not exist.
3. A `print: false` entry is excluded **silently**. In `series/volume-1` the
   review-request page is a real file excluded this way, so both rules are
   exercised, not just described.

## How the mode files work

A book volume needs three LaTeX mode commands: `\mainmatter` before the
numbered chapters, `\appendix` before the lettered back matter, and, when a
volume continues a series, `\setcounter{chapter}{N-1}` so its first chapter
prints as chapter N.

The tool generates those commands into the run output, so the content files
carry no LaTeX markers at all and stay PDF/EPUB-neutral prose. Before
rendering each volume, the tool writes into the output directory:

- `generated/00-mainmatter.md` — `\mainmatter`, plus
  `\setcounter{chapter}{N-1}` when the volume declares `chapter_start`;
- `generated/01-appendix.md` — `\appendix`; written only when the volume
  has printable back matter.

They are inserted into the reading order at the right places as ordinary
`input.explicit_files` entries, and the generated configuration declares
`formats: [pdf]`. The numbering carries across volumes without any toolkit
support: volume 2 of the series declares `chapter_start: 4`, and its
chapters print as Chapter 4 and Chapter 5. Each volume is an independent
PDF; the continuity is a typesetting convention the tool implements, not a
state the toolkit keeps.

## Files

- `single/` — a single-volume project without `series.yaml`.
- `series/` — a two-volume project with `series.yaml`; `volume-2` continues
  the chapter numbering of `volume-1` with `chapter_start`.
- `single/manifest.yaml`, `series/series.yaml`,
  `series/volume-*/manifest.yaml` — content-only manifests; edit these,
  never the generated configuration.

## Requirements

The same as any `pandoc-pdf` render (`pandoc`, a TeX engine, `python3`).
The tool reuses the toolkit's own YAML loader: PyYAML when importable,
otherwise Ruby's stdlib YAML through a subprocess — exactly like the
toolkit's own fallback. Without either, the tool fails with a clear
message.
