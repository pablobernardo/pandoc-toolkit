# Config Contract Alignment (S1)

Commit SHAs below are from the feature branches; each pull request was squash-merged, so the landed record is in `CHANGELOG.md`.

Branch `feature/config-contract-alignment`. Closes the divergence between `schemas/pdf-config.schema.json` and the runtime, plus the approved quick wins. No breaking config-contract change. Landed in PR #11, squash `9cb7211`.

## Specs

**S1 — Original request (translated from Spanish)**
> review this repo and tell me what you propose to improve, optimize or simplify it

**S2 — Distribution question (translated from Spanish)**
> once all those changes are finished, will we have an independent executable like now? or do you recommend compiling something in Go or another language to have it?

**S3 — Distribution decision (translated from Spanish)**
> windows is not a priority but I would like to leave a door open to implement it in Go if you recommend it and it adds value

**S4 — Start authorization (translated from Spanish)**
> sounds good to me

**S5 — Accepted scope of S1 (translated from the approved proposal)**
> **S1** | **P1** (contract vs runtime: 5 inert fields) + quick wins (`--team`, duplicated emoji, `.env`, pycache in the release) | Fixes the contract lie. No high risk, with a minor bump + migration note.

**S6 — `input.order` must sort the chapters**
`natural` (the value declared in defaults/examples/fixtures) compares the numeric segments as numbers: `chapter-2.md` before `chapter-10.md`. `alphabetical` keeps the current lexicographic order. Any other value fails with a localized message listing the accepted values. Only applies when `input.explicit_files` is empty.

**S7 — `output.keep_merged_markdown` must control the merged `.md`**
`true` (default) keeps it (current behavior). `false` removes it after a successful pandoc render; if pandoc fails, the `.md` is kept for diagnosis.

**S8 — `document.*` must reach the template**
With `pandoc.metadata_file` empty, the non-empty fields `title`, `subtitle`, `publisher`, `author`, `date`, `rights` are passed to pandoc as template variables (`-V field=value`). With `metadata_file` set, they are not passed (the metadata file wins), as `docs/architecture.md` §2 rule 4 declares. `document.title` still sets the output file name.

**S9 — `filters.emoji.include_ballot_icons` must control the dingbats**
`false` leaves the characters `☐` (2610), `☑` (2611) and `☒` (2612) unreplaced by image. `true` (default) keeps the current substitution.

**S10 — `runtime.strict` must control preflight severity**
`true` (default) fails with exit 1 if a required command or the TeX engine is missing. `false` reports them as warnings and exits with 0.

**S11 — Approved quick wins**
- The missing-locale message must not mention `--team` (the real option is `--project`).
- The SVGs `filters/emoji/emoji_u{2610,2611,2612}.svg` are byte-identical copies of `filters/emoji/{2610,2611,2612}.svg` and are not referenced: they are removed.
- `scripts/package-release.sh` must not include `scripts/__pycache__` in the artifact nor repackage the same tree 4 times.
- `--resource-path` must be joined with the platform separator, not a hardcoded `':'`.

**S12 — Documentation and version**
`docs/usage.md`, `docs/migration.md`, `CHANGELOG.md`, `CONTEXT.md` and `VERSION` reflect the new semantics. Minor toolkit bump (added behavior, no invalid configs).

**S13 — The emoji filter must not alter text without emojis (L2 verification finding)**
`filters/emoji.lua` wrapped every `Str` in a `pandoc.Span`, additionally splitting each word into one `Str` per character. Effect: any heading became "formatted" and pandoc emitted `\\texorpdfstring`, which requires `hyperref` in the template; with minimal templates the render failed with `! Undefined control sequence`. It already failed on the default branch (L2 exit 43, verified in a worktree of it). The filter must return `nil` when there was no real substitution.

**Out of scope of S1 (approved in the plan)**
- P2 (retire the Ruby renderer), P3 (unify i18n in bash), P5 (schema validator), P7 (split the bash suite).
- Plan JSON `--dry-run --json` and P4 (defaults vs validation) → S2/S3.

## Tasks

| ID | S# | Task | Path | Commit | Status |
| --- | --- | --- | --- | --- | --- |
| T1 | S6-S10 | RED tests for the five behaviors (python and ruby) | inline | #11 `9cb7211` | done |
| T2 | S6-S10 | Implementation in `render-native.py`, `render-native.rb`, `filters/emoji.lua`, `scripts/preflight.py` + i18n keys in 4 locales | inline | #11 `9cb7211` | done |
| T3 | S11 | Quick wins: `--team`, duplicated SVGs, `package-release.sh`, `os.pathsep` | inline | #11 `9cb7211` | done |
| T4 | S12 | Docs, CHANGELOG, CONTEXT, VERSION 1.2.0 | inline | docs slice | done |
| T5 | S6-S12 | L1 suite green + real L2 + python/ruby differential | inline | pending | pending |
| T6 | S13 | Emoji filter: do not rewrite plain headings + integration templates with `graphicx`/`hyperref` | inline | pending | pending |

