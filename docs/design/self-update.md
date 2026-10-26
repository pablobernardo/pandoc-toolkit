# Design — Self-update from GitHub Releases (Linux/macOS)

> Design record for the self-update feature, which shipped in 1.2.0. Current
> behaviour is documented in `docs/usage.md`; this file keeps the reasoning
> behind the shipped contract, not instructions.

## 1) Objective

Add an update capability to the `pandoc-pdf` CLI from GitHub Releases, focused on:

- a simple user experience,
- supply-chain security,
- compatibility with current installations of the toolkit.

Initial scope: **Linux + macOS**.

---

## 2) Scope and non-scope

### In scope (v1)

- `update --check` to query whether a new version exists.
- `update` to install the latest stable version.
- `update --to <tag>` to install a specific version.
- Integrity verification via SHA256 checksum.
- Safe replacement of the binary with backup/rollback.

### Out of scope (v1)

- Native Windows support.
- Multiple channels (`beta`, `rc`, `nightly`).
- Advanced cryptographic signing (Sigstore/GPG) in the first iteration.

---

## 3) Proposed CLI contract

```bash
pandoc-pdf update --check
pandoc-pdf update
pandoc-pdf update --to vX.Y.Z
```

Recommended flags:

- `--yes`: non-interactive mode (no confirmations).
- `--dry-run`: shows actions without modifying the system.
- `--install-dir <path>`: overrides the installation destination.

### Exit codes

- `0`: successful operation.
- `1`: operational error (network, release parsing, permissions, checksum, unsupported platform).

---

## 4) Artifact model in a release

Each tag `vX.Y.Z` must publish:

- `pandoc-pdf_darwin_amd64.tar.gz`
- `pandoc-pdf_darwin_arm64.tar.gz`
- `pandoc-pdf_linux_amd64.tar.gz`
- (optional v1.1) `pandoc-pdf_linux_arm64.tar.gz`
- `checksums.txt` (SHA256 of all artifacts)

Expected content inside each tarball:

- executable `pandoc-pdf`
- `VERSION` (optional, if the executable already exposes an embedded version)

---

## 5) Functional flow

### 5.1 `update --check`

1. Read the local version (`pandoc-pdf --version`).
2. Query the most recent stable release on GitHub.
3. Compare local semver vs remote.
4. Report the status (up to date / update available).

### 5.2 `update` / `update --to`

1. Resolve the target version (`latest` or explicit tag).
2. Detect `OS` and `ARCH`.
3. Select the corresponding artifact.
4. Download the artifact + `checksums.txt` to a temporary directory.
5. Verify the SHA256 of the artifact.
6. Extract and validate that `pandoc-pdf` is executable.
7. Run a quick verification of the artifact (`--version`).
8. Create a backup of the current binary.
9. Replace atomically.
10. Verify the version after installation.
11. If any final validation fails: roll back from the backup.

---

## 6) Minimum security rules

1. **Do not install if `checksums.txt` is missing.**
2. **Do not install if the checksum does not match.**
3. **Do not execute remote scripts** during the update.
4. **No implicit downgrade** (only with an explicit `--to`).
5. **Do not use prerelease channels** in v1.

---

## 7) Installation compatibility

Recommended order for the installation destination:

1. Explicit `--install-dir` (if provided).
2. Directory of the current executable (if writable).
3. Suggested fallback: `~/.local/bin`.

If there are no write permissions, the command must fail with a clear, actionable instruction.

---

## 8) Observability/UX strategy

- Clear messages per stage: resolving the release, downloading, verifying, installing, validating.
- In `--dry-run`, show the URL and target paths without writing to disk.
- On error, show the cause and the next step (retry, permissions, network, missing tag).

---

## 9) Validation plan (tests)

Minimum cases:

- `update --check` (without an update and with an update available).
- Unsupported platform.
- `--to` with a nonexistent tag.
- Missing or invalid checksum.
- Corrupt artifact.
- Insufficient permissions at the destination.
- Successful rollback after a post-installation failure.

---

## 10) Recommended implementation phases

### Phase 1 — Safe discovery

- Deliver `update --check`.
- Define the release artifact contract.

### Phase 2 — Safe installation

- Deliver `update` and `update --to`.
- Enable checksum + backup + rollback.

### Phase 3 — Hardening

- Add telemetry/log improvements.
- Evaluate cryptographic signing of artifacts.

---

## 11) Tradeoffs of the Linux/macOS-first decision

### Advantages

- Lower initial complexity.
- Faster delivery.
- Aligned with the current support of the toolkit.

### Cost

- Windows is deferred to a later iteration.

Recommended decision: **proceed with Linux/macOS first** and design the extension to Windows without breaking the CLI contract.
