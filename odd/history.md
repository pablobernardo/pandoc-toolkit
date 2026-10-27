# History of the 1.2.0 work

What was done, in what order, and what it was measured with. This is the trail, not
the reasoning: the decisions live in the `Decision record` of
`docs/architecture.md` (D1 to D12) and the user-visible changes live in
`CHANGELOG.md`. Read this when you want to know how a change was verified, or what
a slice looked like before it landed.

Each slice was a branch with its own specs, its task list and its evidence, and
each landed through a pull request. Suite counts are quoted as they were on that
branch: they are evidence about a moment, not a current metric.

## Slice 1 — Config contract alignment

Fixed what validation and packaging promised but did not do: the missing-locale
message named `--team` instead of `--project`; three emoji SVGs existed twice
byte-for-byte; `scripts/package-release.sh` packed `scripts/__pycache__` and
rebuilt the same tree four times; and `--resource-path` was joined with a hardcoded
`:` instead of the platform separator.

Evidence: suite **145** at the start, **188** and then **191** as slices landed,
L2 green. One finding earned its own note: `filters/emoji.lua` wrapped every `Str`
in a `pandoc.Span` and split words per character, so any heading became
"formatted", pandoc emitted `\texorpdfstring`, and a minimal template died with
`! Undefined control sequence` (L2 exit 43, confirmed in a clean worktree of the
default branch, so not a regression of the slice).

## Slice 2 — Retire the Ruby renderer

Two renderers meant two behaviours; the one that ran depended on which file the
entry point chose. The Ruby renderer was removed and its guarantees became
structural pins in the suite.

Evidence: **−529 / +131** lines, the 398-line renderer gone; suite **217** (222
minus the two parity tests, plus the pin that the `.rb` never comes back); L2 exit
0; the release artifact inspected to confirm no `.rb` inside.

## Slice 3 — Unify the shell i18n runtime

Two entry points had two i18n implementations with two precedence chains. Both now
use `scripts/i18n.sh`: the catalog loads once, `t` spawns no process, and the
resolution order is single.

Reasoning: D4.

## Slice 4 — Single source for configuration

`defaults/default.yaml` merged a baseline into every configuration, which is how a
key could be required by the schema and silently supplied by something else. The
file was removed; the schema is the only source.

Reasoning: D7.

## Slice 5 — Render plan JSON

`render --dry-run [--json]` prints what it would do and writes nothing, which is
what a conformance suite or a second implementation can be compared against.

Evidence: suite **191** before the slice, **210** after; L2 exit 0 with a real
render. The plan shape was then frozen: it is `plan_version: 1`, and any change to
its shape requires `plan_version: 2`.

Reasoning: D6. The conformance suite this enabled was built later, in
`tests/conformance/`.

## Slice 6 — Metadata without a mandatory side file

`pandoc.metadata_file` was required, which made five of the six `document` fields
inert in every valid configuration: the schema forced the legacy YAML file and left
the modern path unreachable. The file is optional now, and `document` gained
`language`, `titlepage` and a free-form `metadata` map.

Reasoning: D12. The file name rule changed in the same release, which is its own
migration note in `docs/migration.md`.

## What these records were good for

Two things, and both are worth keeping in mind when writing the next one:

- **The measured evidence outlives the prose.** "Suite 191 → 210" and "L2 exit 43,
  reproduced in a clean worktree" are what later told us a failure was pre-existing
  rather than caused by the change at hand.
- **A slice that fixes four things measures four things.** The alignment slice
  found the emoji filter bug only because it was looking at L2 output for an
  unrelated reason.
