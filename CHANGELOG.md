# Changelog

Todos los cambios relevantes de este toolkit se documentan en este archivo.

Este proyecto sigue versionado semántico y mantiene dos contratos versionados:

- `VERSION` para la versión del toolkit
- `pdf.config.yaml -> version` para el contrato de configuración

## [Unreleased]

### Planned (v1.1.0)

- Evaluar publicación de hallazgos de seguridad en formato SARIF.
- Definir umbrales de severidad y política de fallo para SAST/secrets en CI.
- Completar hardening del updater (`pandoc-pdf update`) con rollback robusto y mejoras de observabilidad.

### Maintenance

- Consolidar revisión periódica de dependencias fijadas y documentar validación por actualización.
- Documentar guía técnica de i18n para facilitar alta de nuevos idiomas y validación de seguridad.

### Added (Unreleased)

- i18n del CLI y scripts de runtime con catálogos por clave en `en`, `es`, `pt` y `gl`.
- Comando `pandoc-pdf locale` simplificado a `show`, `set <lang>` y `set --project <lang>`.
- Soporte de configuración global de idioma en `~/.config/pandoc-pdf/config.env`.
- Validación de paridad de catálogos/placeholders (`scripts/check-i18n.py`) integrada en tests.
- Nuevo comando `pandoc-pdf update --check` para comprobar última versión estable en GitHub Releases.
- Nuevos comandos de actualización desde release:
  - `pandoc-pdf update`
  - `pandoc-pdf update --to <tag>`
  - soporte `--yes`, `--dry-run`, `--install-dir`
- Soporte de autenticación para repositorios privados en updater mediante `PANDOC_PDF_UPDATE_TOKEN` o `GH_TOKEN`.
- Instalación gestionada del updater en directorio versionado (`~/.local/share/pandoc-pdf/versions/<tag>`) con puntero `current`.
- Bloqueo explícito de instalación con `update` cuando el comando se invoca como `pandoc-pdf-dev`.
- Workflow automático de release (`.github/workflows/release.yml`) para publicar artefactos y `checksums.txt` en tags `v*`.
- Scripts de distribución:
  - `scripts/package-release.sh` (genera tarballs + checksums)
  - `scripts/install.sh` (instalación estable desde latest release sin clonar repo)
  - `scripts/install-local.sh` (instalación desde repo local al layout gestionado, con opción dev)
- Runners locales de integración:
  - `tests/l2-local.sh` (semi-real)
  - `tests/l3-local.sh` (full runtime con Mermaid)

### Changed (Unreleased)

- CI L2/L3 ahora reutiliza los runners locales (`tests/l2-local.sh`, `tests/l3-local.sh`) para evitar drift entre ejecución local y GitHub Actions.
- Documentación sincronizada con el estado real del toolkit (comando `locale`, locales activos, estado operativo y guía i18n).

### Fixed (Unreleased)

- Eliminados acoples i18n residuales:
  - mensajes hardcodeados en `scripts/check-i18n.py` y `scripts/prepare-emojis.py`
  - etiquetas hardcodeadas de `locale show` en `bin/pandoc-pdf`
  - cobertura incompleta de claves `bootstrap.*` en catálogos.
- Homogeneizado texto operativo en raíz (`Makefile`) para evitar mensajes legacy fuera de la estrategia i18n actual.

---

## [1.0.0] - released

Primera versión estable pública del toolkit.

### Added

- CLI estable `bin/pandoc-pdf` con comandos:
  - `--version` / `version`
  - `info` / `info --json`
  - `doctor`
  - `validate-config -c <file>`
  - `render -c <file>` (modo nativo por defecto)
- `VERSION` como fuente canónica de versión del toolkit.
- `scripts/preflight.sh` como chequeo runtime desacoplado.
- Render nativo desacoplado en:
  - `scripts/render-native.py`
  - `scripts/render-native.rb`
- Contrato de config versionado con:
  - `schemas/pdf-config.schema.json`
  - `examples/pdf.config.example.yaml`
  - `defaults/default.yaml`
  - `templates/default.tex`
- Suite de tests `tests/run.sh` con fixtures de contrato/render/integración.
- CI por niveles:
  - L1 (rápido, PR/push)
  - L2 (semi-real, manual)
  - L3 (integración completa, manual/programada)
- Workflow de seguridad dedicado (`.github/workflows/security.yml`: Semgrep + Gitleaks).
- Dependabot (`.github/dependabot.yml`).
- Documentación operativa:
  - `README.md`
  - `docs/install.md`
  - `docs/usage.md`
  - `docs/migration.md`
  - `docs/architecture.md`
  - `docs/release-readiness.md`
  - `docs/dependency-policy.md`
- Gobierno y seguridad:
  - `LICENSE` (Apache-2.0)
  - `.github/CODEOWNERS`
  - `.github/SECURITY.md`

### Changed

- `validate-config` pasó a validación estricta y schema-driven (required, tipos, `additionalProperties`).
- `pandoc.template` pasó a opcional en schema.
- `doctor` delega en `scripts/preflight.sh`.
- `render` dejó fallback legacy y opera en modo nativo por defecto.
- `bootstrap` mejorado con detección de gestores Linux (`apt-get`, `dnf`, `yum`, `pacman`, `zypper`, `apk`).
- CI endurecido con permisos mínimos (`permissions: contents: read`).
- Dependencias críticas fijadas en bootstrap/CI/security (`mermaid-cli`, `PyYAML`, `Semgrep`, `Gitleaks`).
- Plantilla base movida de raíz a `templates/default.tex`.
- Limpieza de scripts legacy y artefactos obsoletos.

### Fixed

- Hardening de preflight contra inyección (sin `bash -c`; validación de `runtime.required_commands`).
- Carga YAML segura en Ruby (`YAML.safe_load`) para validación, preflight y render nativo.
- Tests robustecidos en PATH aislado y asserts (`grep --`).
- Regresión corregida en fallback de template:
  - si el usuario **no** informa `pandoc.template`, se usa el template por defecto del toolkit;
  - si el usuario informa `pandoc.template`, se resuelve relativo a `project.base_dir`.
