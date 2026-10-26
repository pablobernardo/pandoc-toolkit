# Uso — Pandoc PDF Toolkit

Esta guía explica cómo consumir el toolkit desde cualquier repositorio.

> Antes de empezar: ver `docs/install.md` para dejar `pandoc-pdf` en PATH.

## 1) Requisitos mínimos

- `pandoc`
- engine TeX compatible con tu plantilla (por ejemplo `xelatex`)
- `python3`
- parser YAML disponible (`PyYAML` o Ruby YAML stdlib)
- `curl`
- `mmdc` (si usas filtro Mermaid)

> Recomendación: ejecutar siempre `pandoc-pdf doctor` antes de `render`.

## 2) Contrato de configuración

Cada repositorio consumidor define su `pdf.config.yaml`.

No hay baseline oculto: el contrato es exactamente lo que valida `schemas/pdf-config.schema.json`. El toolkit no fusiona ningún fichero de defaults, así que todo lo que el render necesita está declarado en tu `pdf.config.yaml`. Usa `examples/pdf.config.example.yaml` como plantilla de arranque.

Los únicos valores que el renderer aplica por sí mismo son fallbacks históricos de código para claves ausentes (motor `xelatex`, TOC activo, plantilla `templates/default.tex`); un config válido no depende de ellos porque el schema obliga a declarar las claves.

Campos mínimos esperados:

- `version`
- `project`
- `document`
- `input`
- `output`
- `pandoc`
- `filters`
- `runtime`
- `compat`

### 2.1) Semántica de los campos declarativos

Estos campos son obligatorios en `schemas/pdf-config.schema.json` y el runtime los aplica de verdad. Cuando faltan, el renderer y el preflight usan los valores por defecto indicados abajo (que coinciden con `examples/pdf.config.example.yaml`).

`input.order` — orden de los capítulos:

- `natural`: compara los tramos numéricos como números, así que `chapter-2.md` va antes que `chapter-10.md`.
- `alphabetical`: orden lexicográfico por nombre de fichero.
- Cualquier otro valor se rechaza en `render` con un mensaje localizado que enumera los valores admitidos (`natural`, `alphabetical`); no se ordena en silencio.
- Solo aplica cuando `input.explicit_files` está vacío: una lista explícita se respeta tal cual.

`output.keep_merged_markdown` — suerte del Markdown fusionado:

- `true` (default): conserva el `.md` intermedio junto al PDF.
- `false`: lo elimina tras un render de pandoc correcto. Si pandoc falla, el `.md` se conserva para diagnóstico.

`document.*` — metadatos y portada:

- Con `pandoc.metadata_file` vacío, los campos no vacíos `title`, `subtitle`, `publisher`, `author`, `date` y `rights` se pasan a pandoc como variables de plantilla (`-V campo=valor`) y rellenan la portada de `templates/default.tex`.
- Con `pandoc.metadata_file` informado **no** se pasan: el fichero de metadatos manda (ver `docs/architecture.md` §2, regla 4 «Reglas del contrato»).
- `document.title` sigue fijando el nombre del fichero de salida (`title-<suffix>`); `output.file_prefix` solo se usa como alternativa si `document.title` falta.

`filters.emoji.include_ballot_icons` — casillas de tareas Markdown:

- `true` (default): `☐` (U+2610), `☑` (U+2611) y `☒` (U+2612) se sustituyen por su imagen del set de emoji.
- `false`: se dejan como caracteres, sin sustitución.

`runtime.strict` — severidad del preflight:

- `true` (default): `doctor` falla con exit 1 si falta un comando de `runtime.required_commands` o el motor TeX.
- `false`: los reporta como advertencias y sale con exit 0, **salvo el motor TeX**: sin él no hay PDF, así que su ausencia falla siempre aunque `strict` sea `false`.

## 3) Comandos del CLI

Atajo opcional vía `make`:

```bash
make doctor
make validate CONFIG=pdf.config.yaml
make render CONFIG=pdf.config.yaml
make bootstrap-yes
make bootstrap-ci
```

Consultar versión del CLI:

```bash
pandoc-pdf --version
```

Consultar información de entorno del toolkit:

```bash
pandoc-pdf info
pandoc-pdf info --json
```

Gestionar locale del CLI:

```bash
pandoc-pdf locale show
pandoc-pdf locale set es
pandoc-pdf locale set pt
pandoc-pdf locale set gl
pandoc-pdf locale set --project es
```

Locales actualmente soportados: `en`, `es`, `pt`, `gl`.

`locale set <lang>` guarda el idioma global en `~/.config/pandoc-pdf/config.env` (o `XDG_CONFIG_HOME/pandoc-pdf/config.env`) para que aplique por defecto en ejecuciones futuras.

