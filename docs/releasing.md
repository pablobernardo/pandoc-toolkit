# Releasing

How a version is cut. This describes the process, not the state of the next
version: what is about to ship lives in `CHANGELOG.md`.

## Before tagging

1. **Checks green on `main`**: `make gate` (suite, catalogs, documentation
   references and plan conformance), plus the security workflow with its
   thresholds at zero. When CI cannot start, `make gate` output pasted into the
   pull request is the verification a maintainer accepts.
2. **`VERSION`** holds the version to publish.
3. **`CHANGELOG.md`** has the entry, written for the reader who upgrades.
4. **Contract change?** `pdf.config.yaml -> version` moves only for a breaking
   change of the configuration contract, with a migration section in
   `docs/migration.md`. Toolkit version and contract version are independent.
5. **Dependencies pinned**: every action uses a commit SHA, and the images and
   tool versions in `docs/dependency-policy.md` match what CI installs.

## Cutting it

```bash
git tag -a v2.0.0 -m "pandoc-pdf 2.0.0"
git push github v2.0.0
```

The tag triggers `.github/workflows/release.yml`, which:

- builds `dist/pandoc-pdf_{darwin,linux}_{amd64,arm64}.tar.gz` and
  `dist/checksums.txt` with `scripts/package-release.sh`. The artifact is bash and
  Python, so it is platform-independent: the four names are aliases of the same
  tarball and their checksums are identical by design, which is worth knowing
  before treating a matching hash as a broken build;
- creates or updates the GitHub release for that tag, with generated notes;
- fails if any expected asset is missing.

`workflow_dispatch` on the same workflow releases an existing tag, with the tag
as input.

## After publishing

1. On a machine with the previous version: `pandoc-pdf update --check`, then
   `pandoc-pdf update`, and confirm the installed version.
2. The updater downloads the asset for the platform, verifies it against
   `checksums.txt`, installs into a versioned directory behind a `current`
   pointer, and **rolls back** when the post-install version check fails.
3. If an asset is wrong, delete the release and the tag, fix, and tag again: the
   workflow creates or updates, so re-running the same tag replaces the assets.

## What CI does not exercise

`release.yml` runs only on a tag or by hand, so no pull request proves it. Run
the packaging script locally before trusting it:

```bash
./scripts/package-release.sh /tmp/dist
```

## Security gates

- `scripts/enforce-security-thresholds.py` fails the workflow at the configured
  thresholds; the current policy is zero errors and zero warnings.
- SARIF upload is controlled by the repository variable `ENABLE_SARIF_UPLOAD`.
  Enabled, findings upload on push to `main`; on `pull_request` the scans run
  without upload. Leaving it disabled is the supported state when Code Scanning
  is not enabled.
- Trust model: configuration files are trusted input. The toolkit sanitises what
  it passes to commands, never interpolates into a shell unsafely, and loads
  YAML safely.

These must keep holding, because they are what makes a published version safe:

- command input sanitised for `runtime.required_commands`;
- no unsafe shell interpolation for command detection;
- safe YAML loading on every path, including the Ruby fallback;
- security regression tests green;
- published policy in `.github/SECURITY.md`.
