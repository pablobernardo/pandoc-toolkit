# Dependency policy

## Objective

Reduce supply-chain risk by pinning critical runtime versions and keeping an explicit update cadence.

## Pinned critical dependencies

- `@mermaid-js/mermaid-cli@10.9.1`
  - Usage: `scripts/bootstrap.sh` (default of `MERMAID_CLI_VERSION`, so a run can
    override it), L3 workflow in `.github/workflows/ci.yml`.

### Why this one is a tested version, not an enforced one

`mermaid-cli` is the only dependency that can be installed outside this toolkit
(Homebrew, a system package, a project-local npm install), and the version
decides nothing by itself: what matters is whether it has a browser to render
with. Measured: the npm package at 10.9.1 downloads one, Homebrew at 12.0.0 does
not, and `mmdc` then exits non-zero with `Could not find chrome-headless-shell`.

So the contract is the smoke test, not the number:

- **10.9.1** is what the toolkit installs and what CI renders with. It is the
  version to compare against when reporting a bug.
- **Any other version is accepted** if `pandoc-pdf doctor` renders its test
  diagram. `doctor` reports the version it found, and on failure prints the two
  fixes from `docs/install.md`.
- **Do not pin a user's system-wide install from this repository.** The
  remediation for a browserless `mermaid-cli` is documented in `docs/install.md`,
  and `make bootstrap` only warns, because downloading a browser is the user's
  decision.

The pin lives in three places — `scripts/bootstrap.sh`, `.github/workflows/ci.yml`
and this list — and they must change together. `ci.yml` carries a comment
pointing here for exactly that reason.
- `pyyaml==6.0.2`
  - Usage: `scripts/bootstrap.sh` (assisted installation when the YAML parser is missing).
- `semgrep/semgrep:1.86.0` container image
  - Usage: `.github/workflows/security.yml` (pinned image instead of `pip install`, which breaks with modern setuptools).
- `ghcr.io/gitleaks/gitleaks:v8.24.2` container image
  - Usage: `.github/workflows/security.yml`.

## Update cadence

- **Monthly** review of critical dependencies.
- Extraordinary review on any relevant CVE or advisory.

## Update process

1. Update the pinned version in bootstrap/workflows.
2. Run `tests/run.sh`.
3. Run the security workflow (`security.yml`).
4. Update `CHANGELOG.md` (Unreleased) and, if applicable, `docs/release-readiness.md`.

## Acceptance criteria

- No functional regressions (`tests/run.sh` green).
- Security scans with no new critical findings.
- Documentation synchronized.
