# Prepare the 2.5.2 release
Branch: `chore/prepare-2.5.2`; delivery: one metadata PR, squash to `main`, then a single tag-triggered release on the verified commit.
Scope: metadata plus candidate acceptance. Patch, not minor: one defect published in 2.5.1 is fixed, and no contract, command, flag or message is removed.

## Specs

- S1: One patch release carries what merged since `v2.5.1`: the renderer running on Python 3.9 and the preflight enforcing the declared minimum (#160). The static guard (#162) is a test and does not travel in the artifact, so the published bytes change only by the fix.
- S2: Patch and not minor. Nothing in the configuration contract changed; the renderer produces the same output on a supported interpreter, and `doctor` now refuses an interpreter that could never render — a correction of a preflight that approved an unusable environment, which is behaviour a consumer must be told about in the changelog but not a new contract.
- S3: The reason to publish is not "there is a change on `main`" but that **2.5.1 cannot render on a stock macOS**: `git show v2.5.1:scripts/runtime/render-native.py` carries `zip(..., strict=True)` and `v2.5.1:scripts/runtime/preflight.py` has no version check, so the published release dies mid-render while `doctor` reports the environment as fine. The defect predates 2.5.1 — it is present in v2.4.0, v2.5.0 and v2.5.1 — so this is a long-standing inherited defect reaching a fix, not a regression introduced by the previous release.
- S4: Follow `docs/releasing.md`: `make gate` on the candidate, version and notes ready, compatibility assessed, dependencies still pinned.
- S5: Candidate acceptance from a **clean clone of the approved commit**: package twice, inspect the payload against the commit, install from the artifact, upgrade from the published 2.5.1, and smoke render — with the render exercised under `/usr/bin/python3` 3.9.6, which is the whole point of this release.
- S6: Dispatch macOS L1, L2 and L3 on the candidate on `main` after the metadata merge, so the runs point at the commit that will be tagged. A runner-capacity failure is recorded as a limitation, not claimed as evidence.
- S7: Publication stays the maintainer's decision at the tag step.

## Tasks

- T1 [S1–S3] in progress; route: parent inline; `VERSION` 2.5.2, the `[2.5.2] - 2026-11-05` changelog section and this document.
- T2 [S4] pending; route: parent; `make gate` green on the candidate, recording the suite, catalog, documentation and conformance lines.
- T3 [S5] pending; route: parent; clean clone, packaging twice, payload inspection, clean install, upgrade from 2.5.1, smoke render under Python 3.9.
- T4 [S6] pending; route: parent; dispatch on `main` after the metadata PR merges.
- T5 [S4] pending; route: parent delivery; metadata PR, squash merge, `main` verification.
- T6 [S7] pending; route: parent, after the maintainer's explicit publication decision; annotated tag `v2.5.2` and one release.
- T7 [S7] pending; route: parent acceptance; published assets against the approved candidate, install, `update` from 2.5.1, smoke render from the real download path.

## Log

- L1 — Maintainer, verbatim: "crees que debemos añadir otro patch? que recomiendas?"
- L2 — Recommendation accepted after the reasoning: publish because the published 2.5.1 cannot render on a stock macOS, not because changes accumulated. The verification that made the reason precise: the construct is present in v2.4.0, v2.5.0 and v2.5.1, so it is inherited rather than introduced.
- L3 — Scope held deliberately narrow. #163 (book EPUB) is a feature and stays out; #159 and #152 are not fixes for a published defect and stay out. A patch whose content is one defect is easy to describe and easy to accept.
