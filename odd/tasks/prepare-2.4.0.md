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

- T1 [S1–S3] done; route: parent inline; `VERSION` 2.4.0, the `[2.4.0] - 2026-11-04` changelog section and this document; commit `6b315e4`, merged as `4bf7771` (PR #136).
- T2 [S3] done; route: parent; `make gate` green on the candidate: 533 passed, 0 failed, 4 locales and 176 keys, 70 markdown files, 4 conforming plans.
- T3 [S4] done; route: parent, from a clean clone of `4bf7771`. Packaging twice produced identical checksums, so the published checksum can be compared with the approved candidate: `1ccc33fbcdd20ee4b42adaabb59bafafc8006920941a9b6f15bf78ac49079899`, with the four platform names as aliases of one artifact. The payload carries `VERSION` 2.4.0 and zero entries from `scripts/dev`, `scripts/delivery`, `__pycache__`, `.pyc` or `.git`, and it does carry the new `scripts/runtime/top_level_division_runtime.py`, which is the piece a trimmed payload could plausibly have dropped. A managed install in a disposable layout reported 2.4.0, `doctor` passed and `validate-config` passed, with `current` pointing at `versions/2.4.0`.
- T3a [S4] done; route: parent; smoke render **from the installed artifact**, not the checkout: `pandoc-pdf book` produced three volumes whose generated configuration declares `top_level_division: chapter` (8, 8 and 6 pages, chapters 1–3 and 4–5), and a project with `cover-image` printed the image on page 1 with no text, the typographic title page on page 2, the cover resolved against `base_dir` and every template and filter loaded from `versions/2.4.0`.
- T3b [S4] done; route: parent; upgrade and rollback in the managed layout: the published 2.3.0 artifact (`f844c211…`) reported 2.3.0, adding 2.4.0 moved `current` and reported 2.4.0 with both versions present, and repointing `current` returned to 2.3.0 with that version intact.
- T4 [S5] done; route: parent; the gap is recorded rather than claimed: PyYAML is not installed on this machine, so only the Ruby YAML path was exercised locally.
- T5 [S6] done; route: parent; `workflow_dispatch` of L2 and L3 on `main` (run `41851210015`): both jobs `success`. They are the integration evidence the pull-request checks cannot provide, because those two are skipped there.
- T6 [S1, S7] done; route: parent delivery; metadata PR #136, squash merge `4bf7771`, `main` verified.
- T7 [S7] in progress; route: parent, after the maintainer's explicit publication decision; annotated tag `v2.4.0` and one release.
- T8 [S7] pending; route: parent acceptance; download the published assets, isolated install, update from 2.3.0 through the network updater and a smoke render from the real download path. The network updater cannot run before publication, which is where `docs/releasing.md` places it.

## Log

- L1 — Maintainer request, verbatim: "que nos queda ahora para poder sacar la 2.4.0 ?" and, after the checklist was presented: "me parece bien entonces ya podemos lanzar pr con estos cambios y release o todavía no?"
- L2 — Correction recorded before it could mislead: there were no pending changes to open a pull request with. The working tree was clean at `150b755` and every unit was already merged, so the release pull request is the candidate this document describes; the tag remains a separate, later decision.
- L3 — Candidate acceptance, recorded above in T3–T5. The evidence was produced from a clean clone of the merged commit and from the installed artifact, never from the working tree, and the one gap (PyYAML absent) is stated rather than glossed over.
- L4 — Maintainer decision on publication, verbatim: "hazlo", in response to the question of whether the 2.4.0 publication was authorized.