## Log

**L1 — Initial request (translated from Spanish)**
> review this repo and tell me what you propose to improve, optimize or simplify it

**L2 — Distribution context (translated from Spanish)**
> once all those changes are finished, will we have an independent executable like now? or do you recommend compiling something in Go or another language to have it?

**L3 — Distribution decision (translated from Spanish)**
> windows is not a priority but I would like to leave a door open to implement it in Go if you recommend it and it adds value

**L4 — Authorization (translated from Spanish)**
> sounds good to me

**L5 — Baseline evidence (measured before touching code)**
- `bash tests/run.sh` → PASS=145 FAIL=0.
- `VERSION` = 1.1.3; `CONTEXT.md` declared 1.1.0 and PASS 143/113 (drift).
- Real artifact: 4 identical 53K tarballs, 0 binaries; it includes `scripts/__pycache__/*.pyc` (verified with `tar -tzf`).
- Local `python3` without PyYAML ⇒ the active path on this machine is the Ruby renderer. Both renderers must stay synchronized until S3.
- The template `templates/default.tex` uses `$subtitle$`, `$author$`, `$publisher$`, `$date$`, `$rights$` on the cover page: today they render empty because the runtime never passes them.

**L6 — Implementation decision (conscious deviation from the initial recommendation)**
The initial proposal suggested removing `filters.emoji.include_ballot_icons` and `runtime.strict` from the schema. The decision is to **implement** them instead because:
- removing properties with `additionalProperties: false` invalidates consumer configs (breaking, high-risk item 3);
- both implementations cost a few lines and remove the contract lie without breaking anything.
Result: S1 breaks no existing config and only requires a minor bump.

**L7 — Decision not to delete `.env` (superseded)**
`<repo>/.env` contained `PANDOC_PDF_UPDATE_TOKEN` and was gitignored. It was left in place because deleting a secret is the maintainer's call.

Superseded in 1.2.0: the updater stopped reading that variable (`CHANGELOG.md`), and the maintainer then approved deleting the local file, which held a credential for a feature that no longer exists. Nothing in the tree reads `PANDOC_PDF_UPDATE_TOKEN` or `GH_TOKEN`.

**L8 — Slice closure (measured with `git show --stat` of each feature-branch commit, all landed in #11 `9cb7211`)**
- Implementation slice ≈ 295 authored lines: 256 insertions + 39 deletions across 10 files.
- Release-hygiene slice ≈ 24 lines: 11 insertions + 13 deletions across 4 files.
- Tests slice ≈ 570 lines: 558 insertions across 3 files (2 new fixtures + `tests/run.sh`).
- `bash tests/run.sh` → **PASS=188 FAIL=0** after the tests slice (baseline measured in L5: PASS=145).
- `python3 scripts/check-i18n.py` green with the new keys `doctor.warn.*`, `render.error.order_invalid` and `cli.locale.error.missing_target` in the 4 locales.
- Process note: T1 (tests) materialized in its own feature-branch commit, after the implementation commit; it was kept in a separate commit because `tests/run.sh` is a shared monolith (see the pending slice to split it).

**L9 — Finding in L2 verification: the emoji filter broke minimal templates (pre-existing)**
L2 failed on the default branch with exit 43 and `! Undefined control sequence \texorpdfstring`. Verified in a clean worktree of the default branch, so it was not a regression of this slice.
Root cause: `function Str(el) return pandoc.Span(...) end` in `filters/emoji.lua` wrapped every `Str` in a `Span` (and `string_to_inlines` generated one `Str` per character). Pandoc emits `\texorpdfstring` for formatted headings, and that macro is defined by `hyperref`. A minimal template without `hyperref` ⇒ broken render.
Fix: the filter only wraps when there was a real substitution; the templates in `tests/integration/*/templates/default.tex` load `graphicx` and `hyperref` (a realistic template must load them).

**L10 — Final verification evidence**
- `bash tests/run.sh` → **PASS=191 FAIL=0**.
- `bash tests/l2-local.sh` → **exit 0**, `✅ L2 local integration passed` (real pandoc + pdflatex, PDF and `.md` generated, `-V title=` applied, emoji+mermaid filters active).
- `bash tests/l3-local.sh` → **not runnable on this machine**: `❌ Chromium executable not found. Set PUPPETEER_EXECUTABLE_PATH.` Not retried.
- `python3 scripts/check-i18n.py` → 4 locales, 151 keys.
- Differential baseline↔branch: L2 executed in a worktree of the default branch (fmt: exit 43, same `\texorpdfstring`) and on the branch (exit 0) ⇒ the improvement is verifiable and the regression does not exist.
