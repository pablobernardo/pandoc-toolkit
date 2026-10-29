# Pandoc PDF Toolkit

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
toolkit expects them. System dependencies are in [the installation guide](docs/install.md).

## First render and main commands

Start with a `pdf.config.yaml` for your repository; the
[examples](docs/usage.md#examples-in-this-repository) show complete configurations
and the documents they render.

```bash
pandoc-pdf doctor                              # check the local toolchain
pandoc-pdf validate-config -c pdf.config.yaml  # validate a configuration
pandoc-pdf render -c pdf.config.yaml           # produce the PDF
```

`pandoc-pdf --help` lists every command; [the usage guide](docs/usage.md)
documents them, including CI integration for consuming repositories.

## Documentation

The full index, with one line per document and the question it answers, is
[`docs/README.md`](docs/README.md). The three starting points are
[`docs/install.md`](docs/install.md),
[`docs/usage.md`](docs/usage.md) and
[`docs/architecture.md`](docs/architecture.md).

## Contributing

Setup, tests, commit conventions and the rules that keep this toolkit reusable are
in [CONTRIBUTING.md](CONTRIBUTING.md).

## Built with Gentle AI

The 2.0.0 refactor of this toolkit was built with [Gentle AI](https://github.com/Gentleman-Programming/gentle-ai#built-with-gentle-ai).

<a href="https://github.com/Gentleman-Programming/gentle-ai">
  <img width="220" src="https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/docs/assets/brand/built-with-gentle-ai.png" alt="Built with Gentle-AI" />
</a>

This acknowledgement does not imply official affiliation or endorsement by Gentle AI, Gentle Shell or Pi.

## License

MIT. Releases up to 1.1.3 were published under Apache 2.0; see `CHANGELOG.md`.

## Author

Pablo Bernardo — https://github.com/pablobernardo
