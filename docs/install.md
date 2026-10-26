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
pandoc-pdf validate-config -c examples/pdf.config.example.yaml
```

## 7) OpenCode integration (models)

So that models use the command correctly:

1. Make sure `pandoc-pdf` is on the PATH of the environment where OpenCode runs.
2. State in the project instructions that the official flow is:
   - `pandoc-pdf doctor`
   - `pandoc-pdf validate-config -c <config>`
   - `pandoc-pdf render -c <config>`
3. Avoid invoking local legacy scripts directly from prompts.

## Note on the current state

The CLI render is **native by default** and the official entrypoint for automation is `pandoc-pdf`.
