# Releasing

Publishing requires an explicit maintainer decision. This is a checklist, not
permission to release: proposed changes live in `CHANGELOG.md`, and checks for
the actual release candidate still need to run and be recorded.

## Before tagging

- [ ] **Checks green on the candidate**: `make gate` (suite, catalogs,
  documentation references and plan conformance), plus the security workflow
  with its thresholds at zero. Record which CI levels ran; skipped L2/L3 jobs
  are not integration evidence. If CI cannot start, record that limitation and
  provide local verification for the maintainer's decision.
- [ ] **Version and notes ready**: `VERSION` holds a new, unpublished version;
  `CHANGELOG.md` describes what upgrades change and any known limits. Corrections
  to a published release go into a new patch version, not a replacement tag.
- [ ] **Compatibility assessed**: toolkit version and configuration contract
  version are independent. A breaking contract change needs a contract version
  change and migration guidance in `docs/migration.md`; breaking CLI or default
  behaviour also requires a major toolkit version under `AGENTS.md`.
- [ ] **Dependencies pinned**: action SHAs and the images and tool versions in
  `docs/dependency-policy.md` match CI.

## Candidate acceptance checks

Use isolated temporary output and installation directories. These are checks to
perform for the release, not claims that a future candidate has passed:

- [ ] **Package contents and checksums**: run `scripts/package-release.sh` with a
  fresh temporary output directory; verify all four tarballs against
  `checksums.txt`. Inspect the archive for the executable CLI, matching `VERSION`,
  runtime scripts, schemas, templates, filters, catalogs and license; exclude
  Python bytecode caches. The four platform names are aliases of one
  platform-independent artifact, so identical hashes are intentional.
- [ ] **Clean install**: install the candidate artifact in a clean managed layout,
  confirm `pandoc-pdf --version`, and run `doctor` and `validate-config`. Follow
  `docs/install.md`; use disposable state rather than an everyday installation.
- [ ] **Upgrade**: from the previous published version, exercise the updater
  against the candidate artifact; confirm checksum verification, the installed
  version and the managed `current` pointer. Check rollback on a failed
  post-install version check. After publication, verify the real release
  download path as well.
- [ ] **Smoke rendering**: render representative examples, including highlighted
  and untagged code, inline code and heading pagination. Inspect the PDFs, not
  just the exit status. H6 remains plain text, arbitrary unbreakable content may
  overflow, and missing Unicode glyphs remain tracked in #83.
- [ ] **YAML paths where feasible**: exercise both PyYAML and the Ruby stdlib
  fallback in suitable environments. Record which ran and any gap; a run on one
  path does not establish coverage of the other.

## Tagging and publishing

The following Bash commands are illustrative, not an instruction to run them
without approval. Start at the approved commit on a clean `main`; confirm that
`github` is the intended publishing remote. Check both local and remote tags,
then derive the tag from `VERSION` rather than copying an old release number:

```bash
set -euo pipefail
test "$(git branch --show-current)" = main
test -z "$(git status --porcelain)"
version="$(< VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
tag="v${version}"
if git show-ref --verify --quiet "refs/tags/$tag"; then
  printf 'Tag already exists locally: %s\n' "$tag" >&2
  exit 1
fi
remote_tags="$(git ls-remote --tags github "refs/tags/$tag")"
test -z "$remote_tags"
```

Only after the acceptance evidence and explicit publishing approval:

```bash
git tag -a "$tag" -m "pandoc-pdf $version"
git push github "$tag"
```

The tag triggers `.github/workflows/release.yml`, which builds the four
`dist/pandoc-pdf_{darwin,linux}_{amd64,arm64}.tar.gz` assets and
`dist/checksums.txt`, creates or updates the GitHub release with generated notes,
and fails if an expected asset is missing. `workflow_dispatch` can also publish
an existing tag. A pull request does not exercise this tag/manual workflow.

## After publishing

1. Verify the release tag, notes, asset contents and checksums against the
   approved candidate.
2. In a disposable installation of the previous published version, run
   `pandoc-pdf update --check`, then `pandoc-pdf update`, and confirm the version
   and a smoke render. Also verify a clean install from the published assets.
3. Preserve published tags and assets. If a correction is needed, document it
   and publish a new patch release through the same checks and approval.

**Policy is not technical enforcement:** the workflow can update a release and
replace its assets when rerun. Do not use that capability to delete/recreate a
published tag or silently overwrite a published release.

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
