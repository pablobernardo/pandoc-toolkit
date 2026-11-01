# Dependency policy

## Objective

Reduce supply-chain risk by pinning critical runtime versions and keeping an explicit update cadence.

## Pandoc and TeX: what CI actually runs

Neither is pinned by this repository: `scripts/bootstrap.sh` and CI install
whatever the distribution provides, which lags the current release. That has a
consequence worth stating plainly: **CI can be green while the toolkit is broken
for anyone on a current Pandoc.**

Measured: Pandoc 3.2 and later emit `\pandocbounded` when an image is bounded,
and a template that does not define it dies with `! Undefined control sequence`.
An older distribution package in CI did not emit the macro and therefore missed
the failure. That historical gap let the integration fixtures ship a template
that failed for a year of releases; it is not a claim that today's runner still
uses that older Pandoc.

Two things hold the line: the toolkit template defines `\pandocbounded`, and
`tests/l1/render.sh` fails if that definition disappears. If you change the
template, render a document with an image on a current Pandoc before trusting CI.

### CI rendering prerequisites

Both L2 and L3 install `texlive-latex-extra` and its dependencies for the
template's non-base styles (including `ulem`, `fvextra` and `mdframed`),
`texlive-fonts-recommended` for font metrics such as Zapf Dingbats (`pzdr.tfm`),
and `librsvg2-bin` for `rsvg-convert`. Both jobs check every package declared by
`templates/default.tex` with `kpsewhich` before rendering. The enabled-filter
fixture contains SVG images; Pandoc needs the converter to embed them in PDF.
These are distribution-provided packages, not new version pins.

L3 uses Google Chrome already provided by the hosted Ubuntu image, discovered
with `command -v google-chrome`; it does not install or force a Chromium Snap.
It checks the executable and the installed Mermaid HTML entry point before
running the existing integration script. Normal browser sandbox settings and
the Mermaid CLI pin are unchanged; no browser is installed on a contributor's
machine. L1 checks the declarations; only the actual L2/L3 runs establish that
the Ubuntu environment works.

Ordinary PR/push CI runs L1. L2 requires the manual
`run_render_integration=true` input; L3 runs on schedule or with
`run_render_full=true`. A green run with L2/L3 skipped is not render-integration
evidence. Release preparation must explicitly request and inspect both jobs.

### Optional PDF symbol font (GNU FreeSerif)

The template's default prose and mono faces do not contain the six ballot and
warning symbols of #83 (`☐ ☑ ☒ ✅ ❌ ⚠`). The template maps exactly those glyphs,
and only those glyphs, to GNU FreeSerif when the font exists (D14 in
`docs/architecture.md`). This font is an **optional** dependency: nothing in the
toolkit, `bootstrap.sh` or CI installs or downloads it.

Where it comes from:

| Source | Lookup |
| --- | --- |
| A full TeX Live / MacTeX install (ships `gnu-freefont`) | file name, `FreeSerif.ttf`, through the normal TeX file search |
| Debian/Ubuntu package `fonts-freefont-ttf` | family name, `FreeSerif`, through fontconfig/luaotfload |

Neither `texlive-fonts-recommended` nor any CI job decides this: a distribution
without the font still renders, with the previous behavior and the
Missing-character warnings retained. Minimal CI may exercise that degradation
instead of installing the font. The template maps through the `newunicodechar`
package, guarded together with the font: it ships with every standard TeX
distribution, and a TeX installation without it degrades the same way instead
of failing the render.

Supported engines for the mapping are XeLaTeX and LuaLaTeX, the branches that
already use fontspec. pdfLaTeX keeps its historical behavior, degraded
appearance included.

## EPUBCheck: acceptance, not a runtime dependency

EPUBCheck is the W3C conformance checker for EPUB publications. It is the only
authoritative validator for the standard, and it is written in Java: there is no
official non-Java equivalent.

