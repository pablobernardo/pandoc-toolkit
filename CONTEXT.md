## Contexto operativo (actual)

> Este archivo refleja estado cambiante. Reglas estables viven en `AGENTS.md`.

## Snapshot

- Estado general: **CLI estable con render nativo por defecto**.
- Entry point activo: `bin/pandoc-pdf`.
- Comandos activos: `--version`, `version`, `info`, `locale`, `update --check`, `update`, `update --to`, `doctor`, `validate-config -c`, `render -c`.
- Estado de suite local verificado: **PASS=143 FAIL=0** (`tests/run.sh`).
- Versión actual del toolkit (`VERSION`): **1.1.0**.

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

## Gap principal (post 1.1)

Sin bloqueantes técnicos abiertos para el contrato Linux/macOS del toolkit.

## Roadmap pendiente real (post 1.1)

1. **Soporte Windows (futuro)**
   - diseñar extensión de updater/instalación sin romper contrato CLI actual.
2. **Hardening de supply chain (iteración siguiente)**
   - evaluar firma criptográfica de artefactos (Sigstore/GPG).

## Riesgos activos

- Diferencias de entorno (TeX/Mermaid/Chromium) entre local y ejecución de integración completa.
- Dependencia de publicación en GitHub para cerrar automatización de reportes/updates.

## Decisiones tomadas

1. **Release 1.0.0 primero**, sin bloquear por updater.
2. `pandoc-pdf update` se entregó en **v1.1.0** con rollback + observabilidad.
3. Seguridad CI en **v1.1.0**: SARIF + umbrales explícitos para SAST/secrets.

## Próximo hito recomendado

### M3 — Preparación multi-plataforma
1. Diseñar estrategia de soporte Windows en updater/install.
2. Evaluar firma de artefactos para reforzar supply chain.
