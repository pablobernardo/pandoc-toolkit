# EPUB fidelity and multi-format export

Follow-up to #94 on base `1cee946a`. No release, push or merge is authorized by this implementation.
Preserve published PDF behavior and the user's four local EPUB example selections.

## Specs

- S1 — "lo que veo es que sale autor desconocido en todos los epub, generandolos desde examples/"; accepted scope: "autor y precedencia de metadatos".
- S2 — "pagina 1 en blanco, entre indice y capitulo 1 tambien, entre capitulo 1 y 2, entre 2 y 3, entre capitulo 3 y 4, entre 4 y 5 y entre 5 y 6 en el epub generado en pandoc pdf toolkit. Vamos que parece que antes de cada capítulo sale una página en blanco si o si. Es lo habitual?" Reader: "en libros de apple". Constraint: "pero corregirlo no puede tener daños colaterales sobre la generación de pdf?".
- S3 — "me parece bien entonces lanzamos esa mejora y ves demasiado incluir también la posibilidad de exportar varios formatos desde su pdf.config.yaml?"; "crees que tiene sentido tener format y formats? no sería más limpio solo una clave?". Accepted proposal: only `output.formats: [pdf]`, `[epub]` or `[pdf, epub]`; omission means PDF. Replace the unreleased `format` key, not a published contract.
- S4 — "aplicalo", accepting: "si falla un formato, ¿conservamos los archivos generados correctamente y devolvemos error indicando la entrega parcial?". Preserve successful artifacts and report unsuccessful formats with nonzero exit.
- S5 — Accepted: "También adaptaré tus cuatro configuraciones locales a `formats: [epub]`, manteniendo tu selección." Do not erase unrelated edits or change the published VERSION.

## Tasks

- T1 [done] S1 | parent | Actual EPUB author and metadata-file precedence, public CLI archive tests and docs. Commit: fix(epub) metadata work unit.
- T2 [in_progress] S2 | parent | EPUB-only initial-heading pagination override; preserve split chapters and PDF plans; prepare reader comparison. Commit: pending. Visual acceptance requires Apple Books evidence.
- T3 [pending] S3–S5 | parent | Single formats list, format-aware preflight and multi-output plans/execution; partial failures, regression tests, migration docs and example adaptation. Commit: pending. Risk: item 3 (replace unreleased config key and extend consumed plan contract).
- T4 [pending] S1–S5 | independent verify + parent | Gate, PDF differential and native assessment/review per work-unit; report visual proof separately. Commit: pending.

## Log

- L1 — Original authorization: "aplicalo". Earlier user messages are quoted in S1–S5; reader and pagination evidence precede this feature.
- L2 — Baseline: main and github/main both `1cee946a8f9e4e4cbcd68bd41d874b10559d75c5`; local example YAMLs each add `format: epub`. Preserve these changes until migration in T3. All four existing EPUB archives lack dc:creator; documentation EPUB has no empty spine files, but global h1 page-break-before:always applies to title, navigation and all six split chapters.
- L3 — Implementation gate: optional config selection changes from unpublished `format` to `formats` without changing contract 1 or VERSION 2.0.1. Default PDF single-plan shape and significant argv remain unchanged. Multi-output needs an explicit ordered job list; each job retains single-plan semantics. Runtime requirements are the union of requested formats. Tests must pin omission, each single format, dual output and partial failures in both orders.
- L4 — Workload forecast: metadata ~150 lines, pagination ~100, multi-output ~350–500 including tests/docs. Keep three work-unit commits with tests/docs alongside behavior; report any overage, do not compress code to fit. Delivery shape: reviewable local work-unit chain; public PRs/merge remain separate authorization.
- L5 — Verification: runnable public CLI tests use temporary isolated fixtures; real Pandoc for EPUB metadata and embedded CSS; deterministic Pandoc doubles only for failure scenarios. Apple Books visual acceptance cannot be inferred from ZIP inspection. Do not claim blank pages fixed visually without reader feedback.
- L6 — T1 RED: author assertion 24/1, metadata-file precedence 1/1, both exit1. GREEN: 27/0; full gate job15 exit0, 378/0, 4 locales172 keys,140 Markdown,4 conforming PDF plans. T2 test-first probe separately observed 25/3 (title/nav/chapter missing initial-heading override) before implementation.