It is **never** a runtime requirement. A consumer that only wants to produce an
EPUB must not install a JVM, so `epubcheck` is not part of
`runtime.required_commands` and `doctor` never asks for it. The same reasoning
that keeps Chrome and the Mermaid CLI out of a contributor's machine applies
here: it is installed where a publication is accepted, not where one is
authored.

Tested version: **5.4.0**. Any recent 5.x is expected to work; the release checks
below record what was actually run.

### Installing it

With a JDK already on the machine, use the official release and do not duplicate
the JVM:

```bash
# ~/.local is a convention, not a requirement
mkdir -p ~/.local/lib ~/.local/bin
curl -LO https://github.com/w3c/epubcheck/releases/download/v5.4.0/epubcheck-5.4.0.zip
unzip -q epubcheck-5.4.0.zip -d ~/.local/lib
printf '#!/bin/sh\nexec java -jar "%s/.local/lib/epubcheck-5.4.0/epubcheck.jar" "$@"\n' "$HOME" > ~/.local/bin/epubcheck
chmod +x ~/.local/bin/epubcheck
```

Without a JDK, Homebrew installs one for you: `brew install epubcheck`. Be aware
that the formula declares `openjdk` as a required dependency, so on a machine
that already has a JDK it installs a second one.

### Running it

```bash
make epubcheck FILE=examples/.output/test/project-technical-documentation-20261101.epub
```

Exit codes: `0` no errors, `1` errors found, `2` fatal. **Errors fail, warnings
are reported.** Add `--failonwarnings` only after the warnings have been read
once; today they include accessibility metadata this toolkit does not emit.

Never send a consumer's publication to an online validator. Validation runs
locally or in CI, and the file does not leave the machine.

### Where CI pins it

`.github/workflows/ci.yml` has a manual **EPUB acceptance** job that installs
EPUBCheck 5.4.0 and validates every publication the examples produce. It runs
only on `workflow_dispatch` with `run_epub_acceptance: true`, so it is the single
place where the version lives: a pull request never pays for it, and two
maintainers never validate with different versions.

### Why it is not part of `make gate`

`make gate` runs on every pull request and must stay runnable with no extra
setup. EPUBCheck validates a *finished* publication, needs a JVM, and says
nothing in a pull request that the dependency-free structural checks in
`tests/l1/epub.sh` do not already say. It belongs to release acceptance, where
the question is "is this publication conformant", not "is this diff correct".

### Current state

For the published 2.1.0 candidate (`6b45317`), the four shipped examples —
`documentation`, `manual`, `test` and `ohmyfake` — passed EPUBCheck 5.4.0 with no
errors and no warnings in [CI run 41308070176](https://github.com/pablobernardo/pandoc-toolkit/actions/runs/41308070176). The inter-chapter link defect
that `documentation` used to report no longer occurs: links between selected
chapters are rewritten to internal anchors that resolve inside the merged
publication (#94). EPUBCheck remains acceptance, not a gate: it runs only
through the manual `run_epub_acceptance` job described above.

## YAML: two parsers, one tested at a time

Configuration is read with PyYAML when available and otherwise through Ruby's
standard library in a subprocess. That is deliberate (D1), and it creates a gap
worth knowing about: **each environment exercises only one of the two paths.**

- Locally, `python3` may have no PyYAML, so the Ruby path is the one the suite
  runs. `pandoc-pdf info --json` reports which parser is active (`yaml_parser`).
- In CI the Python path is the one that runs.

The `tests/fixtures/yaml_shim/` double does not close this: it delegates to Ruby,
so comparing a run with the shim against a run without it compares Ruby with Ruby.
A real difference between the two parsers — `yes`/`no`, sexagesimal numbers,
unquoted dates, octal-looking strings — would be invisible in both environments.

What would close it: a parity test that loads every fixture through both parsers
in the same environment, run where PyYAML is installed. Until then, prefer quoted
scalars in configuration examples and fixtures.

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
4. Update `CHANGELOG.md` (Unreleased) and, when the process itself changes, `docs/releasing.md`.

## Acceptance criteria

- No functional regressions (`tests/run.sh` green).
- Security scans with no new critical findings.
- Documentation synchronized.
