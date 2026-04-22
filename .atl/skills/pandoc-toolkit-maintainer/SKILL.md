---
name: pandoc-toolkit-maintainer
description: >
  Skill operativa para mantener el toolkit pandoc-pdf con cambios consistentes en contrato,
  render, CI y documentación.
  Trigger: cuando se modifique schema/config, render/preflight, tests, CI o documentación técnica del toolkit.
license: Apache-2.0
metadata:
  author: pablobernardo
  version: "1.0"
---

## Cuándo usar

- Cuando un cambio afecta al contrato (`schemas/pdf-config.schema.json`, defaults o estructura de `pdf.config.yaml`).
- Cuando se modifica render, preflight o validación de configuración.
- Cuando se tocan tests de integración, pipeline de CI o documentación de uso/migración.

## Patrones críticos

1. **Contrato primero, implementación después**
   - Si cambia config/schema: actualizar primero schema y fixtures; después CLI/scripts; después docs.

2. **Sincronización obligatoria**
   - Si se cambia comportamiento funcional, actualizar en la misma tarea:
     - tests (`tests/run.sh` y fixtures),
     - documentación (`README.md`, `docs/usage.md`, `docs/migration.md`),
     - contexto/estado (`CONTEXT.md` si aplica).

3. **Validación mínima de salida**
   - Ejecutar siempre `tests/run.sh` antes de cerrar.
   - Si hay cambios de integración real/CI, proponer ejecución L2 o L3.

4. **No introducir deuda legacy**
   - No reintroducir scripts legacy ni rutas acopladas.
   - Mantener rutas declarativas y resolución respecto a `project.base_dir`.

## Checklist operativo

- [ ] Cambio clasificado: contrato, implementación, tests, docs, CI.
- [ ] Fixtures y tests actualizados para el comportamiento nuevo.
- [ ] `tests/run.sh` en verde.
- [ ] Documentación alineada con el estado real.
- [ ] Sin referencias a rutas o scripts legacy retirados.

## Árbol de decisión rápido

| Si cambias... | Debes tocar también... |
| --- | --- |
| `schemas/pdf-config.schema.json` | `tests/fixtures/*`, `tests/run.sh`, `docs/usage.md` |
| `scripts/render-native.*` | `tests/run.sh`, fixtures de render, `docs/usage.md` |
| `scripts/preflight.*` o `validate-config.py` | tests de doctor/validate, `docs/usage.md` |
| `.github/workflows/ci.yml` | `README.md`, `docs/usage.md` |
| defaults o plantilla base | `examples/`, fixtures afectados, docs |

## Comandos

```bash
pandoc-pdf doctor
pandoc-pdf validate-config -c examples/pdf.config.example.yaml
tests/run.sh
```

## Recursos

- **Normativa de agentes**: `../../skill-registry.md`
- **Arquitectura**: `../../../docs/architecture.md`
- **Uso operativo**: `../../../docs/usage.md`
- **Migración**: `../../../docs/migration.md`
