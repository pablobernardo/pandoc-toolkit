# Unify the shell i18n runtime

Branch `refactor/unify-i18n`. Work landed in PR #15, squash `2c4a09a`; the landed record is in `CHANGELOG.md`. Language resolution and the translation function were implemented twice in bash (CLI and bootstrap) and a third time in Python, and every translated message cost a `python3` process.

## Specs

**S1 — A single runtime for the bash entry points**
`scripts/i18n.sh` is the only place where `resolve_lang`, `list_supported_locales`, `is_supported_locale`, `supported_locales_csv`, `normalize_lang_or_fail`, `read_project_lang`/`read_global_lang`, `t` and `interp` live. `bin/pandoc-pdf` and `scripts/bootstrap.sh` source it and do not redefine any of that.

**S2 — Translating costs no processes**
The catalog is loaded once per process and `t` resolves with bash parameter expansion, no fork. Before, `--help` launched five `python3` processes.

**S3 — Single language precedence**
Both entry points share the same chain: explicit argument → `PANDOC_PDF_LANG` → project `.pandoc-pdf.env` → `~/.config/pandoc-pdf/config.env` → `LC_ALL` → `LANG` → English. `bootstrap.sh` thus picks up the language configured with `pandoc-pdf locale set`, which it previously ignored.

**S4 — Incomplete installation is explained**
If `scripts/i18n.sh` is missing, both entry points fail with a clear message, not with the raw error of a `source` on one line of the script.

**S5 — Same texts**
The catalogs do not change: 156 keys in 4 locales, with the same texts and placeholders.

## Tasks

| ID | S# | Task | Status |
| --- | --- | --- | --- |
| T1 | S1-S3 | `scripts/i18n.sh` + wiring in both entry points | done |
| T2 | S4 | Incomplete-installation guard + test sandboxes that copy the helper | done |
| T3 | S5 | Rewrite the stub coupled to the old protocol (one fork per key) | done |
| T4 | S1-S3 | Sharing test: both source the helper, neither reimplements, bootstrap inherits the language | done |
| T5 | S5 | L1 + L2 and before/after measurement | done |

## Log

**L1 — Authorization (translated from Spanish)**
> we are not shipping a release yet, move ahead with the rest — and then: merge #13 and #14, and continue with the backlog

**L2 — Before measurement**
- `pandoc-pdf --help`: **0.188 s** on average (5 runs).
- `--help` + `info` + `locale show`: **7** `python3` processes.
- Duplication: 12 references to locale resolution in `bin/pandoc-pdf`, 8 in `scripts/bootstrap.sh`.

**L3 — After measurement**
- `pandoc-pdf --help`: **0.080 s** on average (2.3× faster).
- `--help` + `info` + `locale show`: **4** `python3` processes (the rest is real work: validating config, reading the plan).
- Isolated `--help`: **1** process, the catalog dump.

**L4 — Two mistakes of my own, fixed with evidence**
1. Four hand-made sandboxes did not copy `scripts/i18n.sh`: the CLI died at the `source` (19 failures). Fixed by copying the helper and adding the S4 guard.
2. While rewriting the test's `python3` stub for hints, I removed the `validate-config.py` bypass the original had. That made validation fail before reaching the hints and left 3 failures that looked like runtime issues. The bypass was restored: the test measures the hints, not validation.
The test itself taught me the lesson: I stopped guessing and reproduced the output by hand until I saw the message came from `validate.error.no_yaml_parser`, not from the CLI.
