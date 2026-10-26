# Config Contract Alignment (S1)

Rama `feature/config-contract-alignment`. Cierra la divergencia entre `schemas/pdf-config.schema.json` y el runtime, más los quick wins aprobados. Sin cambio breaking de contrato de config.

## Specs

**S1 — Petición original (verbatim)**
> revisa este repo a ver que propones para mejorarlo optimizarlo o simplificarlo

**S2 — Pregunta de distribución (verbatim)**
> una vez finalizado todos esos cambios tendremos un ejecutable como ahora independiente? o recomiendas compilar algo en go u otro lenguaje para tenerlo?

**S3 — Decisión de distribución (verbatim)**
> windows no es prioritario pero me gustaria dejar una puerta abierta para implementarlo con go si lo recomiendas y nos aporta valor

**S4 — Autorización de arranque (verbatim)**
> me parece bien

**S5 — Alcance aceptado de S1 (verbatim de la propuesta aprobada)**
> **S1** | **P1** (contrato vs runtime: 5 campos inertes) + quick wins (`--team`, emoji duplicados, `.env`, pycache en release) | Arregla la mentira del contrato. Sin riesgo alto, con bump menor + nota de migración.

**S6 — `input.order` debe ordenar los capítulos**
`natural` (valor declarado en defaults/examples/fixtures) compara los tramos numéricos como números: `chapter-2.md` antes que `chapter-10.md`. `alphabetical` conserva el orden lexicográfico actual. Cualquier otro valor falla con mensaje localizado que enumera los valores admitidos. Solo aplica cuando `input.explicit_files` está vacío.

**S7 — `output.keep_merged_markdown` debe controlar el `.md` fusionado**
`true` (default) lo conserva (comportamiento actual). `false` lo elimina tras un render de pandoc exitoso; si pandoc falla, el `.md` se conserva para diagnóstico.

**S8 — `document.*` debe llegar a la plantilla**
Con `pandoc.metadata_file` vacío, los campos no vacíos `title`, `subtitle`, `publisher`, `author`, `date`, `rights` se pasan a pandoc como variables de plantilla (`-V campo=valor`). Con `metadata_file` informado, no se pasan (el fichero de metadatos manda), tal como declara `docs/architecture.md` §2 regla 4. `document.title` sigue fijando el nombre de fichero de salida.

**S9 — `filters.emoji.include_ballot_icons` debe controlar los dingbats**
`false` deja los caracteres `☐` (2610), `☑` (2611) y `☒` (2612) sin sustituir por imagen. `true` (default) mantiene la sustitución actual.

**S10 — `runtime.strict` debe controlar la severidad del preflight**
`true` (default) falla con exit 1 si falta un comando requerido o el motor TeX. `false` los reporta como advertencias y sale con exit 0.

**S11 — Quick wins aprobados**
- El mensaje de falta de locale no debe mencionar `--team` (la opción real es `--project`).
- Los SVG `filters/emoji/emoji_u{2610,2611,2612}.svg` son copias byte-idénticas de `filters/emoji/{2610,2611,2612}.svg` y no se referencian: se eliminan.
- `scripts/package-release.sh` no debe incluir `scripts/__pycache__` en el artefacto ni volver a empaquetar 4 veces el mismo árbol.
- `--resource-path` debe unirse con el separador de la plataforma, no con `':'` hardcodeado.

**S12 — Documentación y versión**
`docs/usage.md`, `docs/migration.md`, `CHANGELOG.md`, `CONTEXT.md` y `VERSION` reflejan la nueva semántica. Bump menor de toolkit (comportamiento añadido, sin configs inválidas).

**S13 — El filtro de emojis no debe alterar texto sin emojis (hallazgo de verificación L2)**
`filters/emoji.lua` envolvía en `pandoc.Span` todo `Str`, partiendo además cada palabra en un `Str` por carácter. Efecto: cualquier encabezado pasaba a ser "con formato" y pandoc emitía `\\texorpdfstring`, que exige `hyperref` en la plantilla; con plantillas mínimas el render fallaba con `! Undefined control sequence`. Ya fallaba en `master` (L2 exit 43, verificado en worktree de `master`). El filtro debe devolver `nil` cuando no hubo sustitución real.

**Fuera de alcance de S1 (aprobado en el plan)**
- P2 (retirar renderer Ruby), P3 (unificar i18n en bash), P5 (validador de schema), P7 (partir la suite bash).
- Plan JSON `--dry-run --json` y P4 (defaults vs validación) → S2/S3.

## Tasks

| ID | S# | Tarea | Ruta | Commit | Estado |
| --- | --- | --- | --- | --- | --- |
| T1 | S6-S10 | Tests RED de los cinco comportamientos (python y ruby) | inline | ae9cb3b | done |
| T2 | S6-S10 | Implementación en `render-native.py`, `render-native.rb`, `filters/emoji.lua`, `scripts/preflight.py` + claves i18n en 4 locales | inline | 75f6dc9 | done |
| T3 | S11 | Quick wins: `--team`, SVG duplicados, `package-release.sh`, `os.pathsep` | inline | bfb5d8f | done |
| T4 | S12 | Docs, CHANGELOG, CONTEXT, VERSION 1.2.0 | inline | docs slice | done |
| T5 | S6-S12 | Suite L1 verde + L2 real + differential python/ruby | inline | pendiente |
| T6 | S13 | Filtro emoji: no reescribir encabezados planos + plantillas de integración con `graphicx`/`hyperref` | inline | pendiente | pendiente |

