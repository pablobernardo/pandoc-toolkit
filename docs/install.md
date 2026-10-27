# Installation — Pandoc PDF Toolkit

This guide gets the `pandoc-pdf` command available for humans, CI and agents (OpenCode).

## 0) Quick install from a release (recommended for end users)

Without cloning the repository:

```bash
curl -fsSL https://raw.githubusercontent.com/pablobernardo/pandoc-toolkit/main/scripts/install.sh | bash
```

This installs into the managed layout:

- `~/.local/share/pandoc-pdf/versions/<tag>`
- `~/.local/share/pandoc-pdf/current`
- `~/.local/bin/pandoc-pdf`

If the releases repository is private, export a token before installing:

```bash
export PANDOC_PDF_UPDATE_TOKEN=<your_token>
# or GH_TOKEN
```

## 1) Development installation (from the repo)

From the repository root:

```bash
make bootstrap
```

This command runs `scripts/bootstrap.sh`, which:

- detects the operating system,
- detects a compatible Linux package manager (`apt-get`, `dnf`, `yum`, `pacman`, `zypper`, `apk`),
- installs common dependencies (macOS/Linux, where possible),
- ensures a YAML parser is available (PyYAML or Ruby YAML),
- creates the `pandoc-pdf` symlink in `~/.local/bin`,
- runs `doctor` to verify the environment.

Note: critical dependency versions are managed in `docs/dependency-policy.md`.

Useful options:

```bash
make bootstrap-dry                       # shows actions without running them
make bootstrap-yes                       # non-interactive mode
make bootstrap-ci                        # CI mode (--yes --skip-link)
bash scripts/bootstrap.sh --no-install   # only verifies dependencies + symlink
bash scripts/bootstrap.sh --yes          # non-interactive equivalent
bash scripts/bootstrap.sh --ci           # CI equivalent
```

## 2) Install from a local repository into the managed layout

Once the repo is cloned, you can install it into the same layout used by `install-release` (so that `update` works correctly) and additionally create the development symlink:

```bash
make install-local          # installs into the managed layout (versions/<tag> + current + bin)
make install-local-dev      # installs into the managed layout + symlink pandoc-pdf-dev -> bin/pandoc-pdf of the repo
```

This copies the contents of the repo to `~/.local/share/pandoc-pdf/versions/<VERSION>` and creates the corresponding symlinks. With `install-local-dev`, `pandoc-pdf-dev` also becomes available, pointing at the development entrypoint `bin/pandoc-pdf` of the repo.

## 3) System dependencies

Install at least:

- `pandoc`
- a TeX engine (`xelatex` or `lualatex` or `pdflatex`)
- `python3`
- YAML parser: **PyYAML** for Python or **Ruby's stdlib YAML**
- `curl`
- `mmdc` (Mermaid CLI)

Quick reference for the Mermaid CLI:

```bash
npm i -g @mermaid-js/mermaid-cli
```

`mermaid-cli` renders through Puppeteer, which needs a Chromium it can find. Recent versions do **not** download it with the package, so a fresh install fails with `Could not find chrome-headless-shell`.

Pick **one** of these two ways. They are alternatives, not two steps:

| Way | How | When |
| --- | --- | --- |
| Let Puppeteer manage its own browser | `npx puppeteer@<same version as mermaid-cli> browsers install chrome-headless-shell` | No Chrome installed, or you want isolation from the desktop browser |
| Reuse a browser you already have | `export PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"` | Chrome or Chromium is already installed |

`npx puppeteer browsers install` without the version pin works too, but pinning it to the Puppeteer version bundled with your `mermaid-cli` guarantees the browser revision it expects.

Rules that avoid the usual breakage:

- **Do not** point `PUPPETEER_EXECUTABLE_PATH` inside `~/.cache/puppeteer`. That path encodes platform and browser revision, and the variable takes precedence over Puppeteer's own resolution, so a pinned cache path breaks after an upgrade even when the right browser is present.
- **Do not hardcode** either path in a script that runs on several machines. Export it in the shell profile, or in the CI job, where it belongs.
- Install `mermaid-cli` **one** way. Homebrew and npm can both provide `mmdc`; whichever comes first in `PATH` wins, and mixing them is how a working setup becomes "no browser" after an upgrade.
- After upgrading `mermaid-cli`, its Puppeteer may expect a different browser revision. Repeat the browser install if `pandoc-pdf doctor` complains.

`pandoc-pdf doctor` verifies this by rendering a test diagram, so the failure surfaces before a long render. `make bootstrap` does the same check at the end of an install: if `mermaid-cli` is present but cannot render, it prints both fixes above. It never downloads a browser on its own, because a silent 200 MB download is not something an installer should decide for you.

Option A (recommended) — install PyYAML:

```bash
python3 -m pip install pyyaml
```

Option B — use Ruby with stdlib YAML (it ships by default on macOS).

## 4) Put the CLI on PATH (development)

> **For end users:** use `make install-local` (section 2) instead of this section.

This section describes installation for **local development** (from the cloned repo):

```bash
mkdir -p "$HOME/.local/bin"
ln -sf "$(pwd)/bin/pandoc-pdf" "$HOME/.local/bin/pandoc-pdf"
```

For active development, also create the development symlink that avoids collisions with the stable installation:

```bash
ln -sfn "$(pwd)/bin/pandoc-pdf" ~/.local/bin/pandoc-pdf-dev
```

Add to PATH (if it is not there):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Persistence (zsh):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
```

## 5) Verify the installation

```bash
pandoc-pdf doctor
```

If it returns `Doctor OK`, the environment is ready.

## 6) Try it with the example config

```bash
pandoc-pdf validate-config -c examples/ohmyfake/pdf.config.yaml
```

## 7) OpenCode integration

Making a model use the CLI consistently is one procedure, so it lives in one
place: see *OpenCode integration* in `docs/usage.md`. The short version is that
`pandoc-pdf` must be on the `PATH` and the repository instructions must say so.
