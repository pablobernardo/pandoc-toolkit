# Prepare the 2.4.0 release
Branch: `chore/prepare-2.4.0`; delivery: one metadata PR, squash to `main`, then a single tag-triggered release on the verified commit.
Scope: metadata plus candidate acceptance. Nothing breaks: the configuration contract gains one optional field and the CLI gains one command.

## Specs

- S1: One minor release carries everything merged since `v2.3.0`: the shared YAML loader, `pandoc.top_level_division`, the PDF image cover, the `pandoc-pdf book` subcommand, the example renamed to say what it demonstrates, and the EPUB acceptance job narrowed to the format it validates.
- S2: Minor and not major. The configuration contract gains one optional field and the CLI gains one command; `pdf.config.yaml` keeps its name and its schema, and no existing flag, output or exit code changes. No migration guide is required.
- S3: Follow `docs/releasing.md`: gate green on the candidate, version and notes ready, compatibility assessed, dependencies still pinned.
- S4: Candidate acceptance from a **clean checkout of the approved commit**, never the working tree: packaging reproducible with matching checksums, payload inspected against the commit, a managed install, an upgrade from the published 2.3.0, and a smoke render whose PDFs are opened rather than trusted.
- S5: Declare the gap instead of hiding it: PyYAML is not installed on this machine, so only the Ruby YAML path can be exercised locally.
- S6: Dispatch L2 and L3 by hand on the candidate and attach the runs, because `docs/releasing.md` states that a skipped job is not integration evidence.
- S7: Publication stays the maintainer's decision at the tag step; one annotated tag, one tag-triggered release, no replacement tags.

## Tasks

- T1 [S1–S3] in progress; route: parent inline; `VERSION` 2.4.0, the `[2.4.0] - 2026-11-04` changelog section and this document.
- T2 [S3] pending; route: parent; `make gate` green on the candidate, recording the suite, catalog, documentation and conformance lines.
- T3 [S4] pending; route: parent; clean clone, packaging twice for a stable hash, payload inspection, managed install, upgrade from 2.3.0, smoke render.
- T4 [S5] pending; route: parent; record which YAML paths ran and which could not.
- T5 [S6] pending; route: parent; `workflow_dispatch` of L2 and L3 on the candidate, runs attached.
- T6 [S1, S7] pending; route: parent delivery; metadata PR, squash merge, `main` verification.
- T7 [S7] pending; route: parent, after the maintainer's explicit publication decision; annotated tag `v2.4.0` and one release.
- T8 [S7] pending; route: parent acceptance; download the published assets, isolated install, update from 2.3.0 and a smoke render from the real download path.

## Log

- L1 — Maintainer request, verbatim: "que nos queda ahora para poder sacar la 2.4.0 ?" and, after the checklist was presented: "me parece bien entonces ya podemos lanzar pr con estos cambios y release o todavía no?"
- L2 — Correction recorded before it could mislead: there were no pending changes to open a pull request with. The working tree was clean at `150b755` and every unit was already merged, so the release pull request is the candidate this document describes; the tag remains a separate, later decision.
