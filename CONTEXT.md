# Operational context (current)

> This file reflects changing state. Stable rules live in `AGENTS.md`, and every
> document is indexed in `docs/README.md`. Correct a statement here rather than
> appending to it: a section that grows is a section nobody trusts.

## Current state

- General state: **stable CLI with native render by default**.
- Entry point: `bin/pandoc-pdf`. The command surface is what `--help` prints and
  `docs/usage.md` documents.
- Local suite: **PASS=271 FAIL=0**, thirteen area files under `tests/l1/` plus.
- **CI is not running**: the account has no Actions minutes left, so every job
  fails to start. `make gate` (suite, catalogs, documentation references, plan
  conformance) is the verification, and its output goes into the pull request.
  `tests/lib.sh`; `tests/run.sh` only orchestrates them.
- Toolkit version (`VERSION`): **1.2.0**, with **no tag**. The release is
  postponed by maintainer decision (D8).
- Local `python3` has no PyYAML, so the Ruby YAML path is the one exercised here;
  both paths are kept in sync and the Python one runs in CI.

## State by area

### 1) CLI

- `doctor` validates the runtime through `scripts/preflight.py`; `runtime.strict:
  false` waives auxiliary commands but never the TeX engine (D2).
- `validate-config` enforces the contract plus functional path checks (D3).
- `render` has a single renderer, `scripts/render-native.py`. The Ruby duplicate
  is gone; Ruby remains only as an optional YAML parser.
- `render --dry-run [--json]` prints a pure `plan_version: 1` plan and writes
  nothing (D6).
- `doctor` renders a test Mermaid diagram and, on failure, names the detected
  `mermaid-cli` version next to the two documented fixes.

### 2) Configuration and paths

- `schemas/pdf-config.schema.json` is the single source of truth; there is no
  defaults baseline to merge (D7).
- `validate-config` checks the critical paths: `input.chapters_dir`,
  `pandoc.template` when set, `pandoc.metadata_file` when set, and
  `filters.extra_lua_filters`.
- `pandoc.template` is optional: absent, the toolkit template is used; present,
  it resolves relative to `project.base_dir`.

### 3) Security

- Preflight hardened against injection: no `bash -c` to resolve commands from
  configuration.
- Safe YAML loading on every path, including the Ruby fallback.
- Security workflow runs Semgrep and Gitleaks from pinned container images, so it
  no longer depends on the runner's Python.
- Every GitHub Action is pinned to a commit SHA (D10), kept current by
  `.github/dependabot.yml`.
- Policy published in `.github/SECURITY.md`; the gates are in `docs/releasing.md`.

### 4) Testing and CI

- CI by levels: **L1** mandatory on pull request and push (macOS and Linux);
  **L2** semi-real integration, manual; **L3** full integration, manual or
  scheduled, including Mermaid.
- `scripts/check-docs.py` fails the suite when a document points at something
  that no longer exists, and every example config is validated.
- Each commit of the 1.2.0 work passed the suite on its own, checked by
  extracting each tree with `git archive`.

### 5) Documentation and governance

- The repository is English, including this file and `odd/`; the only Spanish is
  the message catalogs and the example chapters (D9).
- `docs/README.md` indexes every document by the question it answers;
  `CONTRIBUTING.md` is the path for a human contributor.
- `CHANGELOG.md` carries one honest `[Unreleased]` section stating that 1.2.0 has
  no tag yet.

## Decisions taken during 1.2.0

