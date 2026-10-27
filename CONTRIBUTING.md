# Contributing

The toolkit produces PDFs with Pandoc for consuming repositories, so a change
usually lands in one of three places: the configuration contract, the renderer,
or the documentation a consumer reads. This page is the practical path; the
stable rules live in [`AGENTS.md`](AGENTS.md).

## Setup

```bash
git clone <your fork>
cd pandoc-toolkit
make bootstrap   # pandoc, a TeX engine, mermaid-cli and the Python helpers
make test        # the whole suite
```

`make bootstrap` installs system dependencies and is slow the first time. For
everything except an actual render, `make test` needs no extra setup.

## Commands you will use

| Command | What it does |
| --- | --- |
| `make test` | Runs `bash tests/run.sh`, the whole suite |
| `make gate` | Everything a pull request is verified with: suite, catalogs, docs, plan conformance |
| `make validate CONFIG=path/to/pdf.config.yaml` | Validates a configuration against the schema |
| `make doctor` | Checks the local toolchain |
| `make install-local-dev` | Puts the working copy on `PATH` for manual testing |
| `python3 scripts/check-i18n.py` | Catalog parity and placeholders |
| `python3 scripts/check-docs.py` | No document points at something missing |

`make gate` is the gate: run it before opening a pull request. When CI cannot start
(an account without Actions minutes is the usual reason), it is the verification:
put its output in the pull request so the decision to merge is recorded rather
than assumed.

The suite is one process: `tests/run.sh` sources every `tests/l1/<area>.sh` and
runs them in order. There is no per-area flag, so when you touch one area, read
its file and expect the whole suite to tell you what else broke.

## Test first

A behaviour change comes with a test that fails before it. The suite is shell,
with the assertions in `tests/lib.sh`:

- one assertion per rule the change introduces;
- for every existing command or option the change touches, one assertion that its
  previous behaviour still holds;
- observed red before the fix, green after it.

Documentation needs no test, but it must keep `check-docs.py` green.

## Messages

Never write a user-facing string in code. Add the key to **all four** catalogs in
`i18n/locales/` (`en`, `es`, `pt`, `gl`) with identical placeholders, then run
`python3 scripts/check-i18n.py`. English is the wording that is written first;
the others are translations, not copies.

## Where a change belongs

| Changing | Touch |
| --- | --- |
| The configuration contract | `schemas/pdf-config.schema.json`, then `scripts/validate-config.py`, then `tests/l1/validate.sh` |
| The CLI surface | `bin/pandoc-pdf` and its catalog keys, then `tests/l1/help.sh`, then `docs/usage.md` |
| Rendering | `scripts/render-native.py`, plus the checks in `scripts/preflight.py`; `tests/l1/render.sh` |
| A filter | `filters/<name>.lua`; a failure must be loud, never silent |
| Dependencies | `scripts/bootstrap.sh`, `.github/workflows/`, `docs/dependency-policy.md` |
| A breaking change | All of the above, plus `docs/migration.md`, a `CHANGELOG.md` entry and a contract version bump |

[`docs/README.md`](docs/README.md) maps every document to the question it answers.

## Commits and pull requests

- Branch from `main`, one branch per change.
- Conventional Commits: `feat:`, `fix:`, `docs:`, `test:`, `ci:`, `refactor:`.
- Tests and documentation belong in the same commit as the behaviour.
- Keep a pull request reviewable, around 400 changed lines; beyond that, split it.
- Pull requests are squash-merged, so the commit message is the record, not the
  branch history.

## Language

The repository is written in English: code, comments, documentation, commit
messages and pull request descriptions. The only Spanish in the tree is the
message catalogs (`i18n/locales/es.json` and friends) and the example chapters,
which exist to prove that accents and punctuation render.

## Releasing

Maintainers cut versions. The gates, the commands and what CI does not exercise
are in [`docs/releasing.md`](docs/releasing.md).

## CLI tests and CI levels

`make test` runs the suite. The integration runners, which the table above does
not list because they need a fuller stack:

```bash
bash tests/l2-local.sh
bash tests/l3-local.sh
```

Notes:
- `l2-local.sh` runs semi-real integration (without the full Mermaid stack).
- `l3-local.sh` requires `mmdc` and Chromium (`PUPPETEER_EXECUTABLE_PATH` if it is not auto-detected).

Current suite coverage:

- help and unknown-command handling
- `doctor` in an OK scenario and with a missing dependency
- `validate-config` with a valid and an invalid case
- `render -c` in native mode (checks output/environment)
- explicit rejection of legacy flags (`--legacy`)
- advanced render integration (extra_lua_filters, resource_path, optional metadata)
- render errors for non-existent `explicit_files`
- render plan: valid JSON, no side effects, readable `--dry-run`
- emoji filter: plain headings do not emit `\\texorpdfstring`
- contract behavior (since 1.2.0):
  - `input.order` with `natural` and `alphabetical` values, and rejection of an unsupported value naming the field and the supported values
  - `output.keep_merged_markdown` set to `false` (deletes the `.md`) and `true` (keeps it), with a PDF produced in both cases
  - `document.*` reaches pandoc as `-V` variables, and a `pandoc.metadata_file` takes precedence over them
  - `include_ballot_icons` toggles `PANDOC_EMOJI_BALLOT_ICONS` between `1` and `0`
  - `runtime.strict` set to `false` (warning, exit 0) and `true` (failure)
- release artifact: the generated package contains no Python bytecode (`__pycache__`, `.pyc`)
- locale message with no destination: names `--project`, not `--team`

In addition, this suite runs automatically in CI (GitHub Actions) for PR/push on a macOS/Linux matrix as **L1**.

CI levels:

- **L1 (fast, mandatory on PR/push):** `tests/run.sh`.
- **L2 (semi-real, manual):** real render on Ubuntu against integration fixtures.
- **L3 (full, manual or scheduled):** integration with the extended stack (includes the Mermaid CLI).
  - includes a real Mermaid fixture in `tests/integration/l3-mermaid-project/`.

Workflow and manual inputs:

- Workflow: `.github/workflows/ci.yml`
- `run_render_integration=true` to run **L2**
- `run_render_full=true` to run **L3**

Run from the CLI:

```bash
gh workflow run ci.yml -f run_render_integration=true
# or
gh workflow run ci.yml -f run_render_full=true
```

## Repository housekeeping

To keep the toolkit clean and reusable:

- **Do not** add local system artifacts (`.DS_Store`, etc.).
- **Do not** reintroduce legacy scripts coupled to the consumer repository.
- Always use the official entrypoint: `bin/pandoc-pdf`.
- Keep examples and docs neutral (no private data or client paths).
