## Operational context (current)

> This file reflects changing state. Stable rules live in `AGENTS.md`.

## Snapshot

- General state: **stable CLI with native render by default**.
- Active entry point: `bin/pandoc-pdf`.
- Active commands: `--version`, `version`, `info`, `locale`, `update --check`, `update`, `update --to`, `doctor`, `validate-config -c`, `render -c [--dry-run] [--json]`.
- Verified local suite: **PASS=228 FAIL=0**.
- Toolkit version (`VERSION`): **1.2.0**, no tag — the release is postponed by maintainer decision (see D8).
- L1 suite is split: `tests/lib.sh` (assertions and fixture helpers) plus one file per area under `tests/l1/`; `tests/run.sh` (77 lines) only orchestrates. The split is complete.

## Active i18n convention

- ✅ The app is **multilingual** (active locales: `en`, `es`, `pt`, `gl`).
- ✅ Default fallback: **English (`en`)**.
- ✅ Implementation policy: **no user-facing strings hardcoded in runtime code**; every string comes from the `i18n/locales/*.json` catalogs.
- ✅ One shell runtime: `scripts/i18n.sh`, shared by `bin/pandoc-pdf` and `scripts/bootstrap.sh`; the catalog loads once and `t` spawns no process.
- ✅ Repository language: English, including this file (see `AGENTS.md`). The only Spanish in the tree is `i18n/locales/es.json`, written in Spain Spanish.

## State by area

### 1) CLI

- ✅ `pandoc-pdf` works for humans, CI and agents.
- ✅ `doctor` validates runtime dependencies through `scripts/preflight.sh`; `runtime.strict: false` waives auxiliary commands but never the TeX engine.
- ✅ `validate-config` enforces the strict contract (required fields, types, disallowed fields, `enum`) plus functional path checks.
- ✅ `render` is native with a single renderer, `scripts/render-native.py`; the Ruby duplicate is gone and Ruby remains only as an optional YAML parser.
- ✅ `render --dry-run [--json]` prints a pure `plan_version: 1` plan and writes nothing.
- ✅ `bootstrap` simplifies onboarding (`make bootstrap*`, `scripts/bootstrap.sh`).

### 2) Configuration and paths

- ✅ Schema-driven contract (`schemas/pdf-config.schema.json`) is the single source of truth; there is no defaults baseline to merge.
- ✅ `validate-config` checks the critical paths: `input.chapters_dir`, `pandoc.template` when set, `pandoc.metadata_file` when set, and `filters.extra_lua_filters`.
- ✅ `pandoc.template` is optional: when absent the toolkit template (`templates/default.tex`) is used; when present it resolves relative to `project.base_dir`.

### 3) Security

- ✅ Preflight hardened against injection (no `bash -c` to resolve commands from config).
- ✅ Safe YAML parsing in Ruby (`YAML.safe_load`).
- ✅ Security workflow (`.github/workflows/security.yml`) runs Semgrep and Gitleaks from pinned container images, so it no longer depends on the runner's Python.
- ✅ Policy published in `.github/SECURITY.md`.

### 4) Testing and CI

- ✅ Local suite green: **PASS=228 FAIL=0**, twelve files.
- ✅ CI by levels:
  - **L1** mandatory on PR/push (macOS and Linux);
  - **L2** semi-real integration, manual;
  - **L3** full integration, manual or scheduled (includes Mermaid).
- ✅ Every commit of the 1.2.0 work passed the suite on its own, checked by extracting each tree with `git archive`.

### 5) Documentation and governance

- ✅ `README.md`, `docs/install.md`, `docs/usage.md`, `docs/migration.md`, `docs/architecture.md` reviewed and translated to English.
- ✅ `docs/releasing.md`, `docs/dependency-policy.md`, `docs/i18n.md`, `docs/design/self-update.md` reviewed and translated.
- ✅ `CHANGELOG.md`: one honest `[Unreleased]` section stating that 1.2.0 has no tag yet.
- ✅ Release workflow available (`.github/workflows/release.yml`) for `v*` tags; it uses `action-gh-release@v3`, whose Node 24 runtime its own CI does not exercise.

## Decisions taken during 1.2.0