| # | Decision |
| --- | --- |
| D1 | A single renderer (Python). Ruby stays only as an optional YAML parser in a subprocess; removing it entirely would require making PyYAML mandatory, and that was decided **against**. |
| D2 | `runtime.strict: false` waives auxiliary dependencies, never the TeX engine: without an engine there is no PDF, so it always fails. |
| D3 | `validate-config` rejects a missing `pandoc.metadata_file` and validates `input.order` against its `enum`. The validator implements a documented JSON Schema subset and a test fails if the schema uses any other keyword. |
| D4 | Shell i18n unified in `scripts/i18n.sh`: catalog loaded once, no fork per message, one precedence chain for both entry points. |
| D5 | Metadata precedence: when `pandoc.metadata_file` is set it wins and no `-V` variables are passed; when empty, the `document.*` fields become template variables. |
| D6 | The plan shape (`plan_version: 1`) is frozen as is: `cwd: null` (inherited), `env` with the toolkit's four variables, and `prepare_argv[0]` as the neutral `python3` token. Any shape change requires `plan_version: 2`. |
| D7 | `defaults/default.yaml` removed: the schema is the single source of truth. |
| D8 | Release postponed: 1.2.0 is on `master` with no tag. Creating the tag triggers `release.yml`, a path no pull request exercises. |
| D9 | The repository is English, including this file and `odd/`; only the catalogs are translated. |
| D10 | Every action is pinned to a commit SHA with its tag in a comment. Dependabot tracks the `github-actions` ecosystem weekly, so the pins do not rot; a tag is a mutable pointer, and these workflows handle the token that publishes releases. |
| D11 | `mermaid-cli` is a **tested** version, not an enforced one: 10.9.1 is what the toolkit installs and CI renders with, any other version is accepted when `doctor` renders its test diagram, and this repository never pins a user's system-wide install. See `docs/dependency-policy.md`. |
| D12 | `pandoc.metadata_file` is optional: the legacy side file stays supported and wins when present, but a configuration can now carry the cover through `document.*`, plus `document.language`, `document.titlepage` and a free-form `document.metadata` map. The file name still comes from `document.title`, so no consumer's output is renamed. |

## Native review (RDD) — a size threshold, not a broken provider

State: **usable, and it works on small candidates**. Four attempts with the same
reviewer:

| candidate | result |
| --- | --- |
| 1,088 lines | `review-resilience` returns an empty answer |
| 1,159 lines | same |
| 159 lines | same |
| **62 lines** | **approved, 4/4 lenses, no blocking finding** |

Cause: the model serving the resilience lens reasons until it hits the gateway
guard (`420 s / 45.000 reasoning-character limit`) and then returns nothing, so
whether it finishes depends on how much the candidate makes it think: **above
roughly a hundred lines it fails, below it works**.

Consequences:

- Review a commit or a focused change, never a whole branch.
- An approved review is not a substitute for tests, and a failed review is not a
  reason to skip them: the gate is the suite plus human review of the pull
  request.
- Retrying on a large candidate wastes about ten minutes and leaves a lineage to
  abandon.

## Binary migration (Go) — pending decision

State: **no migration now**. Windows is not a current requirement and the toolkit
is consumed on Linux and macOS. The door is explicitly left open.

What the door consists of:

1. `render --dry-run --json`: done, and the plan shape is frozen (D6).
2. A conformance suite over that plan: `scripts/check-plan-conformance.py`
   compares four recorded cases without reading renderer code. `PANDOC_PDF_BIN`
   selects any implementation (today's Python, a future Go one), and `--update`
   refreshes expectations. The L1 suite checks conformance and failure diagnostics.

Migration triggers (any one of them):

- Windows becomes a real requirement.
- A target consumer cannot provide `python3` + PyYAML.
- Signed single-file artifacts are needed for the supply chain.
- Bash updater defects cost more than a rewrite.

## Known follow-ups

1. **Render-plan conformance is implemented**: four cases and normalized JSON
   expectations under `tests/conformance/`, checked by
   `scripts/check-plan-conformance.py` and wired into the L1 suite, make the Go
   door testable and catch renderer regressions today.
2. **Artifact signing** (Sigstore/GPG) for release artifacts.
3. **Examples that show the toolkit's capabilities**: one example and one chapter
   is the whole surface today (tracked in issue #37).

## Risks worth keeping on the page

- Environment differences (TeX, Mermaid, Chromium) between a local run and full
  integration execution, which is why L2 and L3 stay manual.
- Publication depends on GitHub Releases, which is also what the updater
  consumes.
