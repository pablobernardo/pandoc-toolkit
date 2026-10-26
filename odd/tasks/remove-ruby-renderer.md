# Retire the Ruby renderer

Branch `refactor/remove-ruby-renderer`. Work landed in PR #14, squash `5b87b22`; the landed record is in `CHANGELOG.md`. Removes the second render implementation (`scripts/render-native.rb`, 398 lines) and leaves YAML parsing as Ruby's only remaining optional dependency.

## Specs

**S1 — A single renderer**
`render` and `render --dry-run [--json]` always run with `scripts/render-native.py`. `scripts/render-native.rb` disappears from the repository and from the distribution tree.

**S2 — YAML parsing does not break where PyYAML is missing**
The renderer loads YAML with PyYAML when available and, otherwise, delegates to the Ruby interpreter via subprocess (conversion to JSON), the same way `validate-config.py` already does. Without that safety net, this machine (python3 without PyYAML) would no longer be able to render and the suite could not be verified.

**S3 — Clear message when there is no parser at all**
If there is neither PyYAML nor Ruby, the CLI fails with the existing localized message (`cli.error.no_yaml_parser` and its two options), with no text changes.

**S4 — No orphan references**
The `.rb` is removed from: `bin/pandoc-pdf`, the three `chmod` lines in `ci.yml`, the structure list of `AGENTS.md`, the mentions in `CONTEXT.md` and `docs/i18n.md`, and the Python/Ruby parity tests (their reason to exist disappears with the second implementation).

**S5 — Equivalent coverage**
The suite keeps pinning the renderer's behavior: the py/ruby parity is replaced by the evidence that the single renderer passes the same contract, plan and execution tests. The plan-parity test and the pandoc-invocation test are removed.

**S6 — Declared breaking**
Whoever invoked `scripts/render-native.rb` directly (outside the CLI) loses that path. Noted in `CHANGELOG` (Unreleased, Removed section) and in `docs/migration.md`. The version bump is decided at publish time: the release is postponed by maintainer decision, so `VERSION` stays at 1.2.0 and the note describes the change as the "next version".

**L4 — Closure**
- Suite **PASS=217** (was 222: the two parity tests are removed and the pin on the `.rb`'s absence is added), L2 exit 0, i18n 156 keys, release artifact with `render-native.py` and no `render-native.rb`.
- Net: −529 / +131 lines; the Ruby renderer (398) disappears and YAML parsing keeps its safety net.

## Tasks

| ID | S# | Task | Status |
| --- | --- | --- | --- |
| T1 | S1-S3 | YAML parsing with fallback in `render-native.py`; `bin/pandoc-pdf` always Python; delete the `.rb` | done |
| T2 | S4-S5 | Tests: drop parity, rewrite the ones invoking the `.rb`, absence pin | done |
| T3 | S4 | `ci.yml`, `AGENTS.md`, `CONTEXT.md`, `docs/i18n.md` | done |
| T4 | S6 | CHANGELOG (Unreleased/Removed) and migration | done |
| T5 | S1-S5 | L1 PASS=217, L2 exit 0, artifact without the `.rb` | done |

## Log

**L1 — Authorization (translated from Spanish)**
> we are not shipping a release yet, move ahead with the rest

**L2 — Scope measured before touching code**
- `scripts/render-native.rb`: 398 lines.
- References: 2 calls in `bin/pandoc-pdf`, 3 `chmod` lines in `ci.yml`, 6 uses in `tests/run.sh` (2 of them full parity tests), and mentions in `AGENTS.md`, `CONTEXT.md`, `docs/i18n.md`, `CHANGELOG.md` (historical).
- This machine's `python3` has no PyYAML: the active render path is the `.rb`. Removing it without a parsing safety net would leave the repo unable to render here, so the fallback via Ruby subprocess is a requirement, not an ornament.

**L3 — Design decision**
Ruby is kept as an optional *parser* (subprocess, same as `validate-config.py`) and removed as a *renderer*. A single place where render logic lives; two ways to read YAML. Hardening it later (PyYAML required, fallback removed) is a separate slice with its own migration note.
