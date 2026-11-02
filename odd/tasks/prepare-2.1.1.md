# Prepare the 2.1.1 patch release
Branch: `chore/prepare-2.1.1`; delivery: one metadata PR, squash to `main`, then a single tag-triggered release on the verified commit.
Scope: metadata plus candidate acceptance evidence. The runtime payload, published history and configuration contract do not change; `VERSION` moves from 2.1.0 to 2.1.1.

## Specs

- S1: "vale pues corrige lo que necesites y lanzamos mejor release patch si crees que es lo mejor" — cut a patch release (2.1.1), not a minor one: the two merged units are corrections, with no contract, CLI or default-behaviour change.
- S2: Follow the checklist in `docs/releasing.md` as the acceptance spec: gate green on the candidate, version and notes ready, compatibility assessed, dependencies still pinned.
- S3: "`templates/book.tex` es un archivo local sin versionar: no lo añadas, sobrescribas, borres ni incluyas en revisiones. Nunca empaquetes desde un árbol sucio." Package only from a clean checkout of the candidate commit, never from this working tree, because `scripts/package-release.sh` copies `templates/` wholesale.
- S4: Candidate acceptance: four artifacts with matching `checksums.txt`; archive contains the executable CLI, matching `VERSION`, runtime scripts, schemas, templates, filters, catalogs and licence, and no bytecode caches; clean managed install reporting 2.1.1; upgrade from the published 2.1.0 and rollback on a failed version check.
- S5: Smoke rendering of representative examples, including the behaviour this release fixes: untagged and highlighted code, inline code with the six symbols, and heading pagination. Inspect the PDFs, not just exit codes.
- S6: Exercise both YAML paths where feasible (PyYAML and the Ruby stdlib fallback) and record which ran and which gap remains.
- S7: `release.yml` fires on a tag: exactly one tag-triggered release for the final verified commit, no replacement tags and no retries, and corrections later go into a new patch version.
- S8: Publication is the maintainer's decision at the tag step; everything before it stays unpublished. Record evidence in this file, keep `Refs #83` on the delivery PR, and never close a delivered issue from a release PR.

## Tasks

- T1 [S1–S2] in progress; route: parent inline; `VERSION` 2.1.1, `CHANGELOG` `[2.1.1] - 2026-11-02`, the stale `#83` line in `docs/releasing.md` corrected and this document; commit: pending.
- T2 [S2] pending; route: parent; `make gate` green on the metadata commit.
- T3 [S3–S4] done; route: independent verifier on a clean clone of `6052bbc` with `book.tex` verified absent; packaging, checksums, archive inspection, clean install, upgrade from the published 2.1.0 and rollback all passed; evidence in L2.
- T4 [S5–S6] done; route: same independent verifier; smoke render with PDF inspection passed on the release fixture and two examples, and the Ruby YAML path ran naturally; evidence in L2.
- T5 [S7] in progress; route: parent delivery; metadata PR #115, squash merge, main verification.
- T6 [S7–S8] pending; route: parent, after the maintainer's publication decision; single annotated tag on the verified commit and one tag-triggered release.
- T7 [S4] pending; route: parent acceptance; download the published artifacts, isolated install, upgrade and smoke PDF from the real download path.

## Log

L1 — Maintainer request, verbatim: "vale pues corrige lo que necesites y lanzamos mejor release patch si crees que es lo mejor". This follows the recommendation to publish the two merged fixes as a patch instead of inflating the version to 2.2.0.

L2 — Independent candidate acceptance on a clean clone of `6052bbc` (`Darwin arm64`), with `templates/book.tex` verified absent from clone, install and archive. Package: four artifacts and `checksums.txt`, all four hashes identical (`3881d352…`), verified; archive carries the executable CLI, `VERSION` exactly `2.1.1`, every runtime directory, `templates/default.tex` and no `book.tex`, zero bytecode caches. Clean managed install reported `pandoc-pdf 2.1.1` with a correct `current` pointer; `doctor` needed the documented `PUPPETEER_EXECUTABLE_PATH` fix for the missing browser (a machine gap that also affects 2.1.0); both example configurations validated. Upgrade from the published 2.1.0 passed and set `versions/v2.1.1`; a tampered `checksums.txt` was refused with `checksum mismatch` and an unchanged installation; a forced post-install version mismatch triggered `post-install version validation failed` and rolled back with the previous install intact. Smoke render with the installed candidate: the six symbols in prose, inline, untagged and highlighted code with exact surrounding text, ordinary Pagella and LM Mono fonts plus embedded FreeSerif, zero image objects, and exactly one Missing-character warning for the unsupported 🔍 control; the documentation example rendered 38 pages with no orphaned headings and the pagination probe passed 10/10. YAML: this machine has no PyYAML, so the Ruby stdlib path ran naturally (`yaml_parser: ruby`, config path received once per validator and renderer), and the Python path was exercised through the repository's own shim; real PyYAML remains the one recorded gap, and installing it was not authorized. Not observed: the emoji-filter-enabled render (network fetch) and the pdfLaTeX branch. The verifier also flagged a stale comment in `examples/documentation/pdf.config.yaml`, corrected here. Its three proposed new regression scripts were not added: they are a separate testing improvement, not part of a patch release.
