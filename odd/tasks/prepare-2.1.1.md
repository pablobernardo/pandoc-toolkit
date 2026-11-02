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
- T3 [S3–S4] pending; route: independent verifier; clean-clone packaging, checksums, archive inspection, clean install, upgrade from 2.1.0 and rollback.
- T4 [S5–S6] pending; route: independent verifier; smoke render with PDF inspection and both YAML paths.
- T5 [S7] pending; route: parent delivery; metadata PR, squash merge, main verification.
- T6 [S7–S8] pending; route: parent, after the maintainer's publication decision; single annotated tag on the verified commit and one tag-triggered release.
- T7 [S4] pending; route: parent acceptance; download the published artifacts, isolated install, upgrade and smoke PDF from the real download path.

## Log

L1 — Maintainer request, verbatim: "vale pues corrige lo que necesites y lanzamos mejor release patch si crees que es lo mejor". This follows the recommendation to publish the two merged fixes as a patch instead of inflating the version to 2.2.0.