`locale set --project <lang>` guarda el idioma en `.pandoc-pdf.env` del repositorio actual para ese proyecto.

Comprobar si hay nueva versión estable del toolkit:

```bash
pandoc-pdf update --check
pandoc-pdf update
pandoc-pdf update --to v1.2.3
```

`update --check` informa versión local, última versión estable y si hay actualización disponible.

`update` instala la última versión estable para la plataforma actual.

`update --to <tag>` instala una versión concreta (por ejemplo `v1.2.3`).

Instalación gestionada del updater:

- Toolkit versionado en `~/.local/share/pandoc-pdf/versions/<tag>/`
- Puntero activo en `~/.local/share/pandoc-pdf/current`
- Entrypoint en `~/.local/bin/pandoc-pdf`

Notas:

- `pandoc-pdf-dev` está reservado para desarrollo local y **no permite** instalación con `update`.
- Puedes personalizar la raíz gestionada con `PANDOC_PDF_UPDATE_HOME`.

Flags útiles:

- `--yes`: evita confirmación interactiva.
- `--dry-run`: muestra el plan sin escribir en disco.
- `--install-dir <path>`: define la ruta de instalación.

Para repositorios privados en GitHub, exporta un token antes de ejecutar update:

```bash
export PANDOC_PDF_UPDATE_TOKEN=<tu_token>
# o alternativamente
export GH_TOKEN=<tu_token>
```

Validar entorno y dependencias:

```bash
pandoc-pdf doctor
```

Validar configuración:

```bash
pandoc-pdf validate-config -c pdf.config.yaml
```

`validate-config` aplica validación estricta del contrato (required, tipos y campos no permitidos), alineada con `schemas/pdf-config.schema.json`, y validaciones funcionales de rutas críticas (`input.chapters_dir`, `pandoc.template`, `pandoc.metadata_file` cuando se informa, `filters.extra_lua_filters`). `input.order` se valida además contra su `enum`: un valor distinto de `natural` o `alphabetical` se rechaza aquí, antes de llegar al render.

El validador implementa un subconjunto explícito de JSON Schema (`type`, `properties`, `required`, `additionalProperties`, `items`, `minItems`, `minLength`, `minimum`, `enum`). Un test falla si el schema empieza a usar cualquier otra keyword, para que nunca se ignore en silencio.

`pandoc.template` es opcional: si no se informa, el render usa `templates/default.tex`.

Renderizar PDF:

```bash
pandoc-pdf render -c pdf.config.yaml
```

Inspeccionar el plan de render sin ejecutar nada:

```bash
pandoc-pdf render -c pdf.config.yaml --dry-run
pandoc-pdf render -c pdf.config.yaml --dry-run --json
```

`--dry-run` imprime el plan legible (capítulos en orden efectivo, markdown fusionado, PDF de salida y la invocación de pandoc) y **no escribe nada**: no crea directorios, no genera el markdown fusionado, no prepara emojis y no invoca pandoc.

`--dry-run --json` emite el mismo plan como JSON en stdout (el banner de validación va a stderr, así que stdout queda limpio) con esta forma:

```json
{
  "plan_version": 1,
  "toolkit": { "version": "1.2.0", "root": "/ruta/toolkit" },
  "config": { "path": "/ruta/pdf.config.yaml", "base_dir": "/ruta/proyecto" },
  "chapters": ["/ruta/proyecto/chapters/chapter-2.md"],
  "pandoc": {
    "target": { "markdown": "...", "pdf": "..." },
    "argv": ["pandoc", "..."],
    "cwd": null
  },
  "env": { "PANDOC_EMOJI_DIR": "...", "PANDOC_EMOJI_BALLOT_ICONS": "1" },
  "side_effects": {
    "keep_merged_markdown": true,
    "clearpage_between_h1": true,
    "emoji": { "enabled": true, "dir": "...", "missing_svg": "...", "prepare_argv": ["python3", "..."] },
    "mermaid": { "enabled": true, "dir": "...", "background": "transparent" }
  }
}
```

El plan es el contrato verificable del render: es lo que permite comparar dos implementaciones (hoy la de Python y la de Ruby) sin leer código, y es la base de una futura suite de conformidad.

## 4) Flujo recomendado

1. Preparar/actualizar `pdf.config.yaml`.
2. Ejecutar `doctor` para verificar dependencias.
3. Ejecutar `validate-config` para detectar errores de contrato.
4. Ejecutar `render`.
5. Ejecutar `update --check` de forma periódica para revisar nuevas versiones estables.

## 5) Convenciones para repos consumidores

- Resolver rutas relativas a `project.base_dir`.
- Evitar hardcodes en wrappers locales.
- Mantener overrides de estilo en templates propios, no en el core.

## 6) Troubleshooting rápido

