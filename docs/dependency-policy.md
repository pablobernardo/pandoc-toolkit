# Política de dependencias

## Objetivo

Reducir riesgo de cadena de suministro mediante versiones fijadas en runtime crítico y una cadencia de actualización explícita.

## Dependencias críticas fijadas

- `@mermaid-js/mermaid-cli@10.9.1`
  - Uso: `scripts/bootstrap.sh`, workflow L3 en `.github/workflows/ci.yml`.
- `pyyaml==6.0.2`
  - Uso: `scripts/bootstrap.sh` (instalación asistida cuando falta parser YAML).
- `semgrep==1.86.0`
  - Uso: `.github/workflows/security.yml`.
- `gitleaks:v8.24.2`
  - Uso: `.github/workflows/security.yml`.

## Cadencia de actualización

- Revisión **mensual** de dependencias críticas.
- Revisión extraordinaria ante CVE o advisory relevante.

## Proceso de actualización

1. Actualizar versión fijada en bootstrap/workflows.
2. Ejecutar `tests/run.sh`.
3. Ejecutar workflow de seguridad (`security.yml`).
4. Actualizar `CHANGELOG.md` (Unreleased) y, si aplica, `docs/release-readiness.md`.

## Criterios de aceptación

- Sin regresiones funcionales (`tests/run.sh` en verde).
- Escaneos de seguridad sin hallazgos críticos nuevos.
- Documentación sincronizada.
