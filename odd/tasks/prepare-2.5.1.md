# Prepare the 2.5.1 release
Branch: `chore/prepare-2.5.1`; delivery: one metadata PR, squash to `main`, then a single tag-triggered release on the verified commit.
Scope: metadata plus candidate acceptance. Patch, not minor: three corrections, no new contract field, no change for an installation that declares none of the variables.

## Specs

- S1: One patch release carries everything merged since `v2.5.0`: the release payload built from the committed tree (#151), the updater honouring `PANDOC_PDF_INSTALL_HOME` and `PANDOC_PDF_INSTALL_DIR` (#153), and the documentation no longer linking outside its own publication (#154).
- S2: Patch and not minor. Nothing in the configuration contract changed, no CLI command, flag or message was removed, and the updater resolves exactly as before for an installation that declares neither variable — proven by the differential in #153, not asserted. Adding or correcting behaviour under documented variables is a correction of what the documentation already promised.
- S3: Follow `docs/releasing.md`: `make gate` on the candidate, version and notes ready, compatibility assessed, dependencies still pinned.
- S4: Candidate acceptance from a **clean clone of the approved commit**: package twice for a stable hash, inspect the payload against the commit, build a managed install from the artifact, upgrade from the published 2.5.0, and smoke render. The packager now builds from committed content, so the clean clone is still the input of record even though the machine can no longer contaminate it.
- S5: Dispatch macOS L1 with `run_l1_macos=true`, and L2 and L3, on the candidate, and attach the runs. A hosted-runner capacity failure is recorded as a limitation, not claimed as evidence. Skipped jobs are not integration evidence.
- S6: Publication stays the maintainer's decision at the tag step: one annotated tag on the verified commit, one release, no replacement tags, published assets preserved.

## Tasks

- T1 [S1–S3] in progress; route: parent inline; `VERSION` 2.5.1, the `[2.5.1] - 2026-11-05` changelog section and this document.
- T2 [S3] pending; route: parent; `make gate` green on the candidate, recording the suite, catalog, documentation and conformance lines.
- T3 [S4] pending; route: parent; clean clone, packaging twice, payload inspection, clean install, upgrade from 2.5.0, smoke render.
- T4 [S5] pending; route: parent; `workflow_dispatch` of L2, L3 and macOS L1 on the candidate, runs attached.
- T5 [S3] pending; route: parent delivery; metadata PR, squash merge, `main` verification.
- T6 [S6] pending; route: parent, after the maintainer's explicit publication decision; annotated tag `v2.5.1` and one release.
- T7 [S6] pending; route: parent acceptance; download the published assets, isolated install, `update --check` and update from 2.5.0, smoke render from the real download path.

## Log

- L1 — Maintainer, verbatim: "Release 2.5.1 y empiezo la preparación"
- L2 — Number chosen deliberately between 2.5.1 and 2.6.0: the alternative read "now understands two documented variables" as an added feature, which would make the changelog describe an addition rather than a fix and change what a consumer expects. The patch reading follows the repository policy, which reserves a major bump for breaking the CLI, the contract or default behaviour; the default path is unchanged.
