# Unificar el runtime i18n del shell

Rama `refactor/unify-i18n`. La resolución de idioma y la función de traducción estaban implementadas dos veces en bash (CLI y bootstrap) y una tercera en Python, y cada mensaje traducido costaba un proceso `python3`.

## Specs

**S1 — Un único runtime para los entry points de bash**
`scripts/i18n.sh` es el único sitio donde viven `resolve_lang`, `list_supported_locales`, `is_supported_locale`, `supported_locales_csv`, `normalize_lang_or_fail`, `read_project_lang`/`read_global_lang`, `t` e `interp`. `bin/pandoc-pdf` y `scripts/bootstrap.sh` lo sourcean y no redefinen nada de eso.

**S2 — Traducir no cuesta procesos**
El catálogo se carga una vez por proceso y `t` resuelve con expansión de parámetros de bash, sin fork. Antes, `--help` lanzaba cinco `python3`.

**S3 — Precedencia única de idioma**
Ambos entry points comparten la misma cadena: argumento explícito → `PANDOC_PDF_LANG` → `.pandoc-pdf.env` del proyecto → `~/.config/pandoc-pdf/config.env` → `LC_ALL` → `LANG` → inglés. `bootstrap.sh` gana así el idioma configurado con `pandoc-pdf locale set`, que antes ignoraba.

**S4 — Instalación incompleta se explica**
Si falta `scripts/i18n.sh`, los dos entry points fallan con un mensaje claro, no con el error crudo de `source` en una línea del script.

**S5 — Mismos textos**
Los catálogos no cambian: 156 claves en 4 locales, con los mismos textos y placeholders.

## Tasks

| ID | S# | Tarea | Estado |
| --- | --- | --- | --- |
| T1 | S1-S3 | `scripts/i18n.sh` + cableado en ambos entry points | done |
| T2 | S4 | Guard de instalación incompleta + sandboxes de test que copian el helper | done |
| T3 | S5 | Reescribir el stub acoplado al protocolo viejo (un fork por clave) | done |
| T4 | S1-S3 | Test de compartición: ambos sourcean el helper, ninguno reimplementa, bootstrap hereda idioma | done |
| T5 | S5 | L1 + L2 y medición antes/después | done |

## Log

**L1 — Autorización (verbatim)**
> no lanzamos release todavía, avanza con el resto — y después: mergea #13 y #14, y sigue con el backlog

**L2 — Medición antes**
- `pandoc-pdf --help`: **0,188 s** de media (5 ejecuciones).
- `--help` + `info` + `locale show`: **7** procesos `python3`.
- Duplicación: 12 referencias a la resolución de locale en `bin/pandoc-pdf`, 8 en `scripts/bootstrap.sh`.

**L3 — Medición después**
- `pandoc-pdf --help`: **0,080 s** de media (2,3× más rápido).
- `--help` + `info` + `locale show`: **4** procesos `python3` (el resto ya es trabajo real: validar config, leer el plan).
- `--help` aislado: **1** proceso, el volcado del catálogo.

**L4 — Dos errores propios, corregidos con evidencia**
1. Cuatro sandboxes hechas a mano no copiaban `scripts/i18n.sh`: el CLI moría en el `source` (19 fallos). Se arregló copiando el helper y añadiendo el guard de S4.
2. Al reescribir el stub de `python3` del test de hints, quité el bypass de `validate-config.py` que tenía el original. Eso hacía fallar la validación antes de llegar a los hints y dejaba 3 fallos que parecían del runtime. Se restauró el bypass: el test mide los hints, no la validación.
La lección me la dio el propio test: dejé de adivinar y reproduje la salida a mano hasta ver que el mensaje venía de `validate.error.no_yaml_parser`, no del CLI.
