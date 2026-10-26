# Render Plan JSON (S3-a)

Branch `feature/config-contract-alignment` (same feature branch). Work landed in PR #11, squash `9cb7211`; the landed record is in `CHANGELOG.md`. Extracts the render calculation into a **pure plan** that can be inspected and compared without executing pandoc.

## Specs

**P1 — New `render` mode (additive)**
`pandoc-pdf render -c <pdf.config.yaml> --dry-run` prints the readable plan and **writes nothing** to disk. `--dry-run --json` prints the same plan as JSON on stdout. `--json` implies `--dry-run`. Without flags, `render` behaves exactly as before.

**P2 — The plan is pure**
Calculating the plan creates no directories, does not write the merged markdown, does not download emojis and does not invoke pandoc. It can run in a clean repo without observable effects (no new files, no modifications).

**P3 — Plan content (v1)**
JSON with: `plan_version`, `toolkit` (`version`, `root`), `config` (`path`, `base_dir`), `chapters` (absolute paths in the effective order, with `input.order` or `explicit_files` already applied), `pandoc.target` (merged markdown and PDF), `pandoc.argv`, `pandoc.cwd`, `env`, `side_effects` (`keep_merged_markdown`, `emoji` with its directory, `mermaid` with its directory and background, `emoji_prepare` with its argv or `null` if disabled).

**P4 — Parity between renderers**
The plan JSON must be identical (normalizing the path prefix) between `scripts/render-native.py` and `scripts/render-native.rb`, just as already required for the pandoc invocation.

**P5 — No behavior change**
Normal execution keeps the already-verified pandoc invocation and environment bit for bit: the existing suite (191 assertions) must stay green unmodified, and the plan must be the single source of that invocation (the executor decides nothing).

**Out of scope**
- Retiring the Ruby renderer (P2 of the analysis) and deciding defaults-vs-validation (P4 of the analysis): they remain pending decision.
- Multi-language conformance suite: it will build on this plan when a port exists.

## Tasks

| ID | S# | Task | Path | Status | Commit |
| --- | --- | --- | --- | --- | --- |
| T1 | P1-P5 | Tests: valid plan JSON, no effects, readable `--dry-run`, py/ruby parity | inline | done | tests slice |
| T2 | P2-P3 | Pure `build_plan` refactor + `execute_plan` in `render-native.py` | inline | done | implementation slice |
| T3 | P4 | Mirror in `render-native.rb` | worker | done | implementation slice |
| T4 | P1 | Flag wiring in `bin/pandoc-pdf` + i18n | inline | done | implementation slice |
| T5 | P1-P5 | Docs (`docs/usage.md`, CHANGELOG, CONTEXT) | inline | done | docs slice |

## Log

**L1 — Authorized continuation (translated from Spanish)**
> continue

**L2 — Context**
Slice S3-a of the plan approved in the review conversation. It changes neither the config contract nor default behavior: it only adds an inspection mode. The plan is the piece the analysis identified as the "open door to Go" and as a verifiable contract against a future port.

**L3 — Starting state (measured)**
- `bash tests/run.sh` → PASS=191 FAIL=0.
- `bash tests/l2-local.sh` → exit 0.
- `bash tests/l3-local.sh` → not runnable on this machine (Chromium not found).
- Native review of the previous slice: blocked by provider (reasoning guard in `review-resilience`); lineage `review-d3a0f85c95b06577` in state `reviewing`, without verdict. Not retried without a maintainer decision.

**L4 — Implementation and evidence**
- Python rewritten in three pieces: `build_plan` (pure), `execute_plan` (single point with effects), `print_plan`. Ruby mirrored via worker, with byte-for-byte parity.
- Two real blockers found and fixed during verification:
  1. `bin/pandoc-pdf` validated the config by writing to stdout, so `--dry-run --json` returned banner + JSON. Now the validation banner goes to stderr when `--json` is requested.
  2. `prepare_argv[0]` diverged (`sys.executable` in Python vs `python3` in Ruby). The neutral token `python3` is fixed in the plan, which is the same command the CLI uses to launch the renderer.
- Message `render.error.usage` updated in the 4 locales with `[--plan|--plan-json]`.
- Accepted collateral behavior change: with `filters.emoji.enabled: false` the emoji directory and `_missing.svg` are no longer created (the executor obeys the plan). It affects no fixture nor L2.

**L5 — Final verification**
- `bash tests/run.sh` → **PASS=210 FAIL=0** (baseline of this slice: 191).
- `bash tests/l2-local.sh` → **exit 0**, `✅ L2 local integration passed` (real render after the refactor).
- `python3 scripts/check-i18n.py` → 4 locales, 153 keys.
- Plan verified as pure: `--dry-run` does not invoke pandoc (empty mock capture) and does not create `work/out`.
