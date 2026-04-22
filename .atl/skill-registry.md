# Skill Registry — pandoc-toolkit

## Objetivo

Estandarizar cómo trabajan los agentes en este repositorio para evitar deriva técnica entre contrato, CLI, tests y documentación.

## Flujo oficial del toolkit

Siempre seguir esta secuencia cuando haya cambios funcionales:

1. `pandoc-pdf doctor`
2. `pandoc-pdf validate-config -c <config>`
3. `pandoc-pdf render -c <config>`
4. `tests/run.sh`

## Skills locales disponibles

- `pandoc-toolkit-maintainer`: `.atl/skills/pandoc-toolkit-maintainer/SKILL.md`
  - Usar cuando el cambio afecte contrato, render/preflight, tests, CI o documentación técnica.
- `pandoc-toolkit-security-review`: `.atl/skills/pandoc-toolkit-security-review/SKILL.md`
  - Usar para revisión de seguridad en entradas de configuración, ejecución de procesos, bootstrap y CI.

## Áreas críticas del proyecto

- Contrato y esquema: `schemas/pdf-config.schema.json`
- Validación: `scripts/validate-config.py`
- Preflight: `scripts/preflight.py`, `scripts/preflight.sh`
- Render nativo: `scripts/render-native.py`, `scripts/render-native.rb`
- Defaults: `defaults/default.yaml`
- Plantilla base: `templates/default.tex`
- Tests: `tests/run.sh`, `tests/fixtures/`, `tests/integration/`

## Reglas operativas para agentes

### 1) Cambios de contrato/configuración

Si se toca cualquiera de estos elementos:

- `schemas/pdf-config.schema.json`
- estructura de `pdf.config.yaml`
- defaults (`defaults/default.yaml`)

entonces el agente DEBE:

1. actualizar fixtures afectados,
2. actualizar tests,
3. actualizar documentación (`docs/usage.md`, `docs/migration.md`, `README.md` si aplica).

### 2) Cambios de render o preflight

Si se modifica render/preflight:

1. ejecutar `tests/run.sh`,
2. verificar errores y mensajes de salida,
3. revisar impacto en CI L2/L3 (`.github/workflows/ci.yml`).

### 3) Cambios de documentación

Toda documentación debe mantener:

- neutralidad (sin datos privados),
- coherencia con estado real del código,
- referencias de rutas vigentes (sin nombres legacy retirados).

## Checklist mínimo antes de cerrar una tarea

- [ ] No se rompió el contrato del schema sin documentarlo.
- [ ] Los tests relevantes están actualizados.
- [ ] `tests/run.sh` pasa en local.
- [ ] Si hay cambios de CI, están documentados en `README.md` y `docs/usage.md`.
- [ ] No se han reintroducido scripts o rutas legacy.

## Política de niveles de CI

- **L1**: rápido, obligatorio en PR/push.
- **L2**: integración semi-real manual.
- **L3**: integración completa manual/programada.

Los agentes deben proponer L2/L3 cuando los cambios afecten render, filtros, runtime o integración real.

## Convenciones de idioma y estilo

- Documentación y texto en código: español de España.
- Mensajes técnicos claros, accionables y verificables.
