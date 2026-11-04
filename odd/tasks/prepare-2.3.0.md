# Prepare the 2.3.0 release
Branch: `chore/prepare-2.3.0`; delivery: one metadata PR, squash to `main`, then a single tag-triggered release on the verified commit.
Scope: metadata plus candidate acceptance. No configuration-contract or CLI change; the artifact's payload and the shipped templates do change.

## Specs

- S1: One minor release carries everything merged since `v2.2.0`: the book template shipped as product and resolvable by name, the examples consolidated into `book-kit`, the test areas split by subject, `toc: false` per entry, and the artifact trimmed to what an installation runs.
- S2: Minor and not major: the CLI and the configuration contract are unchanged. The visible differences are an artifact that no longer carries repository tooling, a template that now ships, and a new optional field in the bookkit manifest, which has its own contract.
- S3: Follow `docs/releasing.md`: gate green on the candidate, version and notes ready, compatibility assessed, dependencies still pinned.
- S4: Candidate acceptance from a clean checkout: four artifacts with matching checksums, an archive carrying `scripts/runtime` and `scripts/tools` and nothing from `dev` or `delivery`, a managed install, an upgrade from the published 2.2.0, and a smoke render including the symbol fixture.
- S5: The installed bookkit must build a book through the installed CLI and the installed template, which is the case the trimmed payload could plausibly have broken.
- S6: Publication stays the maintainer's decision at the tag step; one annotated tag, one tag-triggered release, no replacement tags.

## Tasks

- T1 [S1–S3] done; route: parent inline; `VERSION` 2.3.0, the `[2.3.0] - 2026-11-04` changelog section and this document; commit `93770a3`.
- T2 [S3] done; route: parent; `make gate` green on the candidate: 482 passed, 0 failed, 4 locales and 174 keys, 69 markdown files, 4 conforming plans.
- T3 [S4–S5] done; route: parent, after the delegated verifier stalled and produced no report. Clean clone of `93770a3`: packaging reproducible with matching checksums, payload carrying only `scripts/runtime` and `scripts/tools` and zero entries from `dev` or `delivery`, `templates/book.tex` shipped, installed CLI reporting 2.3.0 with `info` and `validate-config` working, install from the trimmed payload through the real installer, and the symbol smoke render with a single warning for the 🔍 control and no images. Evidence in L2.
- T4 [S4–S5] done; route: parent; the acceptance found a real defect: the installed bookkit could not build a project when the output directory lived outside it, because the tool resolved the output directory but not the project and mixed two spellings of the same place (`/var/folders` versus `/private/var/folders`). Fixed in `a11891f` with a symlink test that fails without the change, and re-verified from the artifact.
- T5 [S6] in progress; route: parent delivery; metadata PR #129, squash merge, main verification.
- T6 [S6] pending; route: parent, after the maintainer's explicit publication decision; annotated tag `v2.3.0` and one release.
- T7 [S4] pending; route: parent acceptance; download the published assets, isolated install, update from 2.2.0 and a smoke render from the real download path.

## Log

L1 — Maintainer decision, verbatim: "prepara el candidato y luego seguimos con las mejoras", after recommending one 2.3.0 release for the closed batch rather than accumulating more changes.

L2 — Acceptance and the defect it found. The delegated verifier stalled after a bash call and produced no report, so the parent ran the acceptance on a clean clone: reproducible packaging with matching checksums, a payload carrying only `scripts/runtime` and `scripts/tools` with zero entries from `dev` or `delivery`, `templates/book.tex` shipped, the installed CLI reporting 2.3.0 with `info` and `validate-config` working, an install from the trimmed payload through the real installer against a local release API, and the symbol smoke render with exactly one Missing-character warning (the unsupported 🔍 control) and no images. Then the case this release could plausibly have broken: the **installed** bookkit building the examples. It failed. Two hypotheses were wrong before the right one: it was not a general path-computation error (the previous code rendered fine from the checkout), and it was not fixed by reasoning alone — `mktemp` returns `/var/folders`, which macOS resolves to `/private/var/folders`, and the tool resolved the output directory while leaving the project unresolved, so the relative path between two spellings of the same place pointed outside the tree. `a11891f` resolves the project before anything computes a path against it and pins the behaviour with a test that passes the project through a symlink: it fails without the change and passes with it. Re-verified from the artifact afterwards: the single project and the series render (8 and 6 pages) and `toc: false` keeps the dedication out of volume 1's contents while the listed entry stays.
