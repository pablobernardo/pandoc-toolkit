# Prepare the 2.2.0 release
Branch: `chore/prepare-2.2.0`; delivery: one metadata PR, squash to `main`, then a single tag-triggered release on the verified commit.
Scope: metadata plus candidate acceptance. No configuration-contract or CLI change; the artifact's internal layout does change.

## Specs

- S1: One minor release carries everything merged since `v2.1.1`: reproducible packaging, the two book examples, the `scripts/` split, the registration guard and the docs-check determinism fix. No intermediate patch, because none of those give a rendering consumer anything until they ship together.
- S2: Minor and not major, per the breaking-change policy in `AGENTS.md`: the CLI, the configuration contract and the default behaviour are unchanged, so a major bump would misstate the risk. The visible change is the internal artifact layout, which the `CHANGELOG` names explicitly.
- S3: Follow `docs/releasing.md`: gate green on the candidate, version and notes ready, compatibility assessed, dependencies still pinned.
- S4: Candidate acceptance from a clean checkout, never from a working tree: four artifacts with matching checksums, archive inspection, managed install, upgrade from the published 2.1.1, and a smoke render including the symbol fixture.
- S5: Both book examples build from the installed artifact, since they exercise the public CLI the release ships.
- S6: Publication stays the maintainer's decision at the tag step; one annotated tag, one tag-triggered release, no replacement tags.

## Tasks

- T1 [S1–S3] done; route: parent inline; `VERSION` 2.2.0, the `[2.2.0]` changelog section with Added/Changed/Fixed, and this document; commit `fd51c6b`.
- T2 [S3] done; route: parent; `make gate` green on the metadata commit: 451 passed, 0 failed, 4 locales and 173 keys, 72 markdown files, 4 conforming plans.
- T3 [S4–S5] done; route: independent verifier on a clean clone with all three `PANDOC_PDF_*` variables confined; evidence in L2.
- T4 [S6] in progress; route: parent delivery; metadata PR #122, squash merge, main verification.
- T5 [S6] pending; route: parent, after the maintainer's explicit publication decision; annotated tag `v2.2.0` and one release.
- T6 [S4] pending; route: parent acceptance; download the published assets, isolated install, update from 2.1.1 and a smoke render from the real download path.

## Log

L1 — Maintainer decision, verbatim: "ok fusionamos el pr a main origin/main y a partir de ahi miramos como reorganizar scripts" and, on release strategy, the agreed plan of one 2.2.0 carrying the accumulated work instead of an intermediate patch followed by a second release.

L2 — Independent acceptance on a clean clone of `fd51c6b`, with `PANDOC_PDF_INSTALL_HOME`, `PANDOC_PDF_INSTALL_DIR` and `PANDOC_PDF_UPDATE_HOME` all confined to the scratch root. Packaging: two builds plus a third equal hash (`9efffc44…`) on all four platform files, `checksums.txt` verified, archive carrying `scripts/runtime` 7, `scripts/dev` 4 and `scripts/delivery` 4 files, no `templates/book.tex`, no bytecode, `VERSION` 2.2.0 inside. Version consistency across `VERSION`, the changelog top section, the artifact and both `--version` and `info --json`. Clean managed install reporting 2.2.0 with paths inside the version directory, `validate-config` passing and a real EPUB render. Upgrade from the published 2.1.1 announcing 2.1.1 to 2.2.0, landing on 2.2.0 with both version directories kept; a tampered checksum refused with `checksum mismatch` and an unchanged installation; a forced wrong version triggering `post-install version validation failed` and `rollback completed`, with the previous installation intact. Smoke render: the six symbols in prose, inline, untagged and highlighted code with the exact surrounding text, FreeSerif embedded alongside Pagella and LM Mono, zero image objects, and exactly one Missing-character warning for the unsupported 🔍 control. Both book examples built through the installed CLI (9 pages for the single book; 8, 6 and 8 for the series volumes and the book-kit single project). Two findings were acted on: the changelog claimed `bin/pandoc-pdf` was unchanged when it moved 12 lines of script paths, now stated explicitly, and the Ruby YAML fallback was the path exercised because PyYAML is not installed on this machine, a gap the dependency policy already records. `doctor` needs `PUPPETEER_EXECUTABLE_PATH` on this machine, a documented environment gap that also affects 2.1.1.
