## Contexto operativo (actual)

> Este archivo refleja estado cambiante. Reglas estables viven en `AGENTS.md`.

## Snapshot

- Estado general: **CLI estable con render nativo por defecto**.
- Entry point activo: `bin/pandoc-pdf`.
- Comandos activos: `--version`, `version`, `info`, `doctor`, `validate-config -c`, `render -c`.
- Estado de suite local verificado: **PASS=76 FAIL=0** (`tests/run.sh`).
- Versión actual del toolkit (`VERSION`): **0.9.0**.

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
- ✅ Suite local `tests/run.sh` en verde (PASS=76 FAIL=0).
- ✅ CI por niveles:
  - **L1** obligatorio en PR/push (macOS/Linux)
  - **L2** integración semi-real manual
  - **L3** integración completa manual/programada (incluye Mermaid)

### 5) Documentación y gobierno
- ✅ `README.md`, `docs/install.md`, `docs/usage.md`, `docs/migration.md`, `docs/architecture.md` actualizados.
- ✅ `docs/release-readiness.md` y `docs/dependency-policy.md` activos.
- ✅ `CHANGELOG.md` reorganizado para claridad de release (1.0.0 vs Unreleased).

## Gap principal (pre 1.0)

Cerrar criterio formal de release 1.0.0 (go/no-go) con evidencia del ciclo final local/CI.

## Roadmap pendiente real (post 1.0)

1. **Hardening de seguridad en plataforma de releases**
   - evaluar publicación SARIF en GitHub
   - definir umbrales de severidad para SAST/secrets
2. **Actualización del CLI**
   - implementar `pandoc-pdf update` (Linux/macOS) según `docs/self-update-design.md`

## Riesgos activos

- Diferencias de entorno (TeX/Mermaid/Chromium) entre local y ejecución de integración completa.
- Dependencia de publicación en GitHub para cerrar automatización de reportes/updates.

## Decisiones tomadas

1. **Release 1.0.0 primero**, sin bloquear por updater.
2. `pandoc-pdf update` se mueve a **v1.1.0**.
3. SARIF/umbrales de severidad avanzados también quedan para **v1.1.0**.

## Próximo hito recomendado

### M1 — Corte 1.0.0
1. Ejecutar gate de release completo (10 checks).
2. Corregir cualquier desvío documental/operativo detectado.
3. Cortar `1.0.0` con changelog y criterios de seguridad en verde.
