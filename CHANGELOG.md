# Changelog

Todos los cambios relevantes de este toolkit se documentan en este archivo.

Este proyecto sigue versionado semántico y mantiene dos contratos versionados:

- `VERSION` para la versión del toolkit
- `pdf.config.yaml -> version` para el contrato de configuración

## [Unreleased]

### Fixed

- `validate-config` rechaza un `pandoc.metadata_file` que no existe. Antes el renderer lo omitía en silencio, así que una ruta mal escrita producía un PDF sin los metadatos declarados y sin ningún aviso.

### Maintenance

- Consolidar revisión periódica de dependencias fijadas y documentar validación por actualización.
- Documentar guía técnica de i18n para facilitar alta de nuevos idiomas y validación de seguridad.

---

## [1.2.0] - released

### Added

- Los cinco campos del contrato que el schema declaraba obligatorios y el runtime no leía ahora tienen efecto real (mismo comportamiento en los renderers Python y Ruby):
  - `input.order`: `natural` ordena los capítulos comparando los tramos numéricos como números (`chapter-2.md` antes que `chapter-10.md`); `alphabetical` conserva el orden lexicográfico.
  - `output.keep_merged_markdown`: `false` elimina el `.md` fusionado tras un render de pandoc correcto; si pandoc falla, el `.md` se conserva para diagnóstico.
  - `document.*`: con `pandoc.metadata_file` vacío, `title`, `subtitle`, `publisher`, `author`, `date` y `rights` se pasan a pandoc como variables de plantilla (`-V campo=valor`) y rellenan la portada de `templates/default.tex`.
  - `filters.emoji.include_ballot_icons`: `false` deja las casillas de tareas Markdown (`☐`, `☑`, `☒`) como caracteres en lugar de sustituirlas por imagen.
  - `runtime.strict`: `false` reporta las dependencias ausentes como advertencias y sale con exit 0, también en la ruta de parseo YAML mínimo usada cuando no hay PyYAML. El motor TeX queda fuera del perdón: sin él no hay PDF, así que su ausencia falla siempre.
- `pandoc-pdf render -c <config> --dry-run` imprime el plan de render y no escribe nada; `--dry-run --json` lo emite como JSON (`plan_version: 1`) con capítulos en orden efectivo, dianas, `argv` de pandoc y entorno. El plan es puro: el ejecutor (`execute_plan`) es el único punto con efectos.

### Changed

- El mensaje de error por locale no indicado ya no sugiere `--team` (opción inexistente): ahora nombra la opción real, `pandoc-pdf locale set --project <lang>`.
- `--resource-path` se une con el separador de la plataforma (`os.pathsep`) en lugar de `:` hardcodeado.
- `scripts/package-release.sh` construye el árbol una sola vez y publica el mismo artefacto bajo los cuatro nombres de plataforma, en lugar de empaquetar cuatro veces.

### Fixed

- `filters/emoji.lua` ya no envuelve en `Span` el texto que no contiene emojis. Los encabezados planos dejan de emitir `\\texorpdfstring` (macro que define `hyperref`) y el filtro deja de romper plantillas mínimas. El defecto ya existía en 1.1.x: la integración L2 fallaba en `master`.
- Un valor no admitido en `input.order` falla en `render` con mensaje localizado que enumera los valores soportados (`natural`, `alphabetical`), en lugar de ordenar silenciosamente por nombre.

### Removed

- `defaults/default.yaml`: el schema pasa a ser la única fuente de verdad. El archivo era inalcanzable por el camino validado (el schema ya exige esas claves) y solo lo ejercitaba un test que llamaba al renderer saltándose el CLI.
- `defaults_path` / `defaults_exists` en `pandoc-pdf info` (texto y `--json`), porque el fichero ya no existe.
- Assets `filters/emoji/emoji_u2610.svg`, `emoji_u2611.svg` y `emoji_u2612.svg`: copias byte-idénticas de `2610.svg`, `2611.svg` y `2612.svg` que no se referenciaban y se copiaban en cada ejecución del renderer.
- El artefacto de release ya no incluye `scripts/__pycache__` ni ficheros `.pyc`.

### Tests

