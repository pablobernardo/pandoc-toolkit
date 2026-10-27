# Pandoc PDF Toolkit

![CI](https://img.shields.io/badge/CI-configured-blue)
[![CI](https://github.com/pablobernardo/pandoc-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/pablobernardo/pandoc-toolkit/actions/workflows/ci.yml)

Agnostic toolkit for generating PDFs with Pandoc via a CLI (`pandoc-pdf`) using declarative configuration per consumer repository (`pdf.config.yaml`).

## Install

On macOS or Linux, no clone and no token:

```bash
curl -fsSL https://raw.githubusercontent.com/pablobernardo/pandoc-toolkit/main/scripts/install.sh | bash
```

It installs the latest release into `~/.local/share/pandoc-pdf/versions/<tag>` behind a
`current` pointer and links `pandoc-pdf` into `~/.local/bin`; `pandoc-pdf update`
replaces it later. Piping a script into a shell is a choice, not a requirement, so if
you would rather read it first:

```bash
curl -fsSLO https://raw.githubusercontent.com/pablobernardo/pandoc-toolkit/main/scripts/install.sh
less install.sh
bash install.sh
```

Then `pandoc-pdf doctor` checks that `pandoc`, a TeX engine and `mmdc` are where the
toolkit expects them. System dependencies are in `docs/install.md`.

## Main commands

```bash
pandoc-pdf doctor                              # check the local toolchain
pandoc-pdf validate-config -c pdf.config.yaml  # validate a configuration
pandoc-pdf render -c pdf.config.yaml           # produce the PDF
```

`pandoc-pdf --help` lists every command; `docs/usage.md` documents them.

## Work on the toolkit

For end users, `## Install` above is the whole story. For developing the toolkit
itself, clone it and:

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

## Built with Gentle AI

The 2.0.0 refactor of this toolkit is being built with [Gentle AI](https://github.com/Gentleman-Programming/gentle-ai#built-with-gentle-ai).

<a href="https://github.com/Gentleman-Programming/gentle-ai">
  <img width="220" src="https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/docs/assets/brand/built-with-gentle-ai.png" alt="Built with Gentle-AI" />
</a>

This acknowledgement does not imply official affiliation or endorsement by Gentle AI, Gentle Shell or Pi.

## License

MIT. Releases up to 1.1.3 were published under Apache 2.0; see `CHANGELOG.md`.

## Author

Pablo Bernardo — https://github.com/pablobernardo
