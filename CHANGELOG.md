# Changelog

All notable changes to this toolkit are documented in this file.

The project follows semantic versioning and keeps two versioned contracts:

- `VERSION` for the toolkit version
- `pdf.config.yaml -> version` for the configuration contract

## [Unreleased] — planned as 1.2.0

`VERSION` says `1.2.0` and no tag exists yet, so everything below was merged
after the 1.1.3 release and is **not published**.

### Configuration that no longer requires a side file

- `pandoc.metadata_file` and `output.file_prefix` are **optional**. Without a
  metadata file, `document.*` reaches the template, which is what the renderer
  already implemented. Existing configurations keep validating unchanged.
- New `document.language` (`en`, `es`, `pt`, `gl`) selects the babel language.
  The template no longer hardcodes Spanish; the default is unchanged.
- New `document.titlepage` switch: the cover can now be disabled. It used to be
  unconditional, which made the same key in a metadata file inert.
- New `document.metadata` map for arbitrary Pandoc metadata (`keywords`,
  `subject`, any template variable), so those no longer need a side YAML file.
- The output file name is now a slug of `output.file_prefix` when declared, and a
  slug of `document.title` otherwise. It used to be the raw title, spaces and
  accents included, while `file_prefix` was ignored. See the migration guide.
- The default typesetting language is **English**. It used to be Spanish, the
  language of the first consumer, which made the toolkit Spanish by omission for
  everyone else. Declare `document.language: es` to keep the previous hyphenation.
  See the migration guide.

### Added

- The five contract fields the schema already required and the runtime never
  read now take effect:
  - `input.order`: `natural` compares numeric runs as numbers (`chapter-2.md`
    before `chapter-10.md`); `alphabetical` keeps lexicographic order. Any other
    value is rejected.
  - `output.keep_merged_markdown`: `false` deletes the merged `.md` after a
    successful pandoc run and keeps it when pandoc fails, for diagnosis.
  - `document.*`: with `pandoc.metadata_file` empty, `title`, `subtitle`,
    `publisher`, `author`, `date` and `rights` reach pandoc as template
    variables (`-V field=value`) and fill the cover page that
    `templates/default.tex` already expected.
  - `filters.emoji.include_ballot_icons`: `false` leaves Markdown task boxes
    (`☐`, `☑`, `☒`) as characters instead of substituting images.
  - `runtime.strict`: `false` reports missing dependencies as warnings and
    exits 0, including on the minimal YAML path used when PyYAML is absent. The
    TeX engine is never waived: without it there is no PDF, so its absence
    always fails.
- `pandoc-pdf render -c <config> --dry-run` prints the render plan and writes
  nothing; `--dry-run --json` emits it as JSON (`plan_version: 1`) with the
  chapters in effective order, the targets, the pandoc `argv` and the
  environment. The plan is pure: `execute_plan` is the only place with side
  effects, and the parity test pins both renderers to the same plan while more
  than one exists.

### Changed

- `pandoc-pdf locale set --project <lang>` writes `.pandoc-pdf.env` in the directory it runs from, and the CLI finds it by walking up from the current directory. It used to write into the toolkit installation, so two consuming repositories shared one locale.
- One shell i18n runtime (`scripts/i18n.sh`) shared by `bin/pandoc-pdf` and
  `scripts/bootstrap.sh`: locale resolution and `t` are no longer duplicated and
  translating a message spawns no process. Measured on the same machine,
  `pandoc-pdf --help` went from 0.188 s to 0.080 s and from five `python3`
  processes to one. `bootstrap.sh` now also honours the language set with
  `pandoc-pdf locale set`, which it used to ignore.
- The locale error no longer suggests `--team`, an option that never existed: it
  names the real one, `pandoc-pdf locale set --project <lang>`.
- `--resource-path` is joined with the platform separator instead of a hardcoded
  `:`.
- `scripts/package-release.sh` builds the tree once and publishes the same
  artifact under the four platform names instead of packing four times.

### Fixed

- A dropped Mermaid diagram no longer hides behind a successful render. When `mmdc` is installed but cannot launch a browser, `filters/mermaid.lua` leaves the diagram as a code block and records it; `render` now reports how many diagrams were lost and exits non-zero, and `doctor` renders a test diagram beforehand and prints the fix. `filters.mermaid.enabled: false` remains the explicit way to drop diagrams.
- `validate-config` silently ignored any JSON Schema keyword outside its own
  subset (`enum`, `pattern`, `$ref`…). It now implements `enum` and a test fails
  if the schema starts using an unsupported keyword.
- `input.order` is validated against its `enum` in `validate-config`, not only in
  the renderer: an unsupported value is rejected with a message naming the
  field, the allowed values and the received one.
- `validate-config` rejects a `pandoc.metadata_file` that does not exist. The
  renderer used to skip it silently, so a typo produced a PDF without the
  declared metadata and without any warning.
