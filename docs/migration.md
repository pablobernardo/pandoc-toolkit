# Migración — Legacy `.pandoc` a `pandoc-pdf`

Esta guía describe cómo migrar desde scripts locales acoplados a una adopción reusable del toolkit.

## Objetivo de la migración

Pasar de pipelines hardcodeados por repo a un contrato declarativo (`pdf.config.yaml`) + un CLI versionado (`pandoc-pdf`).

## Señales de que estás en modo legacy

- Scripts wrapper legacy locales con rutas fijas (`chapters/`, `output/`, etc.).
- Filtros Lua acoplados a carpetas concretas.
- Validaciones manuales de dependencias sin preflight unificado.

## Estrategia recomendada (gradual)

### Fase 1 — Paridad funcional

1. Crear `pdf.config.yaml` replicando comportamiento actual.
2. Ajustar rutas a valores declarativos (`project.base_dir`, `input`, `output`).
3. Ejecutar `pandoc-pdf doctor` y resolver dependencias.
4. Ejecutar `pandoc-pdf validate-config -c pdf.config.yaml`.
5. Ejecutar `pandoc-pdf render -c pdf.config.yaml` y comparar salida con legacy.

### Fase 2 — Wrapper de transición

Mantener un wrapper local (por ejemplo `render-pdf.sh`) que internamente invoque:

```bash
pandoc-pdf render -c pdf.config.yaml
```

Esto permite adopción progresiva sin romper hábitos del equipo.

### Fase 3 — Retiro del legacy

1. Eliminar hardcodes de rutas en scripts/filtros locales.
2. Delegar validación al comando `validate-config`.
3. Consolidar documentación en torno al CLI (`doctor`, `validate-config`, `render`).

## Checklist de migración

- [ ] `pdf.config.yaml` con `version` definido.
- [ ] Rutas resueltas desde `project.base_dir`.
- [ ] Dependencias verificadas con `doctor`.
- [ ] Config validada por schema.
- [ ] Render reproducible en local y CI.
- [ ] Wrapper legacy documentado (si aplica) y plan de retiro definido.

## Actualización 1.1.x → 1.2.0

Bump menor. **No se requiere ningún cambio en `pdf.config.yaml`**: los cinco campos afectados ya eran obligatorios en el schema y ninguno se ha eliminado ni renombrado, así que una config válida de 1.1.x sigue validando en 1.2.0.

Cambios de comportamiento que puedes observar al actualizar:

- **`document.*` ahora llega a la plantilla.** Con `pandoc.metadata_file` vacío, `title`, `subtitle`, `publisher`, `author`, `date` y `rights` se pasan a pandoc como variables `-V` y rellenan la portada. Si tu `templates/default.tex` (o tu template propio) esperaba esas variables vacías, la portada cambia: revisa el PDF resultante.
- **`input.order` solo admite `natural` o `alphabetical`.** Antes cualquier valor se ignoraba; ahora un valor distinto falla en `render` con un mensaje que enumera los admitidos. Revisa el campo en tus configs.
- **`runtime.strict: false` hace que `doctor` salga con exit 0** aunque falten dependencias: las sigue imprimiendo, pero como advertencias. Si tu CI dependía del exit code de `doctor` para detectar entornos incompletos, necesitas `runtime.strict: true` (que además es el default).
- **`output.keep_merged_markdown: false` borra el Markdown fusionado** tras un render correcto. Si algún paso posterior de tu pipeline leía ese `.md`, ponlo en `true` (default) o consume el PDF.

Quick wins incluidos en la misma versión:

- El error por locale no indicado sugiere `--project` (antes mencionaba `--team`, que no existe).
- `--resource-path` se une con el separador de la plataforma en lugar de `:` hardcodeado, así que la ruta no se rompe donde el separador es distinto.
- Los assets `filters/emoji/emoji_u*.svg` duplicados desaparecen; el renderer copia `2610/2611/2612.svg` en cada ejecución, así que no hay nada que ajustar en consumidores.
- El artefacto de release ya no incluye `scripts/__pycache__`.

### Baseline de configuración retirado

`defaults/default.yaml` ya no existe: el schema es la única fuente de verdad y `render` no fusiona ningún fichero de defaults. Si validabas tu config, **no tienes que hacer nada** (las claves del baseline ya eran obligatorias). Si invocabas `scripts/render-native.*` directamente con configs parciales, declara las claves que esperabas heredar; en particular `pandoc.resource_path` ya no se rellena solo.

`pandoc-pdf info` (y `info --json`) deja de mostrar `defaults_path` / `defaults_exists`.

### Filtro de emojis

`filters/emoji.lua` deja de reescribir el texto sin emojis. Si tu plantilla mínima no cargaba `graphicx` y `hyperref`, añádelos: son necesarios para imágenes y para encabezados con formato. Antes del cambio, cualquier encabezado emitía `\\texorpdfstring` y el render fallaba aunque no hubiera emojis.

## Política de cambios breaking

Si la migración requiere cambio breaking en CLI/contrato/defaults:

1. Bump de versión mayor del toolkit.
2. Guía de migración explícita.
3. Actualización de ejemplos de referencia.

## Riesgos comunes y mitigación

- **Riesgo:** salida distinta al pipeline legacy.
  - **Mitigación:** paridad por fases y comparación de artefactos.
- **Riesgo:** dependencia faltante en CI.
  - **Mitigación:** ejecutar `doctor` al inicio del pipeline.
- **Riesgo:** configuraciones divergentes por repo.
  - **Mitigación:** contrato versionado + validación schema + ejemplos neutrales.
