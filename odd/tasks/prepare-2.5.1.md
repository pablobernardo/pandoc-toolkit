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
- T3 [S4] done with two declared gaps; route: delegated worker on a clean clone of `da46965`; packaging twice produced one identical hash (`36a9ae65d407dbe377256f4ac725ace693c309d75b4d6b251eaa3cf8e17f6445` for `pandoc-pdf_linux_arm64.tar.gz`), all four assets verified against `checksums.txt` in both runs, and the 34 archive entries matched `git ls-files` with zero differences. The clean install from the artifact reports `pandoc-pdf 2.5.1`, `Config valid` and `Doctor OK` from the installed tree with no repository on `PATH`. Rendering gave 44 pages for `examples/documentation` and 8 for `examples/book-kit/single`, no empty-text page in either. Gap G1: updating *to* 2.5.1 cannot be proven before publication, because the updater downloads through the real GitHub API; what is proven is that the published 2.5.0 installs and reports up to date, that the updater refuses the unpublished `v2.5.1` tag, and that the failed update leaves `current` on `versions/v2.5.0` intact. Gap G2: only the Ruby YAML fallback ran; PyYAML is absent here.
- T4 [S5] done; route: parent; `workflow_dispatch` run `42023095232` on `91fd171` — the squash of the metadata PR — gave L1 Ubuntu, L1 `macos-15`, L2 render integration and L3 full integration all green. macOS had failed or been cancelled in every previous attempt this release cycle, so this is the first real BSD evidence of 2.5.1. EPUB acceptance stayed skipped because it was not requested.
- T5 [S3] done; route: parent delivery; PR #155 squash-merged as `91fd171`, `main` verified clean with `VERSION` 2.5.1, and the acceptance evidence recorded as a comment on the PR before the merge.
- T6 [S6] pending; route: parent, after the maintainer's explicit publication decision; annotated tag `v2.5.1` and one release.
- T7 [S6] pending; route: parent acceptance; download the published assets, isolated install, `update --check` and update from 2.5.0, smoke render from the real download path.

## Log

- L1 — Maintainer, verbatim: "Release 2.5.1 y empiezo la preparación"
- L2 — Number chosen deliberately between 2.5.1 and 2.6.0: the alternative read "now understands two documented variables" as an added feature, which would make the changelog describe an addition rather than a fix and change what a consumer expects. The patch reading follows the repository policy, which reserves a major bump for breaking the CLI, the contract or default behaviour; the default path is unchanged.
- L3 — Acceptance ran on a clean clone at `da469657af9bcf60936e1a5093cb3dd7c11dd37f`, not on the working tree. The node this release adds is observable as a differential: the installed 2.5.0, given `PANDOC_PDF_INSTALL_HOME` and `PANDOC_PDF_INSTALL_DIR`, planned `$HOME/.local/bin/pandoc-pdf`; the candidate plans the declared paths and never creates `$HOME/.local`.
- L4 — Acceptance surfaced a pre-existing defect that is not this release's: `render-native.py:579` uses `zip(..., strict=True)`, which needs Python 3.10+, and macOS ships 3.9.6 as `python3`. The render crashes while `doctor` approves the environment, and no document states the minimum. Filed as #156; deliberately not fixed here, because it would widen the candidate and it predates 2.5.1.