- `filters/emoji.lua` no longer wraps text without emojis in a `Span`. Plain
  headings stop emitting `\texorpdfstring` (a macro `hyperref` defines) and the
  filter stops breaking minimal templates. The defect predates 1.2.0: the L2
  integration job was already failing on `master` because of it.

### Removed

- `scripts/render-native.rb`: a single renderer remains, in Python. The duplicate
  cost 398 lines of parallel logic and existed only because the CLI picked it
  when PyYAML was missing; the renderer now parses YAML with PyYAML when
  available and otherwise delegates to Ruby's stdlib in a subprocess, the same
  resource `validate-config` already used. It only affects callers that invoked
  that script directly.
- `defaults/default.yaml`: the schema is the single source of truth. The file was
  unreachable through the validated path (the schema already required every key
  it provided) and only a test that bypassed the CLI exercised it.
- `defaults_path` / `defaults_exists` from `pandoc-pdf info` (text and `--json`),
  since the file no longer exists.
- The duplicate `filters/emoji/emoji_u{2610,2611,2612}.svg` assets, byte-identical
  to `2610.svg`, `2611.svg` and `2612.svg`, unreferenced and copied into the
  emoji directory on every run.
- `scripts/__pycache__` and `.pyc` files from the release artifact.

### Tests

- The L1 suite grew from 145 assertions to 228 and stopped being a single file:
  2,365 lines became `tests/lib.sh` with the shared assertions and fixture
  helpers plus one file per area under `tests/l1/`, with `tests/run.sh` (77 lines)
  orchestrating. Each split step kept the same PASS count before and after.
- New assertions pin every behaviour above: `input.order` (both values and the
  rejected one), `output.keep_merged_markdown` on success and on pandoc failure,
  `document.*` versus `pandoc.metadata_file`, `include_ballot_icons`,
  `runtime.strict` with and without the TeX engine, `metadata_file` validation,
  the schema keyword guard, the render plan and the emoji filter in headings,
  paragraphs, table cells, captions and list items.
- The two Python/Ruby parity tests were retired together with the duplicate
  renderer and replaced by a structural pin: `render-native.rb` must not come
  back.
- `tests/integration/*` templates now load `graphicx` and `hyperref`, so L2
  verifies a real render again instead of failing before pandoc could produce a
  PDF.
- Test-only YAML double (`tests/fixtures/yaml_shim/yaml.py`) so the Python
  renderer can be exercised where PyYAML is absent.

### Maintenance

- Keep the pinned dependency review periodic and documented per update.

---

## [1.1.3] - released

### Fixed

- `pandoc-pdf update` downloads authenticated artifacts from private releases
  through the GitHub asset API (`assets[].url`) when a token is present
  (`PANDOC_PDF_UPDATE_TOKEN` / `GH_TOKEN`), avoiding the 404 on
  `browser_download_url`.
- Added the `Accept: application/octet-stream` header for downloads through the
  asset API.

### Tests

- New regression in `tests/run.sh` covering installation through `update` with the
  asset API in an authenticated context
  (`run_update_install_private_api_asset_test`).

---

## [1.1.2] - released

### Fixed

- `Security` workflow stabilised for repositories with Code Scanning disabled:
  - SARIF upload is gated behind the repository variable
    `ENABLE_SARIF_UPLOAD == true`.
  - Scans and the CI threshold policy always run.

### Changed

- Operational security policy updated for the SARIF feature flag:
  - by default, CI validates security without depending on Code Scanning;
  - once Code Scanning is enabled, set `ENABLE_SARIF_UPLOAD=true` to publish
    SARIF on `push` to `main/master`.

---

## [1.1.1] - released

### Fixed

- `Security` workflow adjusted to avoid permission failures on pull requests
  (`Resource not accessible by integration`):
  - SARIF is published only on `push` to `main/master`;
  - on `pull_request`, scans and thresholds run without the SARIF upload.
- Workflow permissions tightened for uploads on protected branches
  (`actions: read`, `security-events: write`).
- SARIF upload action updated to `github/codeql-action/upload-sarif@v4`.

### Changed

- Release-readiness documentation updated with the per-event operational security
  policy (`push` versus `pull_request`).

---

## [1.1.0] - released

### Added

- CLI and runtime i18n with per-key catalogs in `en`, `es`, `pt` and `gl`.
- `pandoc-pdf locale` simplified to `show`, `set <lang>` and `set --project <lang>`.
- Global language configuration in `~/.config/pandoc-pdf/config.env`.
- Catalog and placeholder parity validation (`scripts/check-i18n.py`) wired into
  the tests.
- `pandoc-pdf update --check` to look up the latest stable GitHub release.
- Update commands from a release:
  - `pandoc-pdf update`
  - `pandoc-pdf update --to <tag>`
  - `--yes`, `--dry-run` and `--install-dir` support.
