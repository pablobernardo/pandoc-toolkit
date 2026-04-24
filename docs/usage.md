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

El toolkit incluye un baseline en `defaults/default.yaml` que se fusiona en render con la configuración local (la configuración del proyecto tiene prioridad en caso de conflicto).

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

`validate-config` aplica validación estricta del contrato (required, tipos y campos no permitidos), alineada con `schemas/pdf-config.schema.json`, y validaciones funcionales de rutas críticas (`input.chapters_dir`, `pandoc.template`, `filters.extra_lua_filters`).

`pandoc.template` es opcional: si no se informa, el render usa `templates/default.tex`.

Renderizar PDF:

```bash
pandoc-pdf render -c pdf.config.yaml
```

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

Si `runtime.strict: true`, cualquier dependencia faltante debe fallar el pipeline.

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
