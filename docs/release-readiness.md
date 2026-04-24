# Release Readiness — Seguridad

Checklist de referencia para decidir si el toolkit está listo para publicar una versión.

## Estado actual (post-1.0.0)

## Decisiones de gobierno aprobadas

- **Versionado dual**: `VERSION` (toolkit semver) + `pdf.config.yaml -> version` (contrato).
- **`runtime.strict` por defecto**: `true`.
- **Política de errores**: fail-fast por defecto y degradación controlada solo en rutas no críticas.

### Criterios mínimos de seguridad (bloqueantes)

- [x] **Entrada de comandos saneada** en `runtime.required_commands`.
- [x] **Sin shell con interpolación insegura** para detectar comandos.
- [x] **Carga YAML segura** en rutas Ruby (`YAML.safe_load`).
- [x] **Tests de regresión de seguridad** añadidos y en verde.
- [x] **Política de seguridad publicada** (`.github/SECURITY.md`).
- [x] **Modelo de confianza documentado** (uso de configs confiables).

Resultado: **cumplido para corte 1.0.0**.

### Hardening recomendado (no bloqueante)

- [x] Definir `permissions: contents: read` en workflows de GitHub Actions.
- [x] Fijar versiones de dependencias críticas en bootstrap/CI (por ejemplo `@mermaid-js/mermaid-cli`).
- [x] Añadir automatización de actualizaciones (`dependabot.yml`).
- [x] Añadir escaneo básico de secretos/SAST en CI.

### Integración L3 (seguimiento)

- [x] Fixture L3 con Mermaid real (`tests/integration/l3-mermaid-project/`).
- [x] Validación en CI L3 de salida PNG de Mermaid.

## Criterio de decisión

- Si todos los criterios bloqueantes están en verde: se puede publicar versión inicial.
- Si además se completan los no bloqueantes: release más robusta para adopción enterprise.
