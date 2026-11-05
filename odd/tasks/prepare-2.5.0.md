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

- T1 [S1–S3] done; route: parent inline; `VERSION` 2.5.0, the `[2.5.0] - 2026-11-04` changelog section and this document; delivered in PR #145, squash-merged as `86bb255`.
- T2 [S3] done; route: parent; `make gate` green on the candidate — suites, catalog, documentation and conformance — before PR #145 was opened.
- T3 [S4] done; route: parent; clean clone of the approved commit, packaging twice for a stable hash, payload inspected against the commit, managed install through `install-local.sh`, upgrade from 2.4.0 and a smoke render of an example and of a book whose contents is separated.
- T4 [S5] done; route: parent; only the Ruby YAML path was exercised locally, and PyYAML stays unavailable on this machine. The gap is declared, not closed.
- T5 [S6] done with one limitation; route: parent; `workflow_dispatch` run `41887287630` on `d7f1339` gave L1 Ubuntu, L2 and L3 succeeded; L1 `macos-15` was cancelled after 15m38s with no runner assigned. The macOS line is a recorded limitation, not evidence.
- T6 [S1, S7] done; route: parent delivery; PR #145 squash-merged as `86bb255` and PR #146 followed on top of it, so the tag later landed on `d7f1339`.
- T7 [S7] done; annotated tag `v2.5.0` on `d7f1339` (tag object `552b8ca`, peeled to `d7f1339`), pushed to `origin`; the tag-triggered release run `41890127803` succeeded in 17s.
- T8 [S7] done; four platform tarballs plus `checksums.txt` published; every asset hashes to `40efd2445adf96cb0734096ccfbc4447b9b2ed2b12419c7382b6797a17cd6c35`, recomputed in this session on `darwin_arm64` and matching the file; installation from the published assets and the 2.4.0 → 2.5.0 update were verified by the maintainer.

## Log

- L1 — Maintainer request, verbatim: "me parece que podemos lanzar pr, merge y sacar release nueva? como lo ves con lo que tenemos?"
- L2 — The release number was corrected before the candidate was cut: the maintainer had suggested `2.4.1`, but the batch adds contract fields and changes a bookkit default, so the honest number is `2.5.0` under the repository's own policy.
- L3 — Maintainer's verified end-of-session state, verbatim: "main = d7f1339 = origin/main, árbol limpio, VERSION 2.5.0, cero PRs abiertos. v2.5.0 PUBLICADA: tag anotado sobre d7f1339, release run 41890127803 (success). Artefacto publicado sha256 40efd2445adf96cb0734096ccfbc4447b9b2ed2b12419c7382b6797a17cd6c35, byte-idéntico al candidato aceptado. Instalación desde lo publicado y actualización 2.4.0 -> 2.5.0 verificadas. El remoto se llama `origin` (no `github`)."
- L4 — Remote readback in the closing session, against that report: annotated tag `v2.5.0` present locally and on `origin`, peeled to `d7f1339`; release published and not draft; `checksums.txt` and the four tarballs uploaded; the recorded sha256 recomputed on `darwin_arm64` and identical. The four tarballs share one hash because the payload is architecture-independent (bash, Python and Lua sources), not because of a packaging defect.
- L5 — The manual dispatch on the candidate (`41887287630`) is recorded as it is: L1 Ubuntu, L2 and L3 succeeded, L1 `macos-15` was cancelled after 15m38s with no hosted runner assigned. Four such capacity failures were observed during this release, so macOS stays a limitation until a run actually attaches.
- L6 — T1–T6 were still marked pending or in progress when the release was already live. They are marked done with the merge commits and runs that hold them; nothing was re-executed to close them, only read back.
