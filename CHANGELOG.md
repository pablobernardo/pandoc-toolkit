# Changelog

All notable changes to this toolkit are documented in this file.

The project follows semantic versioning and keeps two versioned contracts:

- `VERSION` for the toolkit version
- `pdf.config.yaml -> version` for the configuration contract

## [2.1.0] - 2026-11-01

### Fixed

- A link between selected chapters becomes an internal anchor instead of a
  reference to a file the merged publication does not contain. It resolves in the PDF and in the EPUB, and a project without
  cross-references keeps a byte-identical merged document (#94).
- EPUB keeps emoji as characters inside headings. The generated navigation
  document reused them as images, which is not valid link text, with a path that
  escaped the package. Emoji in paragraph text stay images, and PDF output is
  unchanged (#94).
- Relative assets resolve from `project.base_dir` in both formats, so a content
  image or a cover declared against the project no longer breaks when the
  command runs from another directory. The project base is appended last to the
  resource path, so a declared `pandoc.resource_path` keeps its priority (#94).
- EPUB output no longer carries the generated `\clearpage` between chapters. The
  compatibility switch still applies to the PDF, which is unchanged (#94).
- EPUB tables retain table layout with visible overflow and wrapping cell text,
  instead of scrollable blocks that can interfere with reader pagination. PDF
  table styling is unchanged (#94).
- EPUB internal title pages now separate title/subtitle, credits and rights with
  relative spacing and typographic hierarchy, without changing chapter or PDF
  styling (#94).
- EPUB initial headings no longer request a redundant page break before title,
  navigation or split chapters. PDF styling and plans are unaffected (#94).
- EPUB publications now carry the configured author and respect metadata-file
  precedence for document text fields, instead of appearing as unknown author.
  The configured document language remains authoritative (#94).

### Added

- EPUB publications carry an existing cover image declared through `cover-image`
  in the metadata file, or through `document.metadata` when no file is
  configured. Nothing generates a cover, and PDF styling is unchanged (#94).
- Optional `output.formats: [pdf, epub]` selects one or both artifacts in one
  invocation. Omitted means `[pdf]`, preserving recorded PDF plans. Successful
  files remain if another format fails; the command returns nonzero. EPUB-only
  requests need no implicit TeX engine; explicit runtime requirements apply.
  This replaces the unreleased singular `format` field; see
  [migration](docs/migration.md). Multi-output JSON plans use version 2 (#94).
- Visible emoji compatibility samples in the ohmyfake example's heading,
  paragraph, list and table, with regression coverage for those contexts (#93).
- An optional installable Agent Skill for configuring, checking and reviewing PDFs
  from existing Markdown in consuming repositories, using the Agent Skills format (#86).

## [2.0.1] - 2026-10-30

The configuration contract remains at `1`; these fixes require no consumer
migration.

### Added

- A documentation-as-PDF example using the toolkit's own `docs/` as input, with
  filters disabled and a numbered table of contents (#73).

### Changed

- Documentation now separates the user-focused README from contributor CI
  instructions, removes obsolete migration and self-update guides, and updates
  the documentation PDF's reading order to cover the current guides. Removes
  unused OpenCode guidance, the duplicate operational-context summary and local
  agent skills; contributor and security guidance now have one home each.
- Installation guidance now leads with the no-clone, token-free release install
  and explains the managed layout and update path (#72).
- Release documentation clarifies that the four platform tarball names are
  aliases of one platform-independent artifact, with identical checksums (#71).

### Fixed

- L2/L3 CI rendering jobs explicitly install the template's LaTeX prerequisites,
  font metrics and SVG converter, and check declared styles before rendering.
  L3 uses the hosted image's Chrome instead of a Chromium Snap, with explicit
  browser and Mermaid HTML checks; no runtime or browser-sandbox changes.
- Configuration validation no longer requires the `compat` section or optional
  emoji/Mermaid settings. Disabled filters need only `enabled: false`; enabled
  filters can use the renderer's existing defaults (#76).
- The packaging test accepts the CLI entry with or without a `./` prefix in the
  archive listing and reports diagnostics when it is missing (#77).
- Apply code wrapping to Pandoc's actual highlighted-block environment as well as
  untagged blocks. Wrap at spaces and separators without splitting arbitrary
  letters. Inline code can wrap after `/`, `.` and `=`; long unbreakable
  identifiers can still exceed the available width.
- Disable automatic syllable hyphenation in prose so words move whole to the
  next line.
- Reserve space for H1–H5 and their following content to avoid headings stranded
  at the foot of a page, while retaining consecutive-heading protection.

### Known limits

- H6 is emitted as plain text by Pandoc's LaTeX writer and does not receive the
  H1–H5 heading protection.
- Arbitrary unbreakable content can still overflow; wrapping does not split
  every identifier or guarantee that all content fits.
- Missing Unicode glyphs remain tracked in #83; these layout fixes do not
  resolve font coverage.

## [2.0.0] - released

The first release since 1.1.3, and a major one because **defaults changed**: the
output file name, the typesetting language and the update path. Every one of them
has its section in `docs/migration.md`. The configuration contract version stays
at `1`: no key was removed or made stricter, so existing files keep validating.

### Added

- Three runnable examples, each covering a different branch of the contract and
  documented by what it demonstrates in `docs/usage.md`: a six-chapter narrative
  with a diagram per chapter, an operator's manual with H1 to H4, tables and
  footnotes, and the smallest valid configuration. `examples/toPDF.sh` renders all
  three and the suite validates their configs.
- `pandoc-pdf render -c <config> --dry-run` prints the render plan and writes
  nothing; `--dry-run --json` emits it as JSON (`plan_version: 1`) with the
  chapters in effective order, the targets, the pandoc `argv` and the environment.
  The plan is pure: `execute_plan` is the only place with side effects.
- `document.language` (`en`, `es`, `pt`, `gl`) selects the babel language, so the
  template no longer hardcodes one.
- `document.titlepage` disables the cover page, which used to be unconditional.
- `document.metadata` carries arbitrary Pandoc metadata (`keywords`, `subject`,
  any template variable) without a side YAML file.
- `doctor` names the detected `mermaid-cli` version when a diagram fails, next to
  the two documented fixes.
- A conformance suite over the render plan: four recorded cases compared after
  normalizing machine-local paths, runnable against another implementation through
  `PANDOC_PDF_BIN`.
- `make gate`: the suite, the catalogs, the documentation references and the plan
  conformance in one command, so a pull request can be verified without CI.
- `scripts/check-docs.py`: fails when a document points at something that does not
  exist, or when a published file contains an absolute home path.

### Changed

- The output file name is a **slug**: `output.file_prefix` when declared, a slug of
  `document.title` otherwise. It used to be the raw title, spaces and accents
  included, while `file_prefix` was required and ignored.
- The default typesetting language is **English**. It used to be Spanish, the
  language of the first consumer, which made the toolkit Spanish by omission for
  everyone else.
- `pandoc.metadata_file` and `output.file_prefix` are **optional**. Without a
  metadata file, `document.*` reaches the template; with one, the file wins as
  before.
- The five contract fields the schema already required and the runtime never read
  now take effect:
  - `input.order`: `natural` compares numeric runs as numbers (`chapter-2.md`
    before `chapter-10.md`); `alphabetical` keeps lexicographic order. Any other
    value is rejected.
  - `output.keep_merged_markdown`: `false` deletes the merged `.md` after a
    successful pandoc run and keeps it when pandoc fails, for diagnosis.
  - `document.*`: with `pandoc.metadata_file` empty, `title`, `subtitle`,
    `publisher`, `author`, `date` and `rights` reach pandoc as template variables
    (`-V field=value`) and fill the cover page `templates/default.tex` already
    expected.
  - `filters.emoji.include_ballot_icons`: `false` leaves Markdown task boxes
    (`☐`, `☑`, `☒`) as characters instead of substituting images.
  - `runtime.strict`: `false` reports missing dependencies as warnings and exits 0,
    including on the minimal YAML path used when PyYAML is absent. The TeX engine
    is never waived: without it there is no PDF, so its absence always fails.
- `pandoc-pdf locale set --project <lang>` writes `.pandoc-pdf.env` in the
  directory it runs from, and the CLI finds it by walking up, so each consuming
  repository has its own locale instead of sharing the toolkit's.
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
- The updater fetches release metadata and artifacts **without credentials**, and
  says which of three things happened when it fails: no release published yet
  (404), the anonymous quota exhausted (403 or 429, 60 requests per hour per
  address), or an unreachable host. All three used to report "could not fetch
  latest release metadata" and then suggest a token.
- The toolkit is **MIT** from this version onwards. Everything published up to
  1.1.3 stays under Apache 2.0: a license is not retroactive.
- The default branch is `main`.
- Documentation: an index that maps every document to the question it answers,
  `CONTRIBUTING.md` for humans, `docs/releasing.md` for the release process, and
  the numbered decisions in the `Decision record` of `docs/architecture.md`
  instead of in the state file.

### Fixed

- A dropped Mermaid diagram no longer hides behind a successful render. When
  `mmdc` is installed but cannot launch a browser, the filter records the loss and
  the render fails; `doctor` renders a test diagram and prints both remediations.
- `validate-config` silently ignored any JSON Schema keyword outside its own
  subset (`enum`, `pattern`, `$ref`…). It now implements `enum` and a test fails
  if the schema starts using an unsupported keyword.
- `input.order` is validated against its `enum` in `validate-config`, not only in
  the renderer: an unsupported value is rejected with a message naming the field,
  the allowed values and the received one.
- `validate-config` rejects a `pandoc.metadata_file` that does not exist. The
  renderer used to skip it silently, so a typo produced a PDF without the declared
  metadata and without any warning.
- `filters/emoji.lua` no longer wraps text without emojis in a `Span`. Plain
  headings stop emitting `\texorpdfstring` (a macro `hyperref` defines) and the
  filter stops breaking minimal templates.
- The emoji source that no longer exists: the Noto assets moved to `2D/svg/` and
  every download was failing silently against the fallback.

### Removed

- `PANDOC_PDF_UPDATE_TOKEN` and `GH_TOKEN` support, and with it the private-mirror
  path: `release_asset_api_url_from_json`, the API-asset upgrade on install, and
  the test that exercised it. A private mirror of the releases is no longer
  supported by this updater.
- `scripts/render-native.rb`: a single renderer remains, in Python. The duplicate
  cost 398 lines of parallel logic and existed only because the CLI picked it when
  PyYAML was missing; the renderer now parses YAML with PyYAML when available and
  otherwise delegates to Ruby's stdlib in a subprocess, the same resource
  `validate-config` already used. It only affects callers that invoked that script
  directly.
- `defaults/default.yaml`: the schema is the single source of truth. The file was
  unreachable through the validated path and only a test that bypassed the CLI
  exercised it.
- `defaults_path` / `defaults_exists` from `pandoc-pdf info` (text and `--json`),
  since the file no longer exists.
- The duplicate `filters/emoji/emoji_u{2610,2611,2612}.svg` assets, byte-identical
  to `2610.svg`, `2611.svg` and `2612.svg`, unreferenced and copied into the emoji
  directory on every run.
- `scripts/__pycache__` and `.pyc` files from the release artifact.

### Tests

- The L1 suite grew from **145 assertions to 300** and stopped being a single file:
  2,365 lines became `tests/lib.sh` with the shared assertions and fixture
  helpers plus one file per area under `tests/l1/`, with `tests/run.sh`
  orchestrating them.
- New assertions pin every behaviour above: `input.order` (both values and the
  rejected one), `output.keep_merged_markdown` on success and on pandoc failure,
  `document.*` versus `pandoc.metadata_file`, `include_ballot_icons`,
  `runtime.strict` with and without the TeX engine, `metadata_file` validation,
  the schema keyword guard, the render plan, the emoji filter in headings,
  paragraphs, table cells, captions and list items, the naming rules including
  accents and path traversal, and the three update diagnostics.
- The two Python/Ruby parity tests were retired together with the duplicate
  renderer and replaced by a structural pin: `render-native.rb` must not come
  back.
- `tests/integration/*` templates no longer carry their own copy of the template,
  so L2 exercises the real one; they also load `graphicx` and `hyperref`.
- Test-only YAML double (`tests/fixtures/yaml_shim/yaml.py`) so the Python
  renderer path can be exercised on machines without PyYAML installed.

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
    SARIF on `push` to the default branch.

---

## [1.1.1] - released

### Fixed

- `Security` workflow adjusted to avoid permission failures on pull requests
  (`Resource not accessible by integration`):
  - SARIF is published only on `push` to the default branch;
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
