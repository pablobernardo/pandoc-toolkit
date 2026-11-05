# Building a book

A book is not a second renderer. It is the same `skelepress render`, with a
`book`-class template and, when the book is declared as volumes, a manifest that
turns into one configuration per volume.

There are two ways in, and they meet at the same place.

## 1. From a configuration you already have

Set the template by its builtin name and say what a top-level heading is:

```yaml
pandoc:
  template: book
  top_level_division: chapter
```

`book` resolves to the template that ships inside the installation, so the same
configuration builds from a checkout and from an installed CLI. `chapter` is
what makes Pandoc emit `\chapter` for a top-level heading; `default` lets Pandoc
infer the division and does not guarantee one.

## 2. From manifests

A **book project** is a directory with an optional `series.yaml` and one or more
volumes. A **volume** is a directory with a `manifest.yaml` and its content
folders beside it:

```text
my-book/
  manifest.yaml          # or series.yaml + one directory per volume
  front-matter/
  chapters/
  back-matter/
```

The names are a **convention, not a contract**: the manifest names every file,
and the tool never validates the layout. There is no `content/` level to carry
around.

Build it:

```bash
skelepress book my-book                  # one configuration per volume, then render
skelepress book --check my-book          # validate and emit the configurations only
```

`skelepress book` forwards every argument to the shipped bookkit tool and
reports its own output and exit code, so anything the tool accepts works here.
The complete field reference — every manifest key, its type and its default —
lives with the tool, in
[`scripts/tools/bookkit/README.md`](https://github.com/pablobernardo/skelepress/blob/main/scripts/tools/bookkit/README.md). This
page is the story; that page is the contract.

## What a volume prints

In order: the image cover if one is declared, the typeset title page, the
contents, the front matter, the chapters, and the appendices.

The numbering follows the printed-book convention, and the two alphabets are
different things:

| Part | Division | Page |
| --- | --- | --- |
| Front matter | listed in the contents unless declared `toc: false` | roman: `i`, `ii`, `iii` |
| Chapters | arabic: `1`, `2`, … | arabic, continuing |
| Appendices | letters: `A`, `B`, … | arabic, continuing |

That is why an appendix entry reads `A Glossary …. 4`: the letter numbers the
division and the number numbers the page.

## The fields that shape a book

| Manifest field | What it does |
| --- | --- |
| `title`, `subtitle`, `author`, `publisher`, `date`, `rights`, `language` | What the title page and the metadata carry. In the series shape, `series.yaml` provides defaults a volume may override. |
| `front_matter`, `back_matter` | Ordered maps of logical name to file. An entry accepts `toc: false` to print without appearing in the contents, which is the right choice for a dedication. |
| `chapters` | Either an ordered list of files or the keyword `ordered`, which takes every `*.md` from `chapters_dir`. |
| `chapters_dir` | Folder for `ordered`; defaults to `chapters`. |
| `chapter_start` | The number the volume's first chapter prints with, so a second volume can continue the first instead of restarting at 1. |
| `toc_separators` | Separates the contents into blocks: `none`, `space` (default), `rule`, or `label`. |
| `toc_labels` | The words `label` prints, for `chapters` and `appendices`. |

The generated configuration also carries what makes it a book: `template: book`
and `top_level_division: chapter`.

## Separating the contents

The contents is one list, so the front matter, the chapters and the appendices
run together unless you separate them. `toc_separators: label` prints a word at
each boundary, which is what makes `A Glossary …. 4` readable:

```text
Contents
The Two Lights                    iii

Chapters
1  The North Road                   1
2  The Tower                        2

Appendices
A  Glossary                         4
```

```yaml
toc_separators: label
toc_labels:
  chapters: "Chapters"
  appendices: "Appendices"
```

Declare it in `series.yaml` to share it across volumes; a volume may override
it. A volume without back matter needs no `appendices` label, and asking for
`label` without the words fails naming the field.

## A cover image

Declare `cover-image` in the document metadata — the metadata file or
`document.metadata`, no separate field — and both formats use it:

```yaml
document:
  metadata:
    cover-image: "assets/cover.png"
```

The image prints on its own page before the typeset title page, and it prints
even with `titlepage: false`, because a cover is not a title page. A relative
path resolves against `project.base_dir`, so it works from any working
directory and in both formats.

## See it work

```bash
skelepress book --out .output examples/book-kit/single    # one volume
skelepress book --out .output examples/book-kit/series    # two volumes, shared defaults
```

The examples are the reference for both shapes: a single volume with every field
in one manifest, and a series where `series.yaml` holds the shared facts and
`volume-2` continues the chapter numbering with `chapter_start`.
