# Pandoc PDF Toolkit

![CI](https://img.shields.io/badge/CI-configured-blue)
[![CI](https://github.com/pablobernardo/pandoc-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/pablobernardo/pandoc-toolkit/actions/workflows/ci.yml)

Agnostic toolkit for generating PDFs with Pandoc via a CLI (`pandoc-pdf`) using declarative configuration per consumer repository (`pdf.config.yaml`).

## Main commands

```bash
pandoc-pdf doctor                              # check the local toolchain
pandoc-pdf validate-config -c pdf.config.yaml  # validate a configuration
pandoc-pdf render -c pdf.config.yaml           # produce the PDF
```

`pandoc-pdf --help` lists every command; `docs/usage.md` documents them.

## Quick onboarding

```bash
make bootstrap
```

Install from a local repository into the managed layout (for development with a working `update`):

```bash
make install-local
make install-local-dev   # + symlink pandoc-pdf-dev -> repo
```

Stable installation from the latest release (no cloning):

```bash
make install-release
```

Optional (no changes are executed):

```bash
make bootstrap-dry
# non-interactive mode
make bootstrap-yes
# CI mode (non-interactive, no symlink)
make bootstrap-ci
```

If you clone the repository, create the `pandoc-pdf-dev` symlink so that
updates do not overwrite it:
```bash
ln -sfn <path_to_the_repo>/bin/pandoc-pdf ~/.local/bin/pandoc-pdf-dev
```

## CI

- Main workflow: `.github/workflows/ci.yml`
- Current levels:
  - **L1**: `tests/run.sh` on a macOS/Linux matrix (PR/push).
  - **L2**: semi-real integration (manual, `workflow_dispatch`).
  - **L3**: full integration with Mermaid CLI (manual or scheduled).

### Manual execution (workflow_dispatch)

From **Actions → CI → Run workflow** you can trigger:

- `run_render_integration=true` to run **L2**.
- `run_render_full=true` to run **L3**.

#### From the GitHub UI
1. Go to **Actions** → **CI**.
2. Click **Run workflow**.
3. Enable the input you need (`run_render_integration` or `run_render_full`).
4. Run it.

#### From the `gh` CLI

```bash
gh workflow run ci.yml -f run_render_integration=true
# or
gh workflow run ci.yml -f run_render_full=true
```

Watching the run:

```bash
gh run list --workflow ci.yml
gh run view --log
```

## Documentation

The full index, with one line per document and the question it answers, is
[`docs/README.md`](docs/README.md). The three starting points are
[`docs/install.md`](docs/install.md),
[`docs/usage.md`](docs/usage.md) and
[`docs/architecture.md`](docs/architecture.md).

## Contributing

Setup, tests, commit conventions and the rules that keep this toolkit reusable are
in `CONTRIBUTING.md`.

## Author

Pablo Bernardo — https://github.com/pablobernardo
