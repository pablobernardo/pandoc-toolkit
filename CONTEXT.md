## Contexto operativo (actual)

> Este archivo refleja estado cambiante. Reglas estables viven en `AGENTS.md`.

## Snapshot

- Estado general: **CLI estable con render nativo por defecto**.
- Entry point activo: `bin/pandoc-pdf`.
- Comandos activos: `--version`, `version`, `info`, `locale`, `update --check`, `update`, `update --to`, `doctor`, `validate-config -c`, `render -c`.
- Estado de suite local verificado: **PASS=207 FAIL=0** (`tests/run.sh`).
- Versión actual del toolkit (`VERSION`): **1.2.0**.

## Convención activa de i18n (persistente)

- ✅ La app es **multiidioma** (locales activos: `en`, `es`, `pt`, `gl`).
- ✅ Fallback por defecto: **inglés (`en`)**.
- ✅ Política de implementación: **no hardcodear cadenas user-facing en runtime**; todas las cadenas deben salir de catálogos `i18n/locales/*.json`.
- ✅ Preferencia de estilo en español: cuando se escriba contenido en español para el proyecto, usar **español de España (es-ES)**.
- ✅ Un solo runtime de shell para i18n: `scripts/i18n.sh`, compartido por `bin/pandoc-pdf` y `scripts/bootstrap.sh`; el catálogo se carga una vez y `t` no lanza procesos.

## Estado por frente

### 1) CLI
- ✅ `pandoc-pdf` operativo para humanos/CI/agentes.
- ✅ `doctor` valida dependencias runtime vía `scripts/preflight.sh`.
- ✅ `validate-config` valida contrato estricto (required + tipos + campos no permitidos).
- ✅ `render` nativo con un único renderer en `scripts/render-native.py` (el duplicado en Ruby se retiró).
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
- ✅ Suite local `tests/run.sh` en verde (PASS=207 FAIL=0).
- ✅ CI por niveles:
  - **L1** obligatorio en PR/push (macOS/Linux)
  - **L2** integración semi-real manual
  - **L3** integración completa manual/programada (incluye Mermaid)

### 5) Documentación y gobierno
- ✅ `README.md`, `docs/install.md`, `docs/usage.md`, `docs/migration.md`, `docs/architecture.md` actualizados.
- ✅ `docs/release-readiness.md` y `docs/dependency-policy.md` activos.
- ✅ `CHANGELOG.md` reorganizado para claridad de release (1.0.0 vs Unreleased).
- ✅ Workflow de release automático disponible (`.github/workflows/release.yml`) para tags `v*`.

## Migración a binario (Go) — decisión pendiente

Estado: **no se migra ahora**. Windows no es un requisito actual y el consumo real del toolkit es Linux/macOS. La puerta queda abierta de forma explícita.

Puerta abierta (lo que se construiría antes de decidir):

1. ✅ `render --dry-run --json`: hecho (ver sección anterior).
2. Una suite de conformidad sobre ese plan, ejecutable contra cualquier implementación (actual en bash/Python/Ruby y una futura en Go), para comparar salida sin leer código.

Disparadores de migración (cualquiera de ellos):

- (a) Windows pasa a ser un requisito real del toolkit.
- (b) Un consumidor objetivo no puede tener `python3` + PyYAML en su entorno.
- (c) Se necesitan artefactos firmados de fichero único para supply chain.
- (d) Los defectos del updater en bash cuestan más que una reescritura.

## Plan de render (`--dry-run --json`)

Implementado en 1.2.0: `pandoc-pdf render -c <config> --dry-run [--json]` calcula un plan puro (sin escribir nada) con capítulos, dianas, `argv` de pandoc y entorno. `scripts/render-native.py` está partido en `build_plan` (puro), `execute_plan` (único punto con efectos) y `print_plan`. Había un duplicado en Ruby que se retiró: el parseo YAML usa PyYAML si está y, si no, Ruby por subproceso.

## Contrato de configuración: una sola fuente

`schemas/pdf-config.schema.json` es la única fuente de verdad. No hay fichero de defaults que fusionar: `render` valida el config del usuario y aplica solo los fallbacks históricos de código para claves ausentes. Decisión tomada en 1.2.0 (antes el baseline era inalcanzable por el camino validado).

## Slices pendientes (post 1.2.0)

