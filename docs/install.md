# Installation — Skelepress

This guide makes the `skelepress` command available for people, CI and coding agents.

## Version 3.0.0 is a clean break

There is no compatibility upgrade or migration path from earlier versions.
Remove the previous installation and its settings manually, then install
Skelepress cleanly. The earlier updater cannot consume the new release asset
names. Installers do not detect, adopt or modify the previous managed root.
Only `SKELEPRESS_*` environment variables and the new locale paths are read;
there are no aliases, command shims or fallback configuration loaders.

Rendering and validation still require `-c` / `--config`. The conventional
filename is `skelepress.config.yaml`; an explicitly supplied path may have any
filename. Bookkit generates only the conventional filename.

## Quick install from a release (recommended for end users)

Without cloning the repository:

```bash
curl -fsSL https://raw.githubusercontent.com/pablobernardo/skelepress/main/scripts/delivery/install.sh | bash
```

This installs into the managed layout:

- `~/.local/share/skelepress/versions/<tag>`
- `~/.local/share/skelepress/current`
- `~/.local/bin/skelepress`

An installed version carries only what it runs: the CLI, `scripts/runtime`, the
shipped templates, the schemas and catalogs, and the `bookkit` tool. The
repository's own tooling (`scripts/dev` for the documentation and catalog
checks, `scripts/delivery` for building and installing) is not installed.

## Optional agent skill

