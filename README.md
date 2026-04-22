# Pandoc PDF Toolkit

![CI](https://img.shields.io/badge/CI-configured-blue)

[![CI](https://github.com/pablobernardo/pandoc-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/pablobernardo/pandoc-toolkit/actions/workflows/ci.yml)

Toolkit agnóstico para generar PDF con Pandoc vía CLI (`pandoc-pdf`) usando configuración declarativa por repo consumidor (`pdf.config.yaml`).

## Comandos principales

```bash
pandoc-pdf --version
pandoc-pdf info
pandoc-pdf doctor
pandoc-pdf validate-config -c pdf.config.yaml
pandoc-pdf render -c pdf.config.yaml
```

## Onboarding rápido

```bash
make bootstrap
```

Opcional (sin ejecutar cambios):

```bash
make bootstrap-dry
# modo no interactivo
make bootstrap-yes
# modo CI (no interactivo, sin symlink)
make bootstrap-ci
```

## CI

- Workflow principal: `.github/workflows/ci.yml`
- Niveles actuales:
  - **L1**: `tests/run.sh` en matriz macOS/Linux (PR/push).
  - **L2**: integración semi-real (manual, `workflow_dispatch`).
  - **L3**: integración completa con Mermaid CLI (manual o programada).

### Ejecución manual (workflow_dispatch)

Desde **Actions → CI → Run workflow** puedes activar:

- `run_render_integration=true` para lanzar **L2**.
- `run_render_full=true` para lanzar **L3**.

#### Desde GitHub UI
1. Ir a **Actions** → **CI**.
2. Haz clic en **Run workflow**.
3. Activar el input que necesites (`run_render_integration` o `run_render_full`).
4. Ejecutar.

#### Desde `gh` CLI

```bash
gh workflow run ci.yml -f run_render_integration=true
# o
gh workflow run ci.yml -f run_render_full=true
```

Ver ejecución:

```bash
gh run list --workflow ci.yml
gh run view --log
```

## Documentación

- `docs/install.md` — instalación y PATH
- `docs/usage.md` — uso operativo y tests
- `docs/migration.md` — migración desde legacy
- `docs/architecture.md` — arquitectura y tradeoffs
- `docs/release-readiness.md` — checklist de preparación de release
- `docs/dependency-policy.md` — política de dependencias y actualizaciones
- `.atl/skill-registry.md` — normas operativas para agentes
- `CONTEXT.md` — estado operativo actual del proyecto
- `.github/SECURITY.md` — política de seguridad y reporte de vulnerabilidades

## Housekeeping del repositorio

Para mantener el toolkit limpio y reusable:

- **No** agregar artefactos locales de sistema (`.DS_Store`, etc.).
- **No** reintroducir scripts legacy acoplados al repo consumidor.
- Usar siempre el entrypoint oficial: `bin/pandoc-pdf`.
- Mantener ejemplos y docs neutrales (sin datos privados ni rutas de cliente).

## Autor

Pablo Bernardo — https://github.com/pablobernardo
