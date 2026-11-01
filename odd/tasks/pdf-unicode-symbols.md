# Preserve Unicode symbols in PDF prose and code (#83)
Branch: `fix/pdf-unicode-symbols`; delivery: stacked-to-main (maintainer selected verified main chain); original forecast 300–400 lines, actual first draft 609; split by prose/inline versus verbatim behavior.
Checks: focused L1, public CLI PDF/EPUB fixtures, independent verification, `make gate`; VERSION stays 2.1.0.

## Specs

- S1: "los símbolos se ven en prosa, código en línea y bloque; sin suprimir avisos; sin convertir código en imágenes; sin encender el filtro de emojis como atajo; y respetando a quien lo tiene desactivado." Check the issue's `☐ ☑ ☒ ✅ ⚠️ ❌` fixture through the public CLI in prose, inline, untagged and highlighted code; inspect output, warnings and extraction.
- S2: "Si la fuente no está, se degrada a lo de hoy." Check guarded optional font lookup and successful rendering with the optional font unavailable, retaining missing-character diagnostics.
- S3: "🔍 U+1F50D no lo cubre ninguna: es emoji de plano suplementario, el caso que el filtro de emojis ya resuelve. No lo conviertas en requisito." Use it only as an unsupported-character diagnostic control; never suppress warnings globally.
- S4: "Toca `templates/default.tex`, compartido por todos los consumidores: esto es riesgo item 3 y probablemente exige una decisión nueva (D14) sobre fuentes y degradación." Preserve surrounding prose/code font selections and existing engine branches; document optional font installation, engines, D14 and fallback. No config schema or CLI contract changes are intended.
- S5: "me parece bien mientras siga viendo lo que tengo que ver en los pdf y epub, se verían afectados?" Keep implementation template-only for PDF; compare EPUB member content allowing only generated UUID/timestamps. Do not claim reader acceptance or new EPUB conformance without a run.
- S6: "`VERSION` se queda en 2.1.0 hasta que la preparación de 2.2.0 esté explícitamente autorizada. Sin tag, sin release." No release preparation, tag, publication or immutable asset changes.
- S7: "`templates/book.tex` es un archivo local sin versionar: no lo añadas, sobrescribas, borres ni incluyas en revisiones. Nunca empaquetes desde un árbol sucio." Exclude the local file explicitly; no packaging in this unit.
- S8: "Una rama por unidad, commits de unidad de trabajo con pruebas y documentación al lado, squash merge, `Refs #<issue>` en el commit y en el PR. Cierra cada issue solo cuando su criterio de aceptación esté verificado." Also: "Antes de cada PR: `make gate` verde." Keep the approved release-documentation reconciliation separate from the high-risk behavior commit.

## Tasks

- T1 [S1–S7, prose/inline slice] done; route: delegated worker (runtime context backstop); prose/inline implementation and tests corrected; focused RED/GREEN observed, full gate 447/0; commit: not created, delivery shape unresolved. Risk: item 3 (shared PDF template).
- T2 [S1–S7, prose/inline slice] done; route: one independent verifier after assess escalation item 3; Xe/Lua production, absence font/package, ASCII pdfLaTeX, fonts/text/EPUB verified. One EPUB timestamp-check blocker corrected and targeted recheck passed; commit: not created.
- T3 [S6–S8, prose/inline slice] in_progress; route: parent; maintainer accepted the approximately 700-line coherent first PR within the verified main chain; separate documentation commit, native review, target-policy PR checks and main gate underway; commit: pending.
- T4 [S1–S7, fenced-code slice] pending; route: delegated worker (context backstop); add verbatim reactivation and extend regression/functional coverage to all four contexts; commit: pending, based on verified first-slice main.
- T5 [S1–S8, fenced-code slice] pending; route: independent verifier then parent delivery; final all-context acceptance, native review, second PR/squash merge and main gate; close #83 only on full evidence; commit: pending.

## Log

L1 — Original scoped unit request (verbatim):

> U1 — #83 `fix(pdf): preserve missing Unicode symbols in prose and code`
> El bug más visible: glifos perdidos en cada PDF. Medido en esta máquina:
> · `FreeSerif.ttf` (GNU FreeFont, dentro de TeX Live) cubre ☐ ☑ ☒ ✅ ❌ ⚠,
> es decir toda la lista del issue.
> · `DejaVuSans.ttf` cubre ☐ ☑ ☒ ⚠ pero no ✅ ❌.
> · `FreeMono.ttf` cubre las casillas, útil para código en línea y bloque.
> · 🔍 U+1F50D no lo cubre ninguna: es emoji de plano suplementario, el caso
> que el filtro de emojis ya resuelve. No lo conviertas en requisito.
> Incógnita a resolver primero: si `gnu-freefont` viaja en
> `texlive-fonts-recommended` o solo en `texlive-fonts-extra`. De eso depende
> que el CI mínimo lo tenga y, por tanto, la política de degradación.
> La solución debe cumplir los criterios del issue: los símbolos se ven en
> prosa, código en línea y bloque; sin suprimir avisos; sin convertir código
> en imágenes; sin encender el filtro de emojis como atajo; y respetando a
> quien lo tiene desactivado. Si la fuente no está, se degrada a lo de hoy.
> Toca `templates/default.tex`, compartido por todos los consumidores: esto es
> riesgo item 3 y probablemente exige una decisión nueva (D14) sobre fuentes y
> degradación.

