# AGENTS.md — Pandoc PDF Toolkit

## Mission
Construir y mantener un toolkit **agnóstico, versionado y reusable** para generar PDF con Pandoc en múltiples repositorios consumidores.

## Architectural Goal
Estandarizar el flujo en un CLI estable (`pandoc-pdf`) + configuración declarativa (`pdf.config.yaml`) por repo consumidor, evitando acoplamientos locales.

## Scope
Este archivo define reglas **estables** del proyecto.

El estado cambiante (fase actual, decisiones recientes, tareas abiertas) vive en `CONTEXT.md` para evitar mezclar estrategia con operación diaria.

## Out of Scope
- Este repo **no** contiene documentación de negocio específica de un cliente o repositorio consumidor.
- No se aceptan ejemplos con datos privados, nombres internos o estructuras acopladas a una organización concreta.

## Non-Negotiables
1. Cero hardcodes de rutas en scripts, filtros y plantillas.
2. Compatibilidad por versión de config (`version` obligatorio).
3. CLI usable por humanos, CI e integraciones automatizadas.
4. Preflight obligatorio antes de render (`doctor`/`preflight`).
5. Migración segura sin romper adopción de repos consumidores.
6. Documentación y ejemplos sin datos de cliente ni estructura privada.

## Core Toolkit Structure (implemented)
- `bin/pandoc-pdf`
- `Makefile`
- `filters/emoji.lua`
- `filters/mermaid.lua`
- `scripts/bootstrap.sh`
- `scripts/validate-config.py`
- `scripts/render-native.py`
- `scripts/render-native.rb`
- `scripts/prepare-emojis.py`
- `scripts/preflight.sh`
- `scripts/check-i18n.py`
- `scripts/install.sh`
- `scripts/package-release.sh`
- `schemas/pdf-config.schema.json`
- `examples/pdf.config.example.yaml`
- `defaults/default.yaml`
- `templates/default.tex`
- `i18n/locales/`

## Planned Additions (target)
- Soporte Windows (futuro, sin romper contrato CLI actual).

## Config Contract (`pdf.config.yaml`)
Campos obligatorios o esperados del contrato:
- `version`
- `project`
- `document`
- `input`
- `output`
- `pandoc`
- `filters`
- `runtime`
- `compat`

## Expected CLI Commands
- `pandoc-pdf --version` / `pandoc-pdf version`
- `pandoc-pdf info` / `pandoc-pdf info --json`
- `pandoc-pdf locale show`
- `pandoc-pdf locale set <lang>`
- `pandoc-pdf locale set --project <lang>`
- `pandoc-pdf update --check`
- `pandoc-pdf update`
- `pandoc-pdf update --to <tag>`
- `pandoc-pdf doctor`
- `pandoc-pdf validate-config -c <file>`
- `pandoc-pdf render -c <file>`

## Breaking Change Policy
- Todo cambio breaking en CLI, contrato de config o comportamiento por defecto requiere:
  1. bump de versión mayor del toolkit,
  2. guía de migración explícita,
  3. actualización de ejemplos/config de referencia.

## Delivery Criteria (Definition of Done)
- Un solo entrypoint funcional (`pandoc-pdf`).
- Config validada contra schema JSON.
- Rutas declarativas (sin acoplamientos a carpetas concretas).
- Prueba de compatibilidad en al menos 2 repos con estructuras distintas.
- Migración documentada para consumidores.

## Work Protocol
1. Cambios estructurales primero en contrato + schema.
2. Después CLI (`render`, `validate-config`, `doctor`).
3. Después filtros/scripts parametrizados.
4. Finalmente documentación de uso y migración.

## Implementation Gate (before coding)
Antes de escribir código:
1. Confirmar qué parte del contrato de config está afectada.
2. Evaluar impacto backward-compatible.
3. Definir tests/validaciones mínimas para cubrir el cambio.
4. Recién después implementar.

## Where to update what
- Reglas estables del toolkit: `AGENTS.md`
- Contexto operativo actual: `CONTEXT.md`
- Arquitectura y tradeoffs: `docs/architecture.md`
- Instalación e integración de CLI: `docs/install.md`
- Ejemplos para consumidores: `examples/` y `docs/usage.md`