To guide an agent from **existing Markdown** to a reviewed PDF, run this from the
consuming repository after reviewing the [skill instructions](https://github.com/pablobernardo/skelepress/blob/main/skills/skelepress-documentation/SKILL.md):

```bash
npx skills add pablobernardo/skelepress \
  --skill skelepress-documentation
```

The installer lets you select target agents interactively or uses autodetection
where applicable; a menu is not guaranteed in every environment. Add
`--agent <name>` only to select a target explicitly, or `--global` for user-wide
installation instead of the project-local default. Review the destination before
confirming. Node/npm are needed only for this optional installer, not for the
toolkit runtime. Installing the skill does **not** install `skelepress`, Pandoc,
TeX or Mermaid dependencies.

Start or reload your agent in the consumer repository and activate the skill using
that agent's supported mechanism, supplying the sources, reading order and desired
PDF location. For example, Pi supports `/skill:skelepress-documentation`; Gentle
Shell uses Pi's project skill discovery. Their global homes may differ, so prefer
project scope when sharing between them. These are verification targets, not a
restriction on agents supporting the Agent Skills format.

The skill uses `validate-config`, `doctor` and `render`, preserves existing content
and disabled filters, and reports PDF warnings and any missing visual proof. It
does not author missing documentation or fix the toolkit's known font limitations.

## Development installation (from the repo)

From the repository root:

```bash
make bootstrap
```

This command runs `scripts/delivery/bootstrap.sh`, which:

- detects the operating system,
- detects a compatible Linux package manager (`apt-get`, `dnf`, `yum`, `pacman`, `zypper`, `apk`),
- installs common dependencies (macOS/Linux, where possible),
- ensures a YAML parser is available (PyYAML or Ruby YAML),
- creates the `skelepress` symlink in `~/.local/bin`,
- runs `doctor` to verify the environment.

Note: critical dependency versions are managed in `docs/dependency-policy.md`.

Useful options:

```bash
make bootstrap-dry                       # shows actions without running them
make bootstrap-yes                       # non-interactive mode
make bootstrap-ci                        # CI mode (--yes --skip-link)
bash scripts/delivery/bootstrap.sh --no-install   # only verifies dependencies + symlink
bash scripts/delivery/bootstrap.sh --yes          # non-interactive equivalent
bash scripts/delivery/bootstrap.sh --ci           # CI equivalent
```

## Install from a local repository into the managed layout

Once the repo is cloned, you can install it into the same layout used by `install-release` (so that `update` works correctly) and additionally create the development symlink:

```bash
make install-local          # versions/v<version> + current + bin, exactly like a release
make install-local-dev      # versions/v<version>-dev + skelepress-dev -> bin/skelepress of the repo
```

A local install carries **the released payload**, from the same list the packager
uses, so it exercises what an installation actually receives: no `examples/`, no
`Makefile` and no repository tooling.

The directory is named after the release tag, `versions/v<version>`, which is
what the network installer writes. A development install gets its own
`versions/v<version>-dev` and **does not touch `current`**: the stable binary
keeps pointing where it pointed, and `skelepress-dev` is the separate
development entrypoint.

### Isolated installations for acceptance runs

Three variables decide where an installation lives, and they are independent:

- `SKELEPRESS_INSTALL_HOME` — managed root used by `scripts/delivery/install.sh` and `make install-local`, and honoured by `skelepress update` as a fallback.
- `SKELEPRESS_INSTALL_DIR` — directory that receives the entrypoint symlink, also honoured by `skelepress update` (it beats the `skelepress` found on `PATH`).
- `SKELEPRESS_UPDATE_HOME` — managed root used by `skelepress update`; it wins over `SKELEPRESS_INSTALL_HOME`.

`skelepress update` reads the same declarations the installers write, so it updates the installation it finds instead of writing to the default locations behind your back. `skelepress update --install-dir <path>` only moves the symlink; the managed root still comes from `SKELEPRESS_UPDATE_HOME` or `SKELEPRESS_INSTALL_HOME` (default `~/.local/share/skelepress`), so an isolated acceptance run needs both declared.

## System dependencies

Install at least:

- `pandoc`
- a TeX engine (`xelatex` or `lualatex` or `pdflatex`)
- `python3` — **3.9 or newer**; `skelepress doctor` refuses an older
  interpreter, naming the version it found and the required minimum
  (`docs/dependency-policy.md` records why 3.9 is the line)
- YAML parser: **PyYAML** for Python or **Ruby's stdlib YAML**
- `curl`
- `mmdc` (Mermaid CLI)
- Optional: **GNU FreeSerif**, so the six ballot/warning symbols (`☐ ☑ ☒ ✅ ❌ ⚠`)
  appear in PDF prose and inline code. A full TeX Live/MacTeX install already
  ships it; on Debian/Ubuntu: `sudo apt install fonts-freefont-ttf`. Without it
  (or without the `newunicodechar` package, guarded the same way and shipped by
  standard TeX distributions), rendering still succeeds and those glyphs are
  dropped with the usual Missing-character warnings; see
  `docs/dependency-policy.md`.

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
- After upgrading `mermaid-cli`, its Puppeteer may expect a different browser revision. Repeat the browser install if `skelepress doctor` complains.

`skelepress doctor` verifies this by rendering a test diagram, so the failure surfaces before a long render. `make bootstrap` does the same check at the end of an install: if `mermaid-cli` is present but cannot render, it prints both fixes above. It never downloads a browser on its own, because a silent 200 MB download is not something an installer should decide for you.

Option A (recommended) — install PyYAML:

```bash
python3 -m pip install pyyaml
```

Option B — use Ruby with stdlib YAML (it ships by default on macOS).

## Put the CLI on PATH (development)

> **For end users:** use `make install-local`, described in 'Install from a local repository', instead of this section.

This section describes installation for **local development** (from the cloned repo):

```bash
mkdir -p "$HOME/.local/bin"
ln -sf "$(pwd)/bin/skelepress" "$HOME/.local/bin/skelepress"
```

For active development, also create the development symlink that avoids collisions with the stable installation:

```bash
ln -sfn "$(pwd)/bin/skelepress" ~/.local/bin/skelepress-dev
```

Add to PATH (if it is not there):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Persistence (zsh):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
```

## Verify the installation

```bash
skelepress doctor
```

If it returns `Doctor OK`, the environment is ready.

## Try it with the example config

```bash
skelepress validate-config -c examples/ohmyfake/skelepress.config.yaml
```