1. ✅ Plan JSON `--dry-run --json` y decisión de defaults: `defaults/default.yaml` retirado, el schema es la única fuente de verdad.
2. **Retiro del renderer Ruby**: mantener un solo runtime cuando el plan JSON y la conformidad estén verdes.
3. **Unificación de i18n**: hoy hay catálogos consumidos desde bash y desde los renderers Python/Ruby.
4. **Hardening del validador de schema**: cobertura más estricta que el `additionalProperties: false` actual.
5. **Partir `tests/run.sh`**: es un monolito compartido por todas las áreas; conviene separarlo por dominio antes de seguir creciendo.

## Gap principal (post 1.1)

Sin bloqueantes técnicos abiertos para el contrato Linux/macOS del toolkit.

## Roadmap pendiente real (post 1.1)

1. **Soporte Windows (futuro)**
   - diseñar extensión de updater/instalación sin romper contrato CLI actual.
2. **Hardening de supply chain (iteración siguiente)**
   - evaluar firma criptográfica de artefactos (Sigstore/GPG).

## Revisión nativa (RDD) — bloqueada por límite del proveedor

Estado: **no disponible para esta rama**. Dos intentos, mismo revisor y mismo límite:

| lineage | candidato | resultado |
| --- | --- | --- |
| `review-d3a0f85c95b06577` | rama hasta `31bc09b` (1.088 líneas) | falla en `review-resilience` |
| `review-53a11f26c014de04` | slice plan+defaults (1.159 líneas) | falla en `review-resilience` |

Motivo: `reasoning-only stream guard: 420 s / 45.000 reasoning-character limit` en el modelo que sirve la lente de resiliencia, con `prepared_reviewers: 0` y sin mutación. Con tier `high` el proveedor exige las cuatro lentes, así que no se puede rescatar un subconjunto.

Consecuencias operativas:

- Ningún lineage está corrupto; ambos quedan en estado `reviewing`. **No se abandonan** sin decisión explícita del mantenedor (operación auditada y destructiva).
- La revisión efectiva de la rama es la **revisión humana del PR**.
- Si se quiere reintentar: candidatos por commit (≈200-600 líneas) en lugar de la rama completa; el guard salta por volumen de diff, no por tipo de cambio.

## Verificación por commit

Los 10 commits de la rama pasan `tests/run.sh` de forma independiente (verificado extrayendo cada árbol con `git archive` y ejecutando la suite): `75f6dc9`, `bfb5d8f`, `ae9cb3b`, `2b622ca`, `31bc09b`, `b4dab34`, `443e9ec`, `5a25fef`, `9b22148`, `e61657a`.

## Decisiones de la revisión de 1.2.0

| # | Decisión |
| --- | --- |
| A1 | Precedencia de metadatos: si `pandoc.metadata_file` está informado, manda el fichero y no se pasan variables `-V`; si está vacío, `title`, `subtitle`, `publisher`, `author`, `date` y `rights` se pasan como variables de plantilla. |
| A2 | `runtime.strict: false` perdona dependencias auxiliares, nunca el motor TeX: sin motor no hay PDF, así que falla siempre. |
| A3 | La forma del plan (`plan_version: 1`) se congela tal cual: `cwd: null` (heredado), `env` con las cuatro variables del toolkit y `prepare_argv[0]` como token neutro `python3`. Cualquier cambio de forma pide `plan_version: 2`. |
| A4 | `defaults/default.yaml` retirado: `schemas/pdf-config.schema.json` es la única fuente de verdad del contrato. |

## Riesgos activos

- Diferencias de entorno (TeX/Mermaid/Chromium) entre local y ejecución de integración completa.
- Revisión nativa (RDD) indisponible por límite del proveedor: la cobertura externa de esta rama depende de la revisión humana del PR.
- Dependencia de publicación en GitHub para cerrar automatización de reportes/updates.

## Decisiones tomadas

1. **Release 1.0.0 primero**, sin bloquear por updater.
2. `pandoc-pdf update` se entregó en **v1.1.0** con rollback + observabilidad.
3. Seguridad CI en **v1.1.0**: SARIF + umbrales explícitos para SAST/secrets.

## Próximo hito recomendado

### M3 — Preparación multi-plataforma
1. Diseñar estrategia de soporte Windows en updater/install.
2. Evaluar firma de artefactos para reforzar supply chain.
