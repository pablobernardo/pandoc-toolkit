# Prepare the 2.5.0 release
Branch: `chore/prepare-2.5.0`; delivery: one metadata PR, squash to `main`, then a single tag-triggered release on the verified commit.
Scope: metadata plus candidate acceptance. Minor, not patch: the toolkit gains contract fields and changes a bookkit default.

## Specs

- S1: One minor release carries everything merged since `v2.4.0`: the contents separation (`toc_separators`, `toc_labels`), the bookkit volume layout without `content/` with `chapters_dir` now defaulting to `chapters`, the local installer that builds the released payload under `versions/v<version>`, and `docs/books.md`.
- S2: Minor and not patch. Adding contract fields is free under `AGENTS.md`, and the bookkit default changes behaviour for a manifest that relied on it; a patch number would misdescribe what a consumer receives. Nothing breaks in the CLI: no command, flag, message, exit code, schema rule or `pdf.config.yaml` field changed.
- S3: Follow `docs/releasing.md`: gate green on the candidate, version and notes ready, compatibility assessed, dependencies still pinned.
- S4: Candidate acceptance from a **clean checkout of the approved commit**: packaging twice for a stable hash, payload inspected against the commit, a managed install built by the local installer, an upgrade from the published 2.4.0, and a smoke render of an example **and of a book whose contents is separated**.
- S5: Declare the gap instead of hiding it: PyYAML is not installed on this machine, so only the Ruby YAML path can be exercised locally.
- S6: Dispatch L2 and L3 by hand on the candidate, and macOS L1 with `run_l1_macos=true`, because none of them run on a pull request any more. Attach the runs.
- S7: Publication stays the maintainer's decision at the tag step; one annotated tag, one tag-triggered release, no replacement tags.

## Tasks

- T1 [S1–S3] in progress; route: parent inline; `VERSION` 2.5.0, the `[2.5.0] - 2026-11-04` changelog section and this document.
- T2 [S3] pending; route: parent; `make gate` green on the candidate, recording the suite, catalog, documentation and conformance lines.
- T3 [S4] pending; route: parent; clean clone, packaging twice, payload inspection, managed install through `install-local.sh`, upgrade from 2.4.0, smoke render.
- T4 [S5] pending; route: parent; record which YAML paths ran and which could not.
- T5 [S6] pending; route: parent; `workflow_dispatch` of L2, L3 and macOS L1 on the candidate, runs attached; a runner-capacity failure is recorded as a limitation, not claimed as evidence.
- T6 [S1, S7] pending; route: parent delivery; metadata PR, squash merge, `main` verification.
- T7 [S7] pending; route: parent, after the maintainer's explicit publication decision; annotated tag `v2.5.0` and one release.
- T8 [S7] pending; route: parent acceptance; download the published assets, isolated install, update from 2.4.0 through the network updater and a smoke render from the real download path.

## Log

- L1 — Maintainer request, verbatim: "me parece que podemos lanzar pr, merge y sacar release nueva? como lo ves con lo que tenemos?"
- L2 — The release number was corrected before the candidate was cut: the maintainer had suggested `2.4.1`, but the batch adds contract fields and changes a bookkit default, so the honest number is `2.5.0` under the repository's own policy.
