# Operational context (current)

> This file reflects changing state. Stable rules live in `AGENTS.md`, and every
> document is indexed in `docs/README.md`. Correct a statement here rather than
> appending to it: a section that grows is a section nobody trusts.

## Current state

- **Stable CLI with native render by default.** The entry point is
  `bin/pandoc-pdf`; the command surface is what `--help` prints and
  `docs/usage.md` documents.
- **The verification is `make gate`**: suite, catalogs, documentation references
  and plan conformance. How many assertions that is belongs to the run, not to
  this file.
- **CI is not running**: the account has no Actions minutes, so every job fails to
  start. Until it does, `make gate` output pasted into the pull request is the
  evidence a maintainer accepts.
- Toolkit version (`VERSION`): **1.2.0**, with **no tag**; the release is
  postponed by decision (D8).
- Local `python3` has no PyYAML, so the Ruby YAML path is the one exercised here,
  and the Python one runs where PyYAML exists. Neither environment exercises both
  (`docs/dependency-policy.md`).

## Where each area is described

Not restated here: a second copy of a description is a second place to be wrong.

| Area | Described in |
| --- | --- |
| CLI surface and behaviour | `docs/usage.md`; the command list is `--help` |
| The contract and its rules | 'Configuration contract' in `docs/architecture.md`, and the schema itself |
| Render pipeline and the plan | 'Toolkit structure' and 'Render pipeline' in `docs/architecture.md` |
| Security posture and CI gates | `docs/releasing.md`, `.github/SECURITY.md` |
| Suite and CI levels | `CONTRIBUTING.md` |
| Pinned dependencies and blind spots | `docs/dependency-policy.md` |
| Internationalisation | `docs/i18n.md` |
| How a version is cut | `docs/releasing.md` |

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
