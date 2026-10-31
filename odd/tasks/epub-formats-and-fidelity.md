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

- T1 [done] S1 | parent | Actual EPUB author and metadata-file precedence, public CLI archive tests and docs. Commit: `1f7f286`.
- T2 [done] S2 | parent | EPUB-only initial-heading header override; default CSS, split chapters and PDF plans preserved. Commit: `a9d9156`. Visual acceptance tracked in T5, not claimed.
- T3 [done] S3–S5 | parent | Single formats list, format-aware preflight and multi-output plans/execution; partial failures, regression tests, migration docs and example adaptation. Commit: feat(render) formats work unit. Risk: item 3 (replace unreleased config key and extend consumed plan contract).
- T4 [in_progress] S1–S5 | independent verify + parent | Gate, PDF differential and native assessment/review per work-unit. Commit: final evidence pending.
- T5 [blocked] S2 | user | Open corrected preview in Apple Books and confirm no blank pages before title/index/chapters. Waiting for user visual evidence; not required to implement other code.

## Log

- L1 — Original authorization: "aplicalo". Earlier user messages are quoted in S1–S5; reader and pagination evidence precede this feature.
- L2 — Baseline: main and github/main both `1cee946a8f9e4e4cbcd68bd41d874b10559d75c5`; local example YAMLs each add `format: epub`. Preserve these changes until migration in T3. All four existing EPUB archives lack dc:creator; documentation EPUB has no empty spine files, but global h1 page-break-before:always applies to title, navigation and all six split chapters.
- L3 — Implementation gate: optional config selection changes from unpublished `format` to `formats` without changing contract 1 or VERSION 2.0.1. Default PDF single-plan shape and significant argv remain unchanged. Multi-output needs an explicit ordered job list; each job retains single-plan semantics. Runtime requirements are the union of requested formats. Tests must pin omission, each single format, dual output and partial failures in both orders.
- L4 — Workload forecast: metadata ~150 lines, pagination ~100, multi-output ~350–500 including tests/docs. Keep three work-unit commits with tests/docs alongside behavior; report any overage, do not compress code to fit. Delivery shape: reviewable local work-unit chain; public PRs/merge remain separate authorization.
- L5 — Verification: runnable public CLI tests use temporary isolated fixtures; real Pandoc for EPUB metadata and embedded CSS; deterministic Pandoc doubles only for failure scenarios. Apple Books visual acceptance cannot be inferred from ZIP inspection. Do not claim blank pages fixed visually without reader feedback.
- L6 — T1 commit `1f7f286`, native review `review-fc0328bb8ccc6f44` approved/acknowledged. T2 GREEN30/0, gate job16 exit0:381/0, four conforming PDF plans. Only EPUB argv adds the header include; no shared filter or PDF template edits. Apple Books feedback pending.
- L7 — T1 RED: author assertion 24/1, metadata-file precedence 1/1, both exit1. GREEN: 27/0; full gate job15 exit0, 378/0, 4 locales172 keys,140 Markdown,4 conforming PDF plans. T2 test-first probe separately observed 25/3 (title/nav/chapter missing initial-heading override) before implementation.

- L8 — T2 native review `review-3b94109a29d8386d` approved/acknowledged; advisory pagination assertion only. T3 RED: eight failing assertions over five public CLI tests. GREEN: seven tests, including both orders and either failed format; omission/default PDF plan equality; invalid lists and singular key rejection without output writes; duplicate suppression; preflight union; inline/block and multiline-flow YAML.
- L9 — Independent verifier `mvwj95a4-1-5yjb` found a multiline-flow-list preflight bypass without PyYAML. Regression observed RED (exit0 rather than1), then minimal parser delegates nontrivial list syntax to full Ruby YAML. Recheck `mvwjgkhk-2-1qw0` resolved the same blocker with exact stdout/stderr/exit and byte-identical config. S1/S3/S4/S5 met; S2 structurally met, reader proof pending.
- L10 — Final serialized gate job20 exit0:385/0, 173 catalog keys in four locales,141 Markdown files,4 conformance cases; seven public integration tests passed; git diff --check and active LSP nine-path errors scan clean. Earlier job17 failed because docs checker saw the real-render intermediate Markdown concurrently; serialized job19 passed after its cleanup. No source issue was hidden.
- L11 — Public CLI differential against base1cee946 in scratch: all four PDF cases have identical stdout/stderr/exit after canonical root normalization. First harness attempt failed on macOS /private alias normalization, corrected. Real dual-format documentation render job18 exit0:32-page A4 PDF (134801 bytes) plus EPUB; dc:creator and every XHTML override inspected. PDF retains expected missing-glyph warnings with emoji filter disabled. Preview: examples/.output/review/epub-formats/toolkit-documentation-preview-corrected.epub.
- L12 — T3 is a cohesive ~450-line work unit including failure tests and migration docs; keep behavior/test/docs together rather than compressing to fit a heuristic. No public PR publication is authorized. Stable EPUB identifiers were separately discussed: configuration metadata can carry one, but local reader replacement is not guaranteed; no library edits or extra identifier feature added.
