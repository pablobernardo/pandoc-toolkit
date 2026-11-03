# Book kit example

One adapter, two book shapes. This example proves that a single-volume book
and a multi-volume series are the same pattern: a series is a book with more
than one volume, and both render through the same public `pandoc-pdf` CLI
with the same template, the same configuration shape and the same adapter.

```bash
python3 build.py
```

The build runs from any working directory and writes everything into
`../.output/book-kit/` (gitignored): one `pdf.config.yaml` per volume, the
generated mode files, and one PDF per volume.

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
rendered: no engine, no template, no output settings. The adapter,
`build.py`, turns that model into one standard `pdf.config.yaml` per volume
and calls `bin/pandoc-pdf render`. The toolkit never learns that manifests
or series exist.

## Fields

### `series.yaml` (optional, series shape only)

| Field | Rule |
| --- | --- |
| `collection` | Name of the series; passed to pandoc as the `collection` metadata variable. |
| `author` | Shared default; a volume's `author` overrides it. |
| `publisher` | Shared default; a volume's `publisher` overrides it. |
| `rights` | Shared default; a volume's `rights` overrides it. |
| `language` | Shared default (`en`, `es`, `pt`, `gl`); a volume's `language` overrides it. |
| `volumes` | Ordered list of volume directory names; the render order is exactly this order. |

### `manifest.yaml` (one per volume)

| Field | Rule |
| --- | --- |
| `title` | Required. Names the volume and, by the toolkit's slug rule, the PDF file. |
| `subtitle`, `date` | Optional; passed through when present. |
| `isbn` | Optional; passed to pandoc as the `isbn` metadata variable. It exists so a consumer's own template can print it; the shared example template does not. |
| `chapter_start` | Optional integer, 1 or more. The first chapter of the volume prints with that number (see the mode files below). |
| `front_matter`, `back_matter` | Optional ordered maps of **logical name to entry**. |
| `chapters` | Required, non-empty: an ordered list of entries, or a mapping with `ordered: true` and `files:`. |
| `author`, `publisher`, `rights`, `language` | Optional overrides of the `series.yaml` defaults; in the single-volume shape the manifest is their only source. |
| `collection` | Optional; in the single-volume shape the manifest may declare it. |

Every path in a manifest is relative to **the volume directory**.

### Entries

An entry is either a path string, or a mapping with:

| Key | Rule |
| --- | --- |
| `file` | Required path, relative to the volume directory. |
| `print` | Optional boolean, default `true`. `false` excludes the entry from the PDF silently: it is not read, not checked and not mentioned. |
| `optional` | Optional boolean, default `false`. `true` means the file may be absent: the adapter skips it with a warning instead of failing. |

The three rules, as implemented:

1. A declared entry whose printable file is missing **fails** the build with
   the volume, the logical name and the path in the message:
   `volume 'volume-1': chapters entry '2' declares a missing file: content/chapters/02-the-tower.md`
2. An `optional: true` entry whose file is missing is **skipped with a
   warning** and the volume still renders.
3. A `print: false` entry is excluded **silently**. In `series/volume-1` the
   review-request page is a real file excluded this way; in
   `series/volume-2` the excerpt entry is declared `optional` and its file
   deliberately does not exist, so both rules are exercised, not just
   described.

## How the mode files work

A `book`-class volume needs three LaTeX mode commands: `\mainmatter` before
the numbered chapters, `\appendix` before the lettered appendices, and, when
a volume continues a series, `\setcounter{chapter}{N-1}` so its first
chapter prints as chapter N. The example template opens the front matter
itself, so the front files need no marker.

In `examples/book/` those commands sit inside the content files. This
example takes the other approach: **the adapter generates them**, so the
content files carry no LaTeX markers at all and stay PDF/EPUB-neutral prose.
Before rendering each volume, the adapter writes into the run output:

- `generated/00-mainmatter.md` — contains `\mainmatter`, plus
  `\setcounter{chapter}{N-1}` when the volume declares `chapter_start`;
- `generated/01-appendix.md` — contains `\appendix`; written only when the
  volume has printable back matter.

They are inserted into the reading order at the right places (before the
chapters, before the back matter) as ordinary `input.explicit_files`
entries. Generated files live in the run output, never inside the content
directories, and the adapter computes the relative hops into the generated
configuration. A consequence of generating the mode files the same way
`examples/book/` embeds them: the rendered document is PDF-only, so the
generated configuration declares `formats: [pdf]`.

The numbering carries across volumes without any toolkit support: volume 2
of the series declares `chapter_start: 4`, and its chapters print as
Chapter 4 and Chapter 5. Each volume is an independent PDF; the continuity
is a typesetting convention the adapter implements, not a state the toolkit
keeps.

## Why the adapter lives with the book

The manifest model is a book-shaped convenience, not a contract. Teaching
the toolkit to read `series.yaml` and `manifest.yaml` would turn every
change in the book format into a toolkit contract change, and would force
every consumer to carry a feature most of them do not use. Instead, each
book project keeps one small adapter next to its content; the toolkit stays
a stable CLI plus one configuration schema, and the adapter can be rewritten
in any language without touching it.

This example reuses the sibling `examples/book/templates/book.tex` by
reference: the generated configuration points at it with a path relative to
each volume directory, which is why the reference works no matter where the
build runs. A real consumer copies the template into its own repository and
points its adapter at its own copy.

## Files

- `build.py` — the adapter: discovers the shape, merges series defaults,
  generates the mode files, writes one `pdf.config.yaml` per volume and
  renders each through `bin/pandoc-pdf`.
- `single/` — a single-volume project without `series.yaml`.
- `series/` — a two-volume project with `series.yaml`; `volume-2` continues
  the chapter numbering of `volume-1` with `chapter_start`.
- `single/manifest.yaml`, `series/volume-*/manifest.yaml` — content-only
  manifests; edit these, never the generated configuration.

## Requirements

The same as any `pandoc-pdf` render (`pandoc`, an engine, `python3`), plus
one YAML parser for the adapter: PyYAML when importable, otherwise Ruby's
stdlib YAML through a subprocess, exactly like the toolkit's own fallback.
Without either, the adapter fails with a clear message.
