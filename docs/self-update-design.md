# Diseño — Self-update desde GitHub Releases (Linux/macOS)

## 1) Objetivo

Incorporar una capacidad de actualización del CLI `pandoc-pdf` desde GitHub Releases con foco en:

- experiencia simple para el usuario,
- seguridad de cadena de suministro,
- compatibilidad con instalaciones actuales del toolkit.

Alcance inicial: **Linux + macOS**.

---

## 2) Alcance y no alcance

### En alcance (v1)

- `update --check` para consultar si hay una versión nueva.
- `update` para instalar la última versión estable.
- `update --to <tag>` para instalar una versión específica.
- Verificación de integridad por checksum SHA256.
- Reemplazo seguro del binario con backup/rollback.

### Fuera de alcance (v1)

- Soporte Windows nativo.
- Canales múltiples (`beta`, `rc`, `nightly`).
- Firma criptográfica avanzada (Sigstore/GPG) en la primera iteración.

---

## 3) Contrato CLI propuesto

```bash
pandoc-pdf update --check
pandoc-pdf update
pandoc-pdf update --to vX.Y.Z
```

Flags recomendados:

- `--yes`: modo no interactivo (sin confirmaciones).
- `--dry-run`: muestra acciones sin modificar sistema.
- `--install-dir <path>`: sobreescribe el destino de instalación.

### Exit codes

- `0`: operación exitosa.
- `1`: error operativo (red, parseo release, permisos, checksum, plataforma no soportada).

---

## 4) Modelo de artefactos en release

Cada tag `vX.Y.Z` debe publicar:

- `pandoc-pdf_darwin_amd64.tar.gz`
- `pandoc-pdf_darwin_arm64.tar.gz`
- `pandoc-pdf_linux_amd64.tar.gz`
- (opcional v1.1) `pandoc-pdf_linux_arm64.tar.gz`
- `checksums.txt` (SHA256 de todos los artefactos)

Contenido esperado dentro de cada tarball:

- ejecutable `pandoc-pdf`
- `VERSION` (opcional, si el ejecutable ya expone versión embebida)

---

## 5) Flujo funcional

### 5.1 `update --check`

1. Leer versión local (`pandoc-pdf --version`).
2. Consultar release estable más reciente en GitHub.
3. Comparar semver local vs remota.
4. Informar estado (al día / update disponible).

### 5.2 `update` / `update --to`

1. Resolver versión destino (`latest` o tag explícita).
2. Detectar `OS` y `ARCH`.
3. Seleccionar artefacto correspondiente.
4. Descargar artefacto + `checksums.txt` a directorio temporal.
5. Verificar SHA256 del artefacto.
6. Extraer y validar que `pandoc-pdf` sea ejecutable.
7. Ejecutar verificación rápida del artefacto (`--version`).
8. Crear backup del ejecutable actual.
9. Reemplazar en forma atómica.
10. Verificar versión post-instalación.
11. Si falla cualquier validación final: rollback desde backup.

---

## 6) Reglas de seguridad mínimas

1. **No instalar si falta `checksums.txt`.**
2. **No instalar si checksum no coincide.**
3. **No ejecutar scripts remotos** durante update.
4. **No hacer downgrade implícito** (solo con `--to` explícito).
5. **No usar canales prerelease** en v1.

---

## 7) Compatibilidad de instalación

Orden recomendado para destino de instalación:

1. `--install-dir` explícito (si se informa).
2. Directorio del ejecutable actual (si es escribible).
3. fallback sugerido: `~/.local/bin`.

Si no hay permisos de escritura, el comando debe fallar con instrucción accionable clara.

---

## 8) Estrategia de observabilidad/UX

- Mensajes claros por etapa: resolver release, descargar, verificar, instalar, validar.
- En `--dry-run`, mostrar URL y rutas objetivo sin escribir disco.
- En error, mostrar causa y próximo paso (reintentar, permisos, red, tag inexistente).

---

## 9) Plan de validación (tests)

Casos mínimos:

- `update --check` (sin update y con update disponible).
- Plataforma no soportada.
- `--to` con tag inexistente.
- Checksum faltante o inválido.
- Artefacto corrupto.
- Permisos insuficientes en destino.
- Rollback exitoso tras fallo post-instalación.

---

## 10) Fases de implementación recomendadas

### Fase 1 — Descubrimiento seguro

- Entregar `update --check`.
- Definir contrato de artefactos de release.

### Fase 2 — Instalación segura

- Entregar `update` y `update --to`.
- Activar checksum + backup + rollback.

### Fase 3 — Hardening

- Añadir mejoras de telemetría/logs.
- Evaluar firma criptográfica de artefactos.

---

## 11) Tradeoffs de la decisión Linux/macOS first

### Ventajas

- Menor complejidad inicial.
- Entrega más rápida.
- Alineado con soporte actual del toolkit.

### Coste

- Windows queda para iteración posterior.

Decisión recomendada: **avanzar con Linux/macOS primero** y diseñar extensión a Windows sin romper contrato CLI.
