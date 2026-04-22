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