L2 — User authorizations (verbatim): "haz conciliación documental, por si quedó algo desactualizado con la subida de la release 2.1.0"; "hazlo a ver que pasa"; latest: "ok, haz lo que creas conveniente" following the proposal to fix the isolated prototype and complete coverage before integrating U1.

L3 — Established evidence: production base `6b45317`, VERSION 2.1.0. Approved documentation reconciliation is the only preexisting tracked edit (`docs/dependency-policy.md`); gate passed 435/0. Local `templates/book.tex` remains excluded. Prototype lives under ignored `examples/.output/unicode-font-prototype/`. Real probes refuted nonexistent fontspec NewFontFallback. FreeMono lacks three required base symbols. Guarded FreeSerif glyph mappings plus fancyvrb active-character handling work in observed Xe/Lua outputs and retain ordinary fonts; normalized EPUB members compare equal.

L4 — Open prototype defects to fix before integration: wrong standalone FE0E declaration versus FE0F comment; unguarded use of engine-local boolean in pdfLaTeX branch; untagged fixture lacks three symbols. VS16 is not a visible glyph: base-symbol extraction is required, exact Unicode sequence copy fidelity is not established and must not be claimed. Baseline Lua render timed out at 120 seconds and was not retried. Do not retry that failed command or present absent RED as observed. Use existing Xe baseline RED and fresh production checks. Preserve warnings for unrelated unsupported characters. Optional system font package is `fonts-freefont-ttf` (not texlive-fonts-recommended); verify filename/name loading as appropriate without installing dependencies.

L5 — Production draft readback: tracked diff 234 lines plus new integration script 326 and feature document 49 = 609 authored lines before this log update, exceeding the 300–400 forecast. No commits, PR, full gate or independent risk verification yet. Worker focused Xe run passed, but integration assertions do not reject missing-character warnings for the covered symbols, test VS16 only in prose, and check EPUB content presence rather than production baseline member equality; these need a single bounded correction. Lua production and pdfLaTeX compatibility checks remain unobserved. Worker reported writing /tmp/tdd-check.py outside the authorized surface; parent has not read or removed it, and will not do so without exact-path permission. No evidence of outside tracked-file changes. No package installation occurred. Delivery shape requires maintainer choice before any commit.

L6 — Maintainer chose "Cadena verificada hacia main" in the delivery questionnaire. Split by behavior, not file type: first optional glyph mappings for prose/inline with their tests and docs, preserving current fenced-code behavior; second verbatim reactivation with all-context tests and docs. Each slice must pass gate and independent verification before its own PR/merge and main gate. Do not close #83 after the partial first slice. No extra test framework or machine-specific prototype-cache dependencies in committed checks.

L7 — First-slice correction and independent verification completed. Gate job4 exit0: 447 passed/0failed, 4locales173keys,168Markdown,4conforming plans. Worker focused Xe RED/GREEN and exact prose/inline extraction passed. Independent verifier confirmed production Xe/Lua, unsupported-control warnings, absence of optional font and package, retained prose/mono fonts, no images, and ASCII pdfLaTeX compatibility. The verifier's only blocker was a false EPUB-difference assertion: regexes missed Pandoc3.13 attribute-bearing dc:date and meta-wrapped modified timestamps. Parent corrected two regex lines; exact failing artifact pair comparison passed all9 members; one targeted verifier recheck closed blocker1 without new renders. No reader or EPUBCheck acceptance claimed; emoji-enabled path not functionally retested. Full gate predates only that two-line test-script correction; shellcheck/diffcheck and targeted comparison passed after it.

L8 — Slicing outcome and stop: parent measured 691 authored diff lines before these task/log updates (228 tracked +408 integration +55 task file), not the worker-reported681. The first split removed verbatim behavior but stronger portable verification increased support code; no further cosmetic shrinking or artificial test-only PRs will be attempted. Selected verified-main chain remains the intent but does not yet contain review-sized first slice. Need maintainer decision to accept the larger coherent first PR within that chain or authorize a substantive redesign of test support. No staging, commits, PR, merge, tag, release or native review authority created. The outside-surface /tmp/tdd-check.py incident remains untouched; cleanup needs exact-path permission.

L9 — Maintainer replied "ok" to accepting the approximately 700-line coherent first PR in the selected verified-main chain. Proceed with separate release-documentation reconciliation and high-risk behavior commits, then native review and repository policy checks. VERSION remains2.1.0, #83 stays open until fenced-code slice completes.

L10 — Separate release-documentation reconciliation committed as `f1b652c` (12 authored lines; Refs #83). Native committed-only assess remained unassessable because the provider still requires an explicit untracked declaration. Before source review, select only the intended unit scope and exclude local `templates/book.tex`; never include that local file in review. The target default branch is main; #83 currently has only bug, and target lacks type:bug (type:feature is available). Applying protected status:approved requires a direct maintainer label instruction before PR publication under the branch/PR skill.
