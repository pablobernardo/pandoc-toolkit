# Dependency policy

## Objective

Reduce supply-chain risk by pinning critical runtime versions and keeping an explicit update cadence.

## Pinned critical dependencies

- `@mermaid-js/mermaid-cli@10.9.1`
  - Usage: `scripts/bootstrap.sh`, L3 workflow in `.github/workflows/ci.yml`.
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
