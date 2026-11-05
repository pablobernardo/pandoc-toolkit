# Make the updater honour the installation the user declared
Branch: `fix/update-install-location`; delivery: one code PR closing #147.
Scope: `bin/pandoc-pdf` location resolution, catalogs, the updater tests, documentation. The managed layout and the installers do not change.

## Specs

- S1: `pandoc-pdf update` honours `PANDOC_PDF_INSTALL_HOME` and `PANDOC_PDF_INSTALL_DIR`, which `scripts/delivery/install.sh:8-9` and `scripts/delivery/install-local.sh:4-5` already honour. Maintainer, verbatim: "`pandoc-pdf update` ignora PANDOC_PDF_INSTALL_HOME y PANDOC_PDF_INSTALL_DIR (install.sh sí los respeta), así que en una instalación gestionada no estándar escribe en ~/.local/share/pandoc-pdf sin avisar."
- S2: The manager never writes to the default location when another one was declared. Never silently: refusing with an explanation would be acceptable, writing elsewhere without a word is not.
- S3: Managed root precedence: `PANDOC_PDF_UPDATE_HOME` → `PANDOC_PDF_INSTALL_HOME` → `${HOME}/.local/share/pandoc-pdf`. The variable named for this command wins over the general one.
- S4: Binary-directory precedence: `--install-dir` → `PANDOC_PDF_INSTALL_DIR` → the directory of the `pandoc-pdf` resolved on `PATH` when writable → `${HOME}/.local/bin`. A declared location beats the `PATH` heuristic.
- S5: An installation that declares neither variable resolves exactly as it does today. Proven differentially against the parent commit: same stdout, same stderr, same exit code for the resolution cases, without touching the network.
- S6: The development install stays isolated: it never writes `current`, it lives in `versions/v<version>-dev`, and `pandoc-pdf-dev` still refuses to run the updater (`cli.update.error.dev_blocked`). Verified today by execution; the change must not alter it, and a test must keep it that way.
- S7: Every new user-facing string exists in all four catalogs (`i18n/locales/{en,es,gl,pt}.json`) and passes `check-i18n`. No literal message in code.
- S8: `--install-dir` and `PANDOC_PDF_UPDATE_HOME` are absent from the `update` usage text today; the help and `docs/` describe the resolution after this change, in particular that the declared location beats `PATH`.

## Tasks

- T1 [S1–S8] done; route: delegated worker, verified by the parent; `resolve_install_dir` and `resolve_managed_home` read the installer variables with the S3/S4 precedence, the earlier line ``pandoc-pdf-dev`` block stays untouched, one new catalog key in four locales, `run_update_resolution_precedence_tests` registered in `tests/run.sh:42`, `docs/usage.md` and `docs/install.md` describe the order, and the `[Unreleased]` changelog entry records it. RED 6/2 with exactly the two new-precedence assertions failing, GREEN 10/0; the S5 differential compared stdout, stderr and exit code against `git show main:bin/pandoc-pdf` over four resolution cases and found them identical; full suite 561/0, 177 i18n keys, 74 documentation files, 4 conforming plans.

## Log

- L1 — Maintainer, verbatim: "el 1 es lo mejor no? pero comprueba que hacer `make install-local-dev` no cambie current que no tengo claro si pueden colisionar"
- L2 — Answer, verified by execution, not by reading: `install-local.sh dev` leaves `current` untouched after a release install, does not create `current` when it is the only install, and re-running it leaves the stable `versions/v2.5.0` byte-identical. The paths cannot collide (`v2.5.0` vs `v2.5.0-dev`), the development entrypoint is `pandoc-pdf-dev`, and `bin/pandoc-pdf:415-417` blocks the updater when it is invoked under that name. Honouring `PANDOC_PDF_INSTALL_HOME` therefore cannot disturb a development install.
- L3 — Maintainer chose option 1 of the three proposed mechanisms: read the variables the installers already use, instead of following the `current` link or refusing.
- L4 — Parent verification, independent of the worker's report: the original #147 reproduction now names the declared binary directory in its prompt and creates the managed tree in the declared home, where on `d7f1339` it named `$HOME/.local/bin` and created `$HOME/.local/share/pandoc-pdf/versions`. The `pandoc-pdf-dev` refusal appears in no line of the diff.
