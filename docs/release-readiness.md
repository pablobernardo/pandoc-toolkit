# Release Readiness — Security

Reference checklist for deciding whether the toolkit is ready to publish a
version.

## Current state (unreleased 1.2.0)

- `VERSION` is **1.2.0** and there is **no tag yet**: the release is
  deliberately postponed by maintainer decision (creating the tag triggers
  `release.yml`, whose CI path is not currently exercised).
- Latest published tag: `v1.1.3`.

## Changes since 1.1.2

- The security workflow (`.github/workflows/security.yml`) now runs Semgrep
  from a **pinned container image** (`semgrep/semgrep:1.86.0`) instead of
  `pip install`: the pip path broke on every runner bump (Python 3.14 has no
  pydantic-core wheel, and setuptools 81+ dropped the `pkg_resources` that
  semgrep's opentelemetry dependency imports).
- Gitleaks also runs from a pinned container image
  (`ghcr.io/gitleaks/gitleaks:v8.24.2`).
- CI workflows use pinned `actions/checkout@v7`, and SARIF uploads use
  `github/codeql-action/upload-sarif@v4`.

## Approved governance decisions

- **Dual versioning**: `VERSION` (toolkit semver) + `pdf.config.yaml -> version`
  (contract).
- **`runtime.strict` defaults** to `true`.
- **Error policy**: fail-fast by default, controlled degradation only on
  non-critical paths.

### Minimum security criteria (blocking)

- [x] **Command input sanitised** in `runtime.required_commands`.
- [x] **No shell with unsafe interpolation** for command detection.
- [x] **Safe YAML loading** in Ruby paths (`YAML.safe_load`).
- [x] **Security regression tests** added and green.
- [x] **Security policy published** (`.github/SECURITY.md`).
- [x] **Trust model documented** (trusted configs only).

Result: **fulfilled for the 1.0.0 cut-off** (historical record; see also the
1.2.0 changes above).

### Recommended hardening (non-blocking)

- [x] Define `permissions: contents: read` in GitHub Actions workflows.
- [x] Pin versions of critical dependencies in bootstrap/CI (for example
      `@mermaid-js/mermaid-cli`).
- [x] Add update automation (`.github/dependabot.yml`).
- [x] Add basic secret scanning/SAST in CI.
- [x] Publish SARIF reports to GitHub Security for SAST/secrets.
- [x] Define severity threshold and failure policy in the security CI
      (`scripts/enforce-security-thresholds.py`; error and warning thresholds
      set to 0 in `security.yml`).

Current operating policy:

- SARIF upload is controlled by a repository variable: `ENABLE_SARIF_UPLOAD`.
- If `ENABLE_SARIF_UPLOAD=true`, on `push` to `main`/`master` SARIF reports
  (Semgrep + Gitleaks) are uploaded to GitHub Security.
- On `pull_request`, scans and thresholds run without SARIF upload.
- If Code Scanning is not enabled, leaving `ENABLE_SARIF_UPLOAD` disabled
  avoids workflow failures.

### Updater (`pandoc-pdf update`) — operational status

- [x] Artifact download with SHA256 verification.
- [x] Version-managed installation with a `current` pointer.
- [x] Post-installation validation of the expected version.
- [x] Robust rollback to the previous state when final validation fails.
- [x] Optional operational logging (`PANDOC_PDF_UPDATE_LOG_FILE`,
      `PANDOC_PDF_UPDATE_VERBOSE`).

### L3 integration (follow-up)

- [x] L3 fixture with real Mermaid (`tests/integration/l3-mermaid-project/`).
- [x] L3 CI validation of Mermaid PNG output.

## Decision criteria

- If all blocking criteria are green: an initial version can be published.
- If the non-blocking ones are also completed: a more robust release for
  enterprise adoption.