## Log

**L1 — Petición inicial (verbatim)**
> revisa este repo a ver que propones para mejorarlo optimizarlo o simplificarlo

**L2 — Contexto de distribución (verbatim)**
> una vez finalizado todos esos cambios tendremos un ejecutable como ahora independiente? o recomiendas compilar algo en go u otro lenguaje para tenerlo?

**L3 — Decisión de distribución (verbatim)**
> windows no es prioritario pero me gustaria dejar una puerta abierta para implementarlo con go si lo recomiendas y nos aporta valor

**L4 — Autorización (verbatim)**
> me parece bien

**L5 — Evidencia base (medida antes de tocar código)**
- `bash tests/run.sh` → PASS=145 FAIL=0.
- `VERSION` = 1.1.3; `CONTEXT.md` declaraba 1.1.0 y PASS 143/113 (deriva).
- Artefacto real: 4 tarballs de 53K idénticos, 0 binarios; incluye `scripts/__pycache__/*.pyc` (verificado con `tar -tzf`).
- `python3` local sin PyYAML ⇒ el camino activo en esta máquina es el renderer Ruby. Ambos renderers deben permanecer sincronizados hasta S3.
- La plantilla `templates/default.tex` usa `$subtitle$`, `$author$`, `$publisher$`, `$date$`, `$rights$` en la portada: hoy se renderizan vacíos porque el runtime nunca los pasa.

**L6 — Decisión de implementación (desvío consciente de la recomendación inicial)**
La propuesta inicial sugería retirar `filters.emoji.include_ballot_icons` y `runtime.strict` del schema. Se decide **implementarlos** en su lugar porque:
- retirar propiedades con `additionalProperties: false` invalida configs de consumidores (breaking, item 3 de alto riesgo);
- ambas implementaciones cuestan pocas líneas y eliminan la mentira del contrato sin romper nada.
Resultado: S1 no rompe ninguna config existente y solo requiere bump menor.

**L7 — Decisión de no borrar `.env`**
`/Users/pablo/code/pablobernardo/pandoc-toolkit/.env` contiene `PANDOC_PDF_UPDATE_TOKEN` y está ignorado por git. No se elimina (destructivo, contiene un secreto del usuario). Se documenta la incoherencia para que la decisión sea del mantenedor.

**L8 — Cierre de slices (medido en `git show --stat` de cada commit)**
- `75f6dc9` (implementación) ≈ 295 líneas autoradas: 256 inserciones + 39 borrados sobre 10 ficheros.
- `bfb5d8f` (higiene de release) ≈ 24 líneas: 11 inserciones + 13 borrados sobre 4 ficheros.
- `ae9cb3b` (tests) ≈ 570 líneas: 558 inserciones sobre 3 ficheros (2 fixtures nuevas + `tests/run.sh`).
- `bash tests/run.sh` → **PASS=188 FAIL=0** tras el slice de tests (base medida en L5: PASS=145).
- `python3 scripts/check-i18n.py` verde con las nuevas claves `doctor.warn.*`, `render.error.order_invalid` y `cli.locale.error.missing_target` en los 4 locales.
- Nota de proceso: T1 (tests) se materializó en el commit `ae9cb3b`, posterior a la implementación `75f6dc9`; se conservó en commit propio porque `tests/run.sh` es un monolito compartido (ver slice pendiente de partirlo).

**L9 — Hallazgo en verificación L2: el filtro de emojis rompía plantillas mínimas (pre-existente)**
L2 fallaba en `master` con exit 43 y `! Undefined control sequence \texorpdfstring`. Verificado en un worktree limpio de `master`, así que no era regresión de este slice.
Causa raíz: `function Str(el) return pandoc.Span(...) end` en `filters/emoji.lua` envolvía cada `Str` en un `Span` (y `string_to_inlines` generaba un `Str` por carácter). Pandoc emite `\texorpdfstring` para encabezados con formato, y esa macro la define `hyperref`. Plantilla mínima sin `hyperref` ⇒ render roto.
Fix: el filtro solo envuelve cuando hubo sustitución real; las plantillas de `tests/integration/*/templates/default.tex` cargan `graphicx` y `hyperref` (una plantilla realista debe cargarlos).

**L10 — Evidencia de verificación final**
- `bash tests/run.sh` → **PASS=191 FAIL=0**.
- `bash tests/l2-local.sh` → **exit 0**, `✅ L2 local integration passed` (pandoc + pdflatex reales, PDF y `.md` generados, `-V title=` aplicado, filtros emoji+mermaid activos).
- `bash tests/l3-local.sh` → **no ejecutable en esta máquina**: `❌ Chromium executable not found. Set PUPPETEER_EXECUTABLE_PATH.` No se reintenta.
- `python3 scripts/check-i18n.py` → 4 locales, 151 claves.
- Differential master↔rama: L2 ejecutado en worktree de `master` (fmt: exit 43, mismo `\texorpdfstring`) y en la rama (exit 0) ⇒ la mejora es verificable y la regresión no existe.
