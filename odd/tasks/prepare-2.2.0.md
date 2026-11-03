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

- T1 [S1–S3] in progress; route: parent inline; `VERSION` 2.2.0, the `[2.2.0]` changelog section with Added/Changed/Fixed, and this document.
- T2 [S3] pending; route: parent; `make gate` green on the metadata commit.
- T3 [S4–S5] pending; route: independent verifier; clean-clone packaging, checksums, archive layout, managed install, upgrade from 2.1.1, smoke render and both book examples.
- T4 [S6] pending; route: parent delivery; metadata PR, squash merge, main verification.
- T5 [S6] pending; route: parent, after the maintainer's explicit publication decision; annotated tag `v2.2.0` and one release.
- T6 [S4] pending; route: parent acceptance; download the published assets, isolated install, update from 2.1.1 and a smoke render from the real download path.

## Log

L1 — Maintainer decision, verbatim: "ok fusionamos el pr a main origin/main y a partir de ahi miramos como reorganizar scripts" and, on release strategy, the agreed plan of one 2.2.0 carrying the accumulated work instead of an intermediate patch followed by a second release.
