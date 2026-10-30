---
name: pandoc-pdf-documentation
description: "Trigger: render existing Markdown documentation as PDF, configure pandoc-pdf, or review a documentation PDF. Use the public toolkit CLI in a consuming repository; not general documentation authoring."
license: MIT
---

## Activation Contract

Use existing Markdown to produce a reviewed PDF with `pandoc-pdf`.
Inputs: audience, purpose, source files, reading order, output destination and
publication constraints. Outputs: declarative configuration, PDF and check report.
If source content is missing, stop and ask; do not create a competing documentation
tree or substitute general-purpose writing advice.

## Hard Rules

- Read the consumer's conventions and existing `pdf.config.yaml` before edits.
  Preserve source content, intentional configuration and disabled filters.
- Use the installed toolkit's schema and matching documentation. Configuration
  `version` is a contract version, not the toolkit release number.
- Resolve paths through `project.base_dir`; do not assume a `chapters/` layout,
  machine-specific paths or access to this skill's original toolkit checkout.
- Use only public CLI commands; never invoke private renderer helpers. Do not
  silently install dependencies, browsers or network resources.
- Do not claim universal Unicode coverage, zero overflow or clipboard fidelity.
  Commit, publish and release only with separate human authorisation.

## Decision Gates

| Condition | Action |
| --- | --- |
| Purpose, reading order or destination is unclear | Resolve that decision before changing configuration. |
| Toolkit or dependency is missing | Report it and request installation permission; link the installation guide. |
| Existing configuration is invalid | Explain the validation failure; never bypass the schema. |
| Emoji or Mermaid is disabled | Keep it disabled; report font/dependency limits instead of forcing conversion. |
| PDF cannot be visually inspected | Report the missing proof; do not call the PDF visually verified. |

## Execution Steps

1. Confirm inputs and inspect existing Markdown, configuration and repository
   instructions. Identify tables, code, figures and symbols needing PDF review.
2. Check `pandoc-pdf --version` and `pandoc-pdf --help`. Read the matching schema
   and usage documentation before creating or adjusting configuration. The public
   links below track `main`; select the installed release tag when they differ.
3. Set declarative source paths, reading order and output location. Choose cover
   metadata, document language, table of contents and filters intentionally.
   Preserve explicit metadata-file precedence and existing disabled settings.
4. Run these commands with the actual configuration path, in order. Stop on a
   failure, retain stdout/stderr and fix only within the authorised scope:

   ```bash
   pandoc-pdf validate-config -c pdf.config.yaml
   pandoc-pdf doctor -c pdf.config.yaml
   pandoc-pdf render -c pdf.config.yaml
   ```

5. Open the generated PDF, or use available page-image inspection. Check reading
   order, heading/content association, code wrapping, tables, figures when present
   and symbol visibility. Inspect render warnings, especially missing glyphs.
   An exit code of zero or extracted text alone is not visual proof.

## Output Contract

Report the PDF path, source/configuration changes, toolkit version, each command's
outcome, pages actually inspected and unresolved warnings. Separate structural
checks, successful rendering and visual observations. State unavailable checks
explicitly; do not mark the workflow complete while required proof is missing.

## References

- [Installation](https://github.com/pablobernardo/pandoc-toolkit/blob/main/docs/install.md)
- [Usage and consumer examples](https://github.com/pablobernardo/pandoc-toolkit/blob/main/docs/usage.md)
- [Configuration schema](https://github.com/pablobernardo/pandoc-toolkit/blob/main/schemas/pdf-config.schema.json)
- [Known Unicode coverage work](https://github.com/pablobernardo/pandoc-toolkit/issues/83)