| # | Decision |
| --- | --- |
| D1 | A single renderer (Python). Ruby stays only as an optional YAML parser in a subprocess; removing it entirely would require making PyYAML mandatory, and that was decided **against**. |
| D2 | `runtime.strict: false` waives auxiliary dependencies, never the TeX engine: without an engine there is no PDF, so it always fails. |
| D3 | `validate-config` rejects a missing `pandoc.metadata_file` and validates `input.order` against its `enum`. The validator implements a documented JSON Schema subset and a test fails if the schema uses any other keyword. |
| D4 | Shell i18n unified in `scripts/i18n.sh`: catalog loaded once, no fork per message, one precedence chain for both entry points. |
| D5 | Metadata precedence: when `pandoc.metadata_file` is set it wins and no `-V` variables are passed; when empty, `title`, `subtitle`, `publisher`, `author`, `date` and `rights` become template variables. |
| D6 | The plan shape (`plan_version: 1`) is frozen as is: `cwd: null` (inherited), `env` with the toolkit's four variables, and `prepare_argv[0]` as the neutral `python3` token. Any shape change requires `plan_version: 2`. |
| D7 | `defaults/default.yaml` removed: `schemas/pdf-config.schema.json` is the single source of truth. |
| D8 | Release postponed: 1.2.0 is on `master` with no tag. Creating the tag triggers `release.yml` with `action-gh-release@v3`, which its CI does not exercise. |
| D9 | The repository is English, including this file and `odd/`; only `i18n/locales/es.json` is Spanish. |

## Native review (RDD) — a size threshold, not a broken provider

State: **usable, and it works on small candidates**. Four attempts with the same reviewer:

| candidate | result |
| --- | --- |
| 1,088 lines (branch to `31bc09b`) | `review-resilience` returns an empty answer |
| 1,159 lines (plan+defaults slice) | same |
| 159 lines (`9b22148`) | same |
| **62 lines (project locale file)** | **approved, 4/4 lenses, no blocking finding** |

Cause: the model serving the resilience lens emits reasoning only until it hits the gateway guard (`420 s / 45.000 reasoning-character limit`) and then returns nothing. Whether it finishes depends on how much the candidate makes it think, so **above roughly a hundred lines it fails and below it works**.

Consequences:

- Review small candidates (say, a commit or a focused change), never a whole branch. The plan artefact and its conformance idea remain the right long-term answer for large ones.
- An approved review is not a substitute for tests, and a failed review is not a reason to skip them: the effective gate is still the suite plus human review of the pull request.
- Retrying on a large candidate wastes about ten minutes and leaves a lineage to abandon.


## Binary migration (Go) — pending decision

State: **no migration now**. Windows is not a current requirement and the toolkit is consumed on Linux and macOS. The door is explicitly left open.

What the door consists of:

1. ✅ `render --dry-run --json`: done, and the plan shape is frozen (D6).
2. A conformance suite over that plan, runnable against any implementation (today's Python, a future Go one), to compare output without reading code.

Migration triggers (any one of them):

- (a) Windows becomes a real requirement.
- (b) A target consumer cannot provide `python3` + PyYAML.
- (c) Signed single-file artifacts are needed for supply chain.
- (d) Bash updater defects cost more than a rewrite.

## Known follow-ups

1. **`locale set --project` writes `.pandoc-pdf.env` in the toolkit root**, not in the consuming repository, so every consumer shares one "project" locale. The docs describe the behaviour; deciding whether to change it is still open.
2. **Action pinning**: workflows use major tags (`@v4`, `@v7`) managed by Dependabot. Moving to commit SHAs is a supply-chain policy decision, not taken yet.
3. **Artifact signing** (Sigstore/GPG) for release artifacts.

## Main gap (post 1.1)

No open technical blockers for the Linux/macOS contract of the toolkit.

## Next recommended milestone

### M3 — Multi-platform preparation

1. Design Windows support for the updater and install path, which today is blocked by the bash entry point.
2. Evaluate artifact signing to strengthen the supply chain.

## Active risks

- Environment differences (TeX/Mermaid/Chromium) between local runs and full integration execution.
- Native review (RDD) unavailable because of the provider limit: external coverage of this work depends on human review of the pull requests.
- Dependency on GitHub publication to close the reporting and update automation.