- Authentication for private repositories in the updater through
  `PANDOC_PDF_UPDATE_TOKEN` or `GH_TOKEN`.
- Managed updater installation in a versioned directory
  (`~/.local/share/pandoc-pdf/versions/<tag>`) with a `current` pointer.
- `update` explicitly blocked when the command runs as `pandoc-pdf-dev`.
- Automatic release workflow (`.github/workflows/release.yml`) publishing
  artifacts and `checksums.txt` on `v*` tags.
- SARIF publication for Semgrep and Gitleaks in GitHub Security.
- Severity threshold policy for the security CI through
  `scripts/enforce-security-thresholds.py`.
- Distribution scripts:
  - `scripts/package-release.sh` (tarballs plus checksums)
  - `scripts/install.sh` (stable install from the latest release without cloning)
  - `scripts/install-local.sh` (install from the local repository into the
    managed layout, with a dev option)
- Local integration runners:
  - `tests/l2-local.sh` (semi-real)
  - `tests/l3-local.sh` (full runtime with Mermaid)

### Changed

- L2/L3 CI reuses the local runners (`tests/l2-local.sh`, `tests/l3-local.sh`) to
  avoid drift between local runs and GitHub Actions.
- Security workflow updated to upload SARIF and apply explicit severity
  thresholds.
- Documentation synchronised with the real state of the toolkit (`locale`
  command, active locales, operational state and i18n guide).

### Fixed

- Removed leftover i18n couplings:
  - hardcoded messages in `scripts/check-i18n.py` and `scripts/prepare-emojis.py`;
  - hardcoded `locale show` labels in `bin/pandoc-pdf`;
  - incomplete `bootstrap.*` key coverage in the catalogs.
- Operational text homogenised at the root (`Makefile`) to avoid legacy messages
  outside the current i18n strategy.
- Updater hardening with post-install version validation, robust rollback and
  optional operational logging (`PANDOC_PDF_UPDATE_LOG_FILE`,
  `PANDOC_PDF_UPDATE_VERBOSE`).

---

## [1.0.0] - released

First stable public release of the toolkit.

### Added

- Stable CLI `bin/pandoc-pdf` with the commands:
  - `--version` / `version`
  - `info` / `info --json`
  - `doctor`
  - `validate-config -c <file>`
  - `render -c <file>` (native mode by default)
- `VERSION` as the canonical source of the toolkit version.
- `scripts/preflight.sh` as a decoupled runtime check.
- Native render decoupled into:
  - `scripts/render-native.py`
  - `scripts/render-native.rb`
- Versioned configuration contract with:
  - `schemas/pdf-config.schema.json`
  - `examples/pdf.config.example.yaml`
  - `defaults/default.yaml`
  - `templates/default.tex`
- `tests/run.sh` suite with contract, render and integration fixtures.
- CI by levels:
  - L1 (fast, PR/push)
  - L2 (semi-real, manual)
  - L3 (full integration, manual/scheduled)
- Dedicated security workflow (`.github/workflows/security.yml`: Semgrep plus
  Gitleaks).
- Dependabot (`.github/dependabot.yml`).
- Operational documentation:
  - `README.md`
  - `docs/install.md`
  - `docs/usage.md`
  - `docs/migration.md`
  - `docs/architecture.md`
  - `docs/release-readiness.md`
  - `docs/dependency-policy.md`
- Governance and security:
  - `LICENSE` (Apache-2.0)
  - `.github/CODEOWNERS`
  - `.github/SECURITY.md`

### Changed

- `validate-config` moved to strict, schema-driven validation (required fields,
  types, `additionalProperties`).
- `pandoc.template` became optional in the schema.
- `doctor` delegates to `scripts/preflight.sh`.
- `render` dropped the legacy fallback and operates in native mode by default.
- `bootstrap` improved with Linux package-manager detection (`apt-get`, `dnf`,
  `yum`, `pacman`, `zypper`, `apk`).
- CI hardened with minimal permissions (`permissions: contents: read`).
- Critical dependencies pinned in bootstrap/CI/security (`mermaid-cli`, `PyYAML`,
  `Semgrep`, `Gitleaks`).
- Base template moved from the root to `templates/default.tex`.
- Legacy scripts and obsolete artifacts removed.

### Fixed

- Preflight hardened against injection (no `bash -c`; validation of
  `runtime.required_commands`).
- Safe YAML loading in Ruby (`YAML.safe_load`) for validation, preflight and
  native render.
- Tests hardened in isolated `PATH` and assertions (`grep --`).
- Template fallback regression fixed:
  - when the user does **not** set `pandoc.template`, the toolkit default
    template is used;
  - when the user sets `pandoc.template`, it is resolved relative to
    `project.base_dir`.
