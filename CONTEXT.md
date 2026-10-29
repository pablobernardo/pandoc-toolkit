# Operational context (current)

> This file reflects changing state. Stable rules live in `AGENTS.md`, and every
> document is indexed in `docs/README.md`. Correct a statement here rather than
> appending to it: a section that grows is a section nobody trusts.

## Current state

- **Stable CLI with native render by default.** The entry point is
  `bin/pandoc-pdf`; the command surface is what `--help` prints and
  `docs/usage.md` documents.
- **The verification is `make gate`**: suite, catalogs, documentation references
  and plan conformance. How many assertions that is belongs to the run, not to
  this file.
- **Published release**: [v2.0.0](https://github.com/pablobernardo/pandoc-toolkit/releases/tag/v2.0.0)
  was published on 2026-10-27 at commit `3cc751a`. `VERSION` remains **2.0.0**;
  changes since that tag are unreleased, not a replacement for published assets.
- **Latest implementation baseline**: `main` at `4a62292`, with PR #82 merged.
  L1 CI passed on macOS and Ubuntu, and Security passed; L2/L3 were skipped.
  The CLI-driven heading-pagination check and `make gate` also passed in the
  preceding verification. These are recorded results, not checks rerun by this
  documentation correction; assertion counts belong to their run output.
- The configuration contract remains **1**. The optional-setting validation and
  layout fixes need no consumer migration; a patch release is a separate
  maintainer decision, not yet authorised by this documentation update.
- Earlier local verification used Ruby YAML because that environment lacked
  PyYAML. That is historical evidence, not a claim about the current environment
  or coverage of both parser paths (`docs/dependency-policy.md`).

## Where each area is described

Not restated here: a second copy of a description is a second place to be wrong.

| Area | Described in |
| --- | --- |
| CLI surface and behaviour | `docs/usage.md`; the command list is `--help` |
| The contract and its rules | 'Configuration contract' in `docs/architecture.md`, and the schema itself |
| Numbered decisions D1 to D12 | 'Decision record' in `docs/architecture.md` |
| Render pipeline and the plan | 'Toolkit structure' and 'Render pipeline' in `docs/architecture.md` |
| Security posture and CI gates | `docs/releasing.md`, `.github/SECURITY.md` |
| Suite and CI levels | `CONTRIBUTING.md` |
| Pinned dependencies and blind spots | `docs/dependency-policy.md` |
| Internationalisation | `docs/i18n.md` |
| How a version is cut | `docs/releasing.md` |

## Native review (RDD) — keep candidates focused

Earlier review captures failed, including a small candidate; they do not
establish a deterministic line-count cutoff or prove a universal provider limit.
The final **165-diff-line** candidate passed readability and reliability review,
and that result was acknowledged.

Keep review scope focused and judge capture quality from the observed result,
not a presumed size threshold. Review approval does not replace tests, and a
failed capture is not a reason to skip verification.

## Binary migration (Go) — pending decision

State: **no migration now**. Windows is not a current requirement and the toolkit
is consumed on Linux and macOS. The door is explicitly left open.

What the door consists of:

1. `render --dry-run --json`: done, and the plan shape is frozen (D6).
2. A conformance suite over that plan: `scripts/check-plan-conformance.py`
   compares four recorded cases without reading renderer code. `PANDOC_PDF_BIN`
   selects any implementation (today's Python, a future Go one), and `--update`
   refreshes expectations. The L1 suite checks conformance and failure diagnostics.

Migration triggers (any one of them):

- Windows becomes a real requirement.
- A target consumer cannot provide `python3` + PyYAML.
- Signed single-file artifacts are needed for the supply chain.
- Bash updater defects cost more than a rewrite.

## Known follow-ups

1. **Missing Unicode glyphs (#83)**: font coverage remains unresolved;
   implementation has not begun. The layout fixes do not address it.
2. **Figures and custom Lua filters (#64)**: open work, not implemented by the
   current layout fixes.
3. **Artifact signing** (Sigstore/GPG) for release artifacts.

## Risks worth keeping on the page

- Environment differences (TeX, Mermaid, Chromium) between a local run and full
  integration execution, which is why L2 and L3 stay manual.
- Publication depends on GitHub Releases, which is also what the updater
  consumes.
