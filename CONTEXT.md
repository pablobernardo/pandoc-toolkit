## Contexto operativo (actual)

> Este archivo refleja estado cambiante. Reglas estables viven en `AGENTS.md`.

## Snapshot

- Estado general: **CLI estable con render nativo por defecto**.
- Entry point activo: `bin/pandoc-pdf`.
- Comandos activos: `--version`, `version`, `info`, `locale`, `update --check`, `update`, `update --to`, `doctor`, `validate-config -c`, `render -c`.
- Estado de suite local verificado: **PASS=135 FAIL=0** (`tests/run.sh`).
- Versión actual del toolkit (`VERSION`): **1.0.0**.

## Convención activa de i18n (persistente)

- ✅ La app es **multiidioma** (locales activos: `en`, `es`, `pt`, `gl`).
- ✅ Fallback por defecto: **inglés (`en`)**.
- ✅ Política de implementación: **no hardcodear cadenas user-facing en runtime**; todas las cadenas deben salir de catálogos `i18n/locales/*.json`.
- ✅ Preferencia de estilo en español: cuando se escriba contenido en español para el proyecto, usar **español de España (es-ES)**.

## Estado por frente

### 1) CLI
- ✅ `pandoc-pdf` operativo para humanos/CI/agentes.
- ✅ `doctor` valida dependencias runtime vía `scripts/preflight.sh`.
- ✅ `validate-config` valida contrato estricto (required + tipos + campos no permitidos).
- ✅ `render` nativo desacoplado en `scripts/render-native.py` y `scripts/render-native.rb`.
- ✅ `bootstrap` simplifica onboarding (`make bootstrap*`, `scripts/bootstrap.sh`).

### 2) Configuración y rutas
- ✅ Contrato schema-driven activo (`schemas/pdf-config.schema.json`).
- ✅ Validación funcional de rutas críticas en `validate-config`:
  - `input.chapters_dir`
  - `pandoc.template` (si viene informado)
  - `filters.extra_lua_filters`
- ✅ `pandoc.template` es opcional.
- ✅ Fallback de template corregido:
  - si el usuario **no** informa `pandoc.template`, se usa el template por defecto del toolkit (`templates/default.tex`);
  - si el usuario informa `pandoc.template`, se resuelve relativo a `project.base_dir`.

### 3) Seguridad
- ✅ Preflight endurecido contra inyección (sin `bash -c` para resolver comandos de config).
- ✅ Parseo YAML seguro en Ruby (`YAML.safe_load`).
- ✅ Workflow de seguridad disponible (`.github/workflows/security.yml`: Semgrep + Gitleaks).
- ✅ Política publicada en `.github/SECURITY.md`.

### 4) Testing y CI
- ✅ Suite local `tests/run.sh` en verde (PASS=113 FAIL=0).
- ✅ CI por niveles:
  - **L1** obligatorio en PR/push (macOS/Linux)
  - **L2** integración semi-real manual
  - **L3** integración completa manual/programada (incluye Mermaid)

### 5) Documentación y gobierno
- ✅ `README.md`, `docs/install.md`, `docs/usage.md`, `docs/migration.md`, `docs/architecture.md` actualizados.
- ✅ `docs/release-readiness.md` y `docs/dependency-policy.md` activos.
- ✅ `CHANGELOG.md` reorganizado para claridad de release (1.0.0 vs Unreleased).
- ✅ Workflow de release automático disponible (`.github/workflows/release.yml`) para tags `v*`.

## Gap principal (post 1.0)

Consolidar roadmap de v1.1.0 en dos frentes principales: hardening de reportes de seguridad y updater desde releases.

## Roadmap pendiente real (post 1.0)

1. **Hardening de seguridad en plataforma de releases**
   - evaluar publicación SARIF en GitHub
   - definir umbrales de severidad para SAST/secrets
2. **Actualización del CLI**
   - ✅ `update --check` implementado
   - ✅ `update` y `update --to` implementados con descarga + checksum + instalación
   - ✅ soporte de token para repos privados (`PANDOC_PDF_UPDATE_TOKEN` / `GH_TOKEN`)
   - ✅ instalación gestionada por versiones (`~/.local/share/pandoc-pdf/versions/<tag>` + `current`)
   - ✅ bloqueo de instalación cuando se invoca como `pandoc-pdf-dev`
   - ✅ instalador inicial sin clonado (`scripts/install.sh`) basado en latest release
   - ⏳ pendiente: hardening final de rollback/observabilidad
3. **Internacionalización del CLI**
   - ✅ implementada con catálogos por clave y fallback
   - ✅ locales actuales: `en`, `es`, `pt`, `gl`
   - ✅ tests de paridad de claves/placeholders activos

## Riesgos activos

- Diferencias de entorno (TeX/Mermaid/Chromium) entre local y ejecución de integración completa.
- Dependencia de publicación en GitHub para cerrar automatización de reportes/updates.

## Decisiones tomadas

1. **Release 1.0.0 primero**, sin bloquear por updater.
2. `pandoc-pdf update` se mueve a **v1.1.0**.
3. SARIF/umbrales de severidad avanzados también quedan para **v1.1.0**.

## Próximo hito recomendado

### M2 — Inicio v1.1.0
1. Completar diseño operacional del updater y artefactos de release.
2. Cerrar política de severidad y reporting de seguridad en CI.
