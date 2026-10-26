# Render Plan JSON (S3-a)

Rama `feature/config-contract-alignment` (misma rama de feature). Extrae el cálculo del render a un **plan puro** que se puede inspeccionar y comparar sin ejecutar pandoc.

## Specs

**P1 — Nuevo modo de `render` (aditivo)**
`pandoc-pdf render -c <pdf.config.yaml> --dry-run` imprime el plan legible y **no escribe nada** en disco. `--dry-run --json` imprime el mismo plan como JSON en stdout. `--json` implica `--dry-run`. Sin flags, `render` se comporta exactamente como hasta ahora.

**P2 — El plan es puro**
Calcular el plan no crea directorios, no escribe el markdown fusionado, no descarga emojis y no invoca pandoc. Se puede ejecutar en un repo limpio sin efectos observables (ni ficheros nuevos, ni modificaciones).

**P3 — Contenido del plan (v1)**
JSON con: `plan_version`, `toolkit` (`version`, `root`), `config` (`path`, `base_dir`), `chapters` (rutas absolutas en el orden efectivo, ya aplicado `input.order` o `explicit_files`), `pandoc.target` (markdown fusionado y PDF), `pandoc.argv`, `pandoc.cwd`, `env`, `side_effects` (`keep_merged_markdown`, `emoji` con su directorio, `mermaid` con su directorio y fondo, `emoji_prepare` con su argv o `null` si está deshabilitado).

**P4 — Paridad entre renderers**
El plan JSON debe ser idéntico (normalizando el prefijo de ruta) entre `scripts/render-native.py` y `scripts/render-native.rb`, igual que ya se exige para la invocación de pandoc.

**P5 — Sin cambio de comportamiento**
La ejecución normal conserva bit a bit la invocación de pandoc y el entorno ya verificados: la suite existente (191 aserciones) debe seguir verde sin modificarlas, y el plan debe ser la única fuente de esa invocación (el ejecutor no decide nada).

**Fuera de alcance**
- Retirar el renderer Ruby (P2 del análisis) y decidir defaults-vs-validación (P4 del análisis): siguen pendientes de decisión.
- Suite de conformidad multi-lenguaje: se apoyará en este plan cuando exista un port.

## Tasks

| ID | S# | Tarea | Ruta | Estado | Commit |
| --- | --- | --- | --- | --- | --- |
| T1 | P1-P5 | Tests: plan JSON válido, sin efectos, `--dry-run` legible, paridad py/ruby | inline | done | slice de tests |
| T2 | P2-P3 | Refactor `build_plan` puro + `execute_plan` en `render-native.py` | inline | done | slice de implementación |
| T3 | P4 | Espejo en `render-native.rb` | worker | done | slice de implementación |
| T4 | P1 | Cableado de flags en `bin/pandoc-pdf` + i18n | inline | done | slice de implementación |
| T5 | P1-P5 | Docs (`docs/usage.md`, CHANGELOG, CONTEXT) | inline | done | slice de docs |

## Log

**L1 — Continuación autorizada (verbatim)**
> continua

**L2 — Contexto**
Slice S3-a del plan aprobado en la conversación de revisión. No cambia contrato de config ni comportamiento por defecto: solo añade un modo de inspección. El plan es la pieza que el análisis identificó como "puerta abierta a Go" y como contrato verificable frente a un port futuro.

**L3 — Estado de partida (medido)**
- `bash tests/run.sh` → PASS=191 FAIL=0.
- `bash tests/l2-local.sh` → exit 0.
- `bash tests/l3-local.sh` → no ejecutable en esta máquina (Chromium no encontrado).
- Review nativo del slice anterior: bloqueado por proveedor (guard de razonamiento en `review-resilience`); lineage `review-d3a0f85c95b06577` en estado `reviewing`, sin veredicto. No se reintenta sin decisión del mantenedor.

**L4 — Implementación y evidencias**
- Python reescrito en tres piezas: `build_plan` (pura), `execute_plan` (único punto con efectos), `print_plan`. Ruby espejo vía worker, con paridad byte a byte.
- Dos bloqueos reales encontrados y corregidos en la verificación:
  1. `bin/pandoc-pdf` validaba el config escribiendo en stdout, así que `--dry-run --json` devolvía banner + JSON. Ahora el banner de validación va a stderr cuando se pide `--json`.
  2. `prepare_argv[0]` divergía (`sys.executable` en Python vs `python3` en Ruby). Se fija el token neutro `python3` en el plan, que es el mismo comando con el que el CLI lanza el renderer.
- Mensaje `render.error.usage` actualizado en los 4 locales con `[--plan|--plan-json]`.
- Cambio de comportamiento colateral aceptado: con `filters.emoji.enabled: false` ya no se crea el directorio de emojis ni `_missing.svg` (el ejecutor obedece al plan). No afecta a ningún fixture ni a L2.

**L5 — Verificación final**
- `bash tests/run.sh` → **PASS=210 FAIL=0** (base de este slice: 191).
- `bash tests/l2-local.sh` → **exit 0**, `✅ L2 local integration passed` (render real tras el refactor).
- `python3 scripts/check-i18n.py` → 4 locales, 153 claves.
- Plan verificado como puro: `--dry-run` no invoca pandoc (captura del mock vacía) y no crea `work/out`.
