# Single-source config defaults (P4)

Rama `feature/config-contract-alignment`. Elimina `defaults/default.yaml` para que `schemas/pdf-config.schema.json` sea la única fuente de verdad del contrato: hoy el schema exige las 9 secciones y `render` valida el config del usuario, así que el baseline es inalcanzable por el camino validado.

## Specs

**S1 — Autorización (verbatim)**
> haz lo que recomiendes

**S2 — Decisión aplicada (verbatim de la recomendación aceptada)**
> Mi recomendación es **(b)** para este toolkit: un solo lugar donde leer el contrato, y el consumidor ya tiene `examples/pdf.config.example.yaml` como plantilla de arranque.

**S3 — Desaparece el baseline**
`defaults/default.yaml` se elimina del repositorio y del árbol de distribución. Ningún runtime lo lee: ni los renderers, ni `package-release.sh`, ni `install-local.sh`.

**S4 — Sin defaults ocultos en el renderer**
Un config que omita una clave no recibe un valor del toolkit: el renderer solo aplica los fallbacks de código históricos (motor `xelatex`, `toc` activo, `templates/default.tex`, etc.). En particular, sin `pandoc.resource_path` no se emite `--resource-path`. El contrato válido es el que valida el schema.

**S5 — `pandoc-pdf info` deja de anunciar el baseline**
Se retiran `defaults_path` / `defaults_exists` de la salida de texto y de `info --json`, porque el fichero ya no existe. Se documenta como cambio de salida.

**S6 — Sin pérdida de comportamiento en configs válidas**
Todo config que hoy pasa `validate-config` se renderiza igual: las claves que el baseline aportaba son obligatorias en el schema, así que el usuario ya las declara. La suite anterior (210 aserciones) debe seguir verde salvo las que probaban el propio baseline.

**S7 — Documentación y rastro**
`docs/usage.md`, `docs/architecture.md` (árbol), `docs/migration.md`, `CHANGELOG.md` y `CONTEXT.md` reflejan la retirada y qué hacer si un consumidor dependía del baseline.

## Tasks

| ID | S# | Tarea | Ruta | Estado | Commit |
| --- | --- | --- | --- | --- | --- |
| T1 | S3-S4 | Tests: sin baseline y sin defaults ocultos | inline | pendiente | pendiente |
| T2 | S3-S4 | Retirar el merge en ambos renderers y borrar `defaults/` | inline | pendiente | pendiente |
| T3 | S3-S5 | `package-release.sh`, `install-local.sh`, `info` | inline | pendiente | pendiente |
| T4 | S7 | Docs, CHANGELOG, migración, CONTEXT | inline | pendiente | pendiente |

## Log

**L1 — Petición (verbatim)**
> haz lo que recomiendes

**L2 — Evidencia de la incoherencia**
- `schemas/pdf-config.schema.json` exige 9 secciones y `runtime.required_commands`, `pandoc.resource_path`, `output.keep_merged_markdown`, `compat.legacy_clearpage_between_h1`, etc.
- `bin/pandoc-pdf render` ejecuta `validate-config` sobre el config **del usuario** antes de renderizar.
- El único test que ejercitaba el merge (`run_render_defaults_merge_test`) llamaba a `render-native.rb` directamente, saltándose el CLI: era la prueba de que el baseline no era alcanzable por el camino soportado.
- Configs válidas: el baseline nunca aportaba nada, porque el schema ya obliga a declarar esas claves. Un config sin `pandoc.resource_path` falla la validación, así que el default `[chapters]` del baseline era código muerto.

**L3 — Alcance del cambio**
- Renderers: fuera `deep_merge` y la carga del baseline (`deepcopy` deja de usarse).
- `bin/pandoc-pdf info`: fuera `defaults_path`/`defaults_exists` (texto y `--json`).
- `scripts/package-release.sh` e `scripts/install-local.sh`: fuera la copia del directorio.
- `defaults/default.yaml`: eliminado (5 semanas de historial en git si hiciera falta volver).