- Falla `doctor`: instalar dependencias faltantes antes de reintentar.
- Falla `validate-config`: corregir campos obligatorios/estructura YAML.
- Falla `render` con Mermaid: verificar `mmdc` en PATH y permisos de salida.

## 6.1) Seguridad de configuración

- No ejecutes `render` ni `doctor -c` con `pdf.config.yaml` de origen no confiable.
- Revisa especialmente `runtime.required_commands` y `filters.extra_lua_filters`.
- Consulta la política de seguridad en `.github/SECURITY.md`.

## 7) Integración en CI

Secuencia sugerida:

1. `pandoc-pdf doctor`
2. `pandoc-pdf validate-config -c pdf.config.yaml`
3. `pandoc-pdf render -c pdf.config.yaml`

Si `runtime.strict: true` (default), cualquier dependencia faltante debe fallar el pipeline.

Con `runtime.strict: false`, `doctor` degrada las dependencias faltantes a advertencias: las imprime igualmente y sale con exit 0. La única excepción es el motor TeX: su ausencia falla siempre, porque sin él el PDF no puede generarse. Úsalo solo en pipelines donde la dependencia auxiliar se resuelve más adelante (por ejemplo una imagen que la instala en un paso posterior).

## 8) Integración con OpenCode (agentes)

Para que los modelos lo usen de forma consistente:

1. Asegura que el proceso de OpenCode tenga `pandoc-pdf` en PATH.
2. Define en instrucciones del repositorio que el entrypoint oficial es `pandoc-pdf`.
3. Secuencia recomendada para agentes:
   - `pandoc-pdf doctor`
   - `pandoc-pdf validate-config -c pdf.config.yaml`
   - `pandoc-pdf render -c pdf.config.yaml`
4. Para cambios estructurales del toolkit, usar la skill local:
   - `.atl/skills/pandoc-toolkit-maintainer/SKILL.md`

## 9) Tests del CLI

Suite actual de smoke/contract tests:

```bash
tests/run.sh
```

Runners locales de integración:

```bash
bash tests/l2-local.sh
bash tests/l3-local.sh
```

Notas:
- `l2-local.sh` ejecuta integración semi-real (sin stack Mermaid completo).
- `l3-local.sh` requiere `mmdc` y Chromium (`PUPPETEER_EXECUTABLE_PATH` si no autodetecta).

Cobertura actual de la suite:

- ayuda y manejo de comando desconocido
- `doctor` en escenario OK y dependencia faltante
- `validate-config` con caso válido e inválido
- `render -c` en modo nativo (verifica salida/entorno)
- rechazo explícito de flags legacy (`--legacy`)
- integración avanzada de render (extra_lua_filters, resource_path, metadata opcional)
- errores de render por `explicit_files` inexistentes
- plan de render: JSON válido, sin efectos secundarios, `--dry-run` legible y paridad byte a byte entre los renderers Python y Ruby
- filtro de emojis: encabezados planos no emiten `\\texorpdfstring`
- comportamiento del contrato (desde 1.2.0):
  - `input.order` con valores `natural` y `alphabetical`, y rechazo de un valor no admitido indicando el campo y los valores soportados
  - `output.keep_merged_markdown` en `false` (borra el `.md`) y en `true` (lo conserva), con PDF producido en ambos casos
  - `document.*` llega a pandoc como variables `-V`, y un `pandoc.metadata_file` tiene prioridad sobre ellas
  - `include_ballot_icons` conmuta `PANDOC_EMOJI_BALLOT_ICONS` entre `1` y `0`
  - `runtime.strict` en `false` (advertencia, exit 0) y en `true` (fallo)
- paridad Python/Ruby: ambos renderers construyen una invocación de pandoc byte-idéntica
- artefacto de release: el paquete generado no contiene bytecode de Python (`__pycache__`, `.pyc`)
- mensaje de locale sin destino: nombra `--project`, no `--team`

Además, esta suite corre automáticamente en CI (GitHub Actions) para PR/push sobre matriz macOS/Linux como **L1**.

Niveles de CI:

- **L1 (rápido, obligatorio en PR/push):** `tests/run.sh`.
- **L2 (semi-real, manual):** render real en Ubuntu sobre fixtures de integración.
- **L3 (completo, manual o programado):** integración con stack ampliado (incluye Mermaid CLI).
  - incluye fixture Mermaid real en `tests/integration/l3-mermaid-project/`.

Workflow e inputs manuales:

- Workflow: `.github/workflows/ci.yml`
- `run_render_integration=true` para ejecutar **L2**
- `run_render_full=true` para ejecutar **L3**

Ejecutar por CLI:

```bash
gh workflow run ci.yml -f run_render_integration=true
# o
gh workflow run ci.yml -f run_render_full=true
```
