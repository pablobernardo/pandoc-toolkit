# EPUB phase 1: minimal functional export

Phase 1 of issue #94. Optional `output.format: pdf | epub` through the existing
renderer, with configuration contract 1 and unchanged PDF behavior.

## Specs

- S1 — Issue #94, "Phase 1: Minimal functional EPUB export", approved by the
  maintainer as the shared plan:
  "- Add optional `output.format: pdf | epub` while retaining configuration contract 1 and PDF behavior when omitted.
  - Integrate format-aware planning, preflight and EPUB3 generation in the existing renderer.
  - Do not implicitly require TeX for EPUB. Keep explicitly declared runtime requirements enforced and retain the required `pdf_engine` field, ignored for EPUB.
  - Include focused tests and the documentation for this behavior in the same PR."
- S2 — Same phase, exit criterion: "generate a minimal valid EPUB through the public CLI while preserving existing PDF behavior and normalized PDF plans. Do not land schema acceptance for EPUB while the renderer still silently produces PDF."
- S3 — Issue #94 delivery rules: "Keep tests and documentation with each phase, not postponed to the last PR." "Do not introduce unsupported conditional-schema keywords, numbering hacks or new CLI flags."
- S4 — Maintainer deferral and resume, verbatim: "hazlo y lo empezamos a implentar otro dia", then "continua". Implementation starts only now; the plan came from #94, not from free scope.

## Tasks

- T1 S1 | parent | Schema: optional `output.format` enum `pdf`/`epub`; omitted means PDF; existing configs keep validating. Commit: T1.
- T2 S1–S2 | parent | Plan: format-aware `build_plan`, EPUB target `{markdown, epub}`, LaTeX-only argv excluded, PDF plan byte-identical. Commit: T1.
- T3 S1 | parent | Preflight: no implicit TeX engine for EPUB; explicit `runtime.required_commands` still enforced; PDF unchanged. Commit: T1.
- T4 S1 | parent | Renderer/CLI messages: EPUB output path, no PDF-only claims; catalogs in all four locales. Commit: T1.
- T5 S2–S3 | parent | Tests: real EPUB generation plus structure checks, validation rejection, dry-run plan, preflight without TeX, PDF regression. Commit: T1.
- T6 S3 | parent | Docs: usage, architecture and CHANGELOG entries for the new optional field. Commit: T1.
- T7 S1–S3 | parent | Gate, native review and Phase 1 PR with `Refs #94`. Commit: PR.

## Log

- L1 — "continua": resume the agreed plan after the recorded deferral. Source of requirements is issue #94, whose three phases the maintainer accepted ("me parece bien el plan") and asked to record.
- L2 — Exploration before writing: `schemas/pdf-config.schema.json` (validator supports `enum`), `scripts/render-native.py` (`build_plan`, `merged_markdown`, `execute_plan`, `print_plan`), `scripts/preflight.py` (implicit TeX requirement in `missing_engine`), `bin/pandoc-pdf` (render/doctor wiring, no per-format flags), `tests/run.sh`, `tests/l1/render.sh`, `tests/l1/conformance.sh` and `tests/conformance/expected`. Pandoc 3.13 and `unzip` are available locally; `epubcheck` is not, and PyYAML is genuinely absent (Ruby stdlib fallback is the real local path).
- L3 — Measured Pandoc baseline: a bare `pandoc a.md -o a.epub` produces `mimetype`, `META-INF/container.xml`, `EPUB/content.opf` (version 3.0), `nav.xhtml`, `toc.ncx`, stylesheet, title page and chapter XHTML, with generated identifier/date/language but **no `dc:title`**. A minimal valid EPUB3 therefore needs title and language from the configuration; everything beyond that (metadata-file precedence, cover, resources) stays in phase 2.
- L4 — RED before implementation: `examples/.output/review/epub-phase1/red.log`, 8 pass / 21 fail, all for the intended reasons (`In 'output' there are disallowed fields: format`, no `.epub` target, doctor demanding a TeX engine for EPUB). GREEN after implementation: `green.log`, 46 pass / 0 fail, including the archive checks (mimetype stored and first, container rootfile, EPUB 3.0 package, `dc:title`/`dc:language`/identifier, single nav document, resolvable spine).
- L5 — Differential check in the same style as the earlier shared-code changes: the PDF plan JSON from the base commit `1c08308` and from the change are byte-identical for the same configuration, and the four recorded conformance expectations still pass. `output.format: pdf` is likewise identical to omitting the field.
- L6 — Tooling note for the record: the inline JSON linter reported "Colon expected / End of file expected" at a constant line 129 for the four catalogs. The strict `json` parser, `python3 scripts/check-i18n.py` (4 locales, 172 keys) and a content-preserving rewrite showed no defect: `en`, `es` and `gl` were clean, and `pt` cleared after the file was replaced without any content change, so those findings were stale cache, not a catalog problem. `scripts/render-native.py` also carries two pre-existing path-traversal warnings on the output paths it computes, unchanged by this work.
