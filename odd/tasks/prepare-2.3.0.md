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

- T1 [S1–S3] in progress; route: parent inline; `VERSION` 2.3.0, the `[2.3.0] - 2026-11-04` changelog section and this document.
- T2 [S3] pending; route: parent; `make gate` green on the metadata commit.
- T3 [S4–S5] pending; route: independent verifier; clean-clone packaging, payload shape, managed install, upgrade from 2.2.0, smoke render and the installed bookkit build.
- T4 [S6] pending; route: parent delivery; metadata PR, squash merge, main verification.
- T5 [S6] pending; route: parent, after the maintainer's explicit publication decision; annotated tag `v2.3.0` and one release.
- T6 [S4] pending; route: parent acceptance; download the published assets, isolated install, update from 2.2.0 and a smoke render from the real download path.

## Log

L1 — Maintainer decision, verbatim: "prepara el candidato y luego seguimos con las mejoras", after recommending one 2.3.0 release for the closed batch rather than accumulating more changes.
