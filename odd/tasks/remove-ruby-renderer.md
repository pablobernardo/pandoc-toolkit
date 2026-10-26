# Retirar el renderer Ruby

Rama `refactor/remove-ruby-renderer`. Elimina la segunda implementación del render (`scripts/render-native.rb`, 398 líneas) y deja el parseo YAML como única dependencia opcional de Ruby.

## Specs

**S1 — Un solo renderer**
`render` y `render --dry-run [--json]` se ejecutan siempre con `scripts/render-native.py`. `scripts/render-native.rb` desaparece del repositorio y del árbol de distribución.

**S2 — El parseo YAML no se rompe donde falta PyYAML**
El renderer carga el YAML con PyYAML si está disponible y, si no, delegando en el intérprete Ruby por subproceso (conversión a JSON), igual que ya hace `validate-config.py`. Sin esa red, esta máquina (python3 sin PyYAML) dejaría de poder renderizar y la suite no se podría verificar.

**S3 — Mensaje claro cuando no hay ningún parser**
Si no hay PyYAML ni Ruby, el CLI falla con el mensaje localizado existente (`cli.error.no_yaml_parser` y sus dos opciones), sin cambios de texto.

**S4 — Sin referencias huérfanas**
Fuera el `.rb` de: `bin/pandoc-pdf`, los tres `chmod` de `ci.yml`, la lista de estructura de `AGENTS.md`, las menciones en `CONTEXT.md` y `docs/i18n.md`, y los tests de paridad Python/Ruby (su motivo de existir desaparece con la segunda implementación).

**S5 — Cobertura equivalente**
La suite mantiene el pinneado del comportamiento del renderer: la paridad py/ruby se sustituye por la evidencia de que el único renderer pasa los mismos tests de contrato, plan y ejecución. Se elimina el test de paridad de plan y el de invocación de pandoc.

**S6 — Breaking declarado**
Quien invocara `scripts/render-native.rb` directamente (fuera del CLI) pierde ese camino. Se anota en `CHANGELOG` (Unreleased, sección Removed) y en `docs/migration.md`. El bump de versión se decide al publicar: el release está pospuesto por decisión del mantenedor, así que `VERSION` se queda en 1.2.0 y la nota describe el cambio como "próxima versión".

**L4 — Cierre**
- Suite **PASS=217** (eran 222: se retiran los dos tests de paridad y se añade el pin de ausencia del `.rb`), L2 exit 0, i18n 156 claves, artefacto de release con `render-native.py` y sin `render-native.rb`.
- Neto: −529 / +131 líneas; el renderer Ruby (398) desaparece y el parseo YAML mantiene su red de seguridad.

## Tasks

| ID | S# | Tarea | Estado |
| --- | --- | --- | --- |
| T1 | S1-S3 | Parseo YAML con fallback en `render-native.py`; `bin/pandoc-pdf` siempre Python; borrar `.rb` | done |
| T2 | S4-S5 | Tests: quitar paridad, reescribir los que invocaban el `.rb`, pin de ausencia | done |
| T3 | S4 | `ci.yml`, `AGENTS.md`, `CONTEXT.md`, `docs/i18n.md` | done |
| T4 | S6 | CHANGELOG (Unreleased/Removed) y migration | done |
| T5 | S1-S5 | L1 PASS=217, L2 exit 0, artefacto sin `.rb` | done |

## Log

**L1 — Autorización (verbatim)**
> no lanzamos release todavía, avanza con el resto

**L2 — Alcance medido antes de tocar código**
- `scripts/render-native.rb`: 398 líneas.
- Referencias: 2 llamadas en `bin/pandoc-pdf`, 3 `chmod` en `ci.yml`, 6 usos en `tests/run.sh` (2 de ellos tests de paridad completos), y menciones en `AGENTS.md`, `CONTEXT.md`, `docs/i18n.md`, `CHANGELOG.md` (histórico).
- `python3` de esta máquina no tiene PyYAML: el camino activo del render es el `.rb`. Retirarlo sin red de parseo dejaría el repo sin poder renderizar aquí, así que el fallback vía subproceso Ruby es requisito, no adorno.

**L3 — Decisión de diseño**
Se mantiene Ruby como *parser* opcional (subproceso, igual que `validate-config.py`) y se elimina Ruby como *renderer*. Un solo sitio donde vive la lógica de render; dos formas de leer YAML. Endurecerlo después (PyYAML obligatorio, fuera el fallback) es un slice aparte con su propia nota de migración.