- 43 nuevas aserciones en `tests/run.sh`: los cinco comportamientos del contrato (`input.order`, `output.keep_merged_markdown`, `document.*`, `include_ballot_icons`, `runtime.strict`), paridad de invocación pandoc entre los renderers Python y Ruby, y el artefacto de release sin bytecode.
- Test guardado con pandoc real: el filtro de emojis no reescribe encabezados planos (`\\texorpdfstring` ausente).
- Las plantillas de `tests/integration/*` cargan `graphicx` y `hyperref`, así que L2 vuelve a verificar un render real completo.
- Nueva fixture `tests/fixtures/doctor-config-strict-false.yaml` y doble de test `tests/fixtures/yaml_shim/yaml.py` para ejercitar el renderer Python donde no hay PyYAML.

---

## [1.1.3] - released

### Fixed

- `pandoc-pdf update` ahora descarga artefactos autenticados de releases privadas usando la API de assets de GitHub (`assets[].url`) cuando hay token (`PANDOC_PDF_UPDATE_TOKEN` / `GH_TOKEN`), evitando 404 en `browser_download_url`.
- Añadido header `Accept: application/octet-stream` para descargas vía API de assets.

### Tests

- Nueva regresión en `tests/run.sh` para validar instalación por `update` usando asset API en contexto autenticado (`run_update_install_private_api_asset_test`).

---

## [1.1.2] - released

### Fixed

- Workflow `Security` estabilizado para repos con Code Scanning deshabilitado:
  - upload SARIF condicionado por variable de repositorio `ENABLE_SARIF_UPLOAD == true`.
  - se mantienen siempre los escaneos y la política de umbrales en CI.

### Changed

- Política operativa de seguridad actualizada para feature-flag de SARIF:
  - por defecto, CI valida seguridad sin depender de Code Scanning.
  - cuando se habilite Code Scanning, activar `ENABLE_SARIF_UPLOAD=true` para publicar SARIF en `push` a `main/master`.

---

## [1.1.1] - released

### Fixed

- Workflow `Security` ajustado para evitar fallos de permisos en PR (`Resource not accessible by integration`):
  - SARIF se publica sólo en `push` a `main/master`.
  - En `pull_request` se mantienen escaneos y umbrales, sin upload SARIF.
- Permisos del workflow endurecidos/afinados para upload en ramas protegidas (`actions: read`, `security-events: write`).
- Acción de upload SARIF actualizada a `github/codeql-action/upload-sarif@v4`.

### Changed

- Documentación de release-readiness actualizada con la política operativa de seguridad por evento (`push` vs `pull_request`).

---

## [1.1.0] - released

### Added

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
- Publicación de resultados de seguridad en SARIF para Semgrep y Gitleaks en GitHub Security.
- Política de umbrales de severidad para CI de seguridad mediante `scripts/enforce-security-thresholds.py`.
- Scripts de distribución:
  - `scripts/package-release.sh` (genera tarballs + checksums)
  - `scripts/install.sh` (instalación estable desde latest release sin clonar repo)
  - `scripts/install-local.sh` (instalación desde repo local al layout gestionado, con opción dev)
- Runners locales de integración:
  - `tests/l2-local.sh` (semi-real)
  - `tests/l3-local.sh` (full runtime con Mermaid)

### Changed

- CI L2/L3 ahora reutiliza los runners locales (`tests/l2-local.sh`, `tests/l3-local.sh`) para evitar drift entre ejecución local y GitHub Actions.
- Workflow de seguridad actualizado para subir SARIF y aplicar umbrales de severidad explícitos.
- Documentación sincronizada con el estado real del toolkit (comando `locale`, locales activos, estado operativo y guía i18n).

### Fixed

- Eliminados acoples i18n residuales:
  - mensajes hardcodeados en `scripts/check-i18n.py` y `scripts/prepare-emojis.py`
  - etiquetas hardcodeadas de `locale show` en `bin/pandoc-pdf`
  - cobertura incompleta de claves `bootstrap.*` en catálogos.
- Homogeneizado texto operativo en raíz (`Makefile`) para evitar mensajes legacy fuera de la estrategia i18n actual.
- Hardening del updater con validación post-instalación por versión esperada, rollback robusto y logging operativo opcional (`PANDOC_PDF_UPDATE_LOG_FILE`, `PANDOC_PDF_UPDATE_VERBOSE`).

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
