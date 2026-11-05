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

- T1 [S1–S3] done; route: parent inline; `VERSION` 2.5.2, the `[2.5.2] - 2026-11-05` changelog section and this document; delivered in PR #165, squash-merged as `0376d56`.
- T2 [S4] done; route: parent; `make gate` on the candidate gave 570 passing, 0 failing, 179 catalog keys, 77 documentation files and 4 conforming plans.
- T3 [S5] done with three declared gaps; route: delegated worker on a clean clone, reproduced by the parent. Packaging twice gave `28d9b8f96f7143cc12a183ebf684763564e91729b75a6af199e05039bbbe9933` both times, the archive matched `git ls-files`, and the documentation example rendered under `/usr/bin/python3` 3.9.6 with exit 0. The parent re-packaged the candidate and got the same hash, and repeated the 3.9.6 render. Gaps: `doctor` cannot pass the Mermaid examples on this machine (no `chrome-headless-shell`), PyYAML is absent so only the Ruby loader ran, and no Linux runtime was exercised because the four archives alias one payload.
- T4 [S6] done; route: parent; `workflow_dispatch` run `42053335662` on `0376d56` gave L1 Ubuntu, L1 `macos-15`, L2 render integration and L3 full integration all green. EPUB acceptance stayed skipped because it was not requested.
- T5 [S4] done; route: parent delivery; PR #165 squash-merged as `0376d56`, `main` verified clean with `VERSION` 2.5.2, and the acceptance evidence recorded as a comment on the PR before the merge.
- T6 [S7] done; route: parent, after the maintainer's explicit publication decision; annotated tag `a5da6ad` on `0376d56`, pushed, and the tag-triggered release run published four assets of 66,307 B plus `checksums.txt`, neither draft nor prerelease.
- T7 [S7] done; route: parent acceptance; published assets against the approved candidate, install, `update` from 2.5.1, smoke render from the real download path.

## Log

- L1 — Maintainer, verbatim: "crees que debemos añadir otro patch? que recomiendas?"
- L2 — Recommendation accepted after the reasoning: publish because the published 2.5.1 cannot render on a stock macOS, not because changes accumulated. The verification that made the reason precise: the construct is present in v2.4.0, v2.5.0 and v2.5.1, so it is inherited rather than introduced.
- L3 — Scope held deliberately narrow. #163 (book EPUB) is a feature and stays out; #159 and #152 are not fixes for a published defect and stay out. A patch whose content is one defect is easy to describe and easy to accept.
- L4 — Post-publication acceptance of v2.5.2 (scratch directories only, tree untouched). All four published tarballs hash `28d9b8f96f7143cc12a183ebf684763564e91729b75a6af199e05039bbbe9933`, matching the accepted candidate and the published `checksums.txt`. Clean install reports `pandoc-pdf 2.5.2`; `validate-config` and `doctor` exit 0 against the copied `examples/ohmyfake` config. Real upgrade from the published 2.5.1: `update --check` reports 2.5.1 -> 2.5.2 (exit 0), `update --yes` prints `Updated to version 2.5.2` (exit 0), `current` repoints to `versions/v2.5.2`; checksum verification is silent on success by design. Smoke render under `/usr/bin/python3` 3.9.6 forced first on `PATH` produced the 13-page PDF (text layer non-empty on every page) and the EPUB; `/usr/bin/python3` has no PyYAML, so the Ruby fallback parsed the YAML. `doctor` refuses a shimmed `python3` reporting 3.8.9 with exit 1, in English ("python3 3.8.9 is below the required minimum 3.9") and Spanish ("python3 3.8.9 está por debajo del mínimo obligatorio 3.9"). Tag is annotated, peeling to `0376d5621305f225bef544f1311ba60af092a6ac`; release is neither draft nor prerelease; notes begin with `## What's Changed`.
