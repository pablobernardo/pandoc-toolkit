# Add an agnostic book example with a book-class template
Branch: `feat/book-example`; scope: example and documentation only. No schema, validator, renderer or default-template change; the consumer-side glue lives inside the example.
Why it is one slice over the review budget: the example only proves anything if the manifest, the glue, the content and the template land together, because the template is what makes the content render as a book.

## Specs

- S1: "recuerda que teniamos intención de poder maquetar libros un ejemplo de plantilla de libro que tenemos agnostica de generador de pdf". The reference manifest the maintainer supplied:
  ```text
  title, author, language, audience, description
  volumes: volume-1 (chapters 1-22), volume-2 (chapters 23-43)
  chapters: ordered
  front_matter: title-page, copyright, dedication, prologue, characters, glossary
  back_matter: about-the-author, review-request, collection-page, activities
  ```
  It is explicitly a content manifest: "Content only: no tool, engine, or layout settings belong here."
- S2: "me parece bien lo que planteas en el punto 2 para ir probando como quedaría e ir construyendo desde ahí y a partir de ahí decidimos, pero igual era bueno crear una plantilla .tex para libro no crees?" The example and a book-class template are authorized; the contract decision waits for the evidence.
- S3: "no codifiques nada todavía estamos solo estudiando la opción" applied until S2. Nothing in `schemas/`, `scripts/` or `templates/default.tex` may change.
- S4: "`templates/book.tex` es un archivo local sin versionar: no lo añadas, sobrescribas, borres ni incluyas en revisiones." The example template is new and lives under `examples/book/templates/`.
- S5: The manifest stays content-only, and the manifest-to-config glue belongs to the consuming repository, so a change in the book format never becomes a toolkit contract change.
- S6: No client data, no real ISBN, English artifacts, and no absolute paths (`scripts/check-docs.py` rejects home paths).

## Tasks

- T1 [S1, S5] done; route: parent read-only; contract mapped against the manifest: no manifest support inside `pdf.config.yaml`, and `input` has no pre/post concept while every section sets `additionalProperties: false`.
- T2 [S1] done; route: parent; suite constraints measured: every `examples/**/pdf.config*.yaml` must validate, the documentation-coverage test points only at `examples/documentation`, and `explicit_files` resolves against `chapters_dir` so `front/x.md` subpaths work.
- T3 [S1–S6] done; route: delegated worker (context backstop); manifest, glue, three chapters, front and back matter, new book-class template, README and the `docs/usage.md` row.
- T4 [S1] done; route: parent review of the render; two defects found and corrected: the table of contents was printing in arabic because it preceded the mode switch, and both front files re-issued `\frontmatter`, restarting the roman counter. The template now opens the front matter and the front files carry no marker.
- T5 [S1–S6] in progress; route: parent delivery; `make gate`, PR, squash merge and main verification; commit `aff923e`.
- T6 [S2] pending; route: follow-up unit; the renderer cannot pass pandoc's `--top-level-division`, so the example template shifts heading levels with `\let`. A first-class option (for example `pandoc.top_level_division`) is a contract addition and is deliberately out of scope here.

## Log

L1 — Maintainer request, verbatim excerpt: "que toca ahora? recuerda que teniamos intención de poder maquetar libros un ejemplo de plantilla de libro que tenemos agnostica de generador de pdf por ahora tenemos algo como así:" followed by the content manifest quoted in S1, and "no se si recomiendas añadir algo a pdf.config.yaml para dar soporte a lo que se quiere hacer ahí. No codifiques nada todavía estamos solo estudiando la opción".

L2 — Parent recommendation, accepted by the maintainer in S2: keep the manifest in the consumer repository, generate `pdf.config.yaml` with a small glue step, and ship a book-class template as an example. Rationale recorded: teaching the toolkit to read a book manifest would turn every book-format change into a toolkit contract change, and the three real gaps are ordered groups before and after the body, a real book template, and typographic numbering — the last one being PDF-only.

L3 — Delivery evidence. Renders through the public CLI with `xelatex`: nine pages, title page without a folio, contents on folio **i**, dedication without a folio, the characters page on folio **iii** (so the roman sequence is continuous and does not restart), chapters 1–3 on folios 1–3, `Appendix A` and `Appendix B` on folios 4–5, table-of-contents entries `1 The Harbour` with 1.1 and 1.2, `2 The Light`, `3 The Storm`, `A Glossary`, `B About the Author`, and zero `Missing character` warnings. `validate-config` exits 0 on the generated configuration, `build.sh` runs from the repository root and from an unrelated working directory, `shellcheck` is clean and `check-docs.py` exits 0. Two workarounds are documented rather than hidden: the heading-level shift for the missing `--top-level-division`, and the redefinition of `\frontmatter`/`\mainmatter` because TeX Live 2026's `book.cls` calls `\cleardoublepage` unconditionally, which would force recto starts and blank pages despite `openany`. The example uses the Ruby YAML fallback because PyYAML is not installed on this machine, and the pdfLaTeX branch of the example template is unexercised.
