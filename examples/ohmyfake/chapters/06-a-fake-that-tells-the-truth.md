# A Fake That Tells the Truth

You are reading a fake.

These six chapters are original text written to be published by a PDF toolkit,
about a fictional field guide that does not exist. The table of contents is
generated, the diagrams are rendered by a converter, and the whole thing exists
so that a build can fail loudly if any of those steps stops working. The cover
page is decoration. The value is that a broken pipeline produces an obviously
broken document instead of a quiet one.

That is the good kind of fake: one whose purpose is to expose the machinery
around it. Not a forgery, which hides its origin, but a control sample — a known
quantity you can compare against.

Which brings the argument back to where it started. Fakes are not a moral
category; they are a design decision with a stated purpose or an unstated one.
Mock objects, synthetic datasets, generated voices, imitation models: every one
of them is fine when the purpose is legible and the resemblance is honestly
scoped, and every one of them is dangerous when the resemblance is the only
thing anyone checks.

- [x] The purpose of the fake is written down
- [x] The resemblance is scoped to what you actually claim
- [ ] Someone outside the team can verify the origin 🧪
- [ ] The fake is regenerated as reality moves

The last two boxes are the ones that get left unticked in production, and they
are the only two that matter once the system has been running for a year.

## A Visible Compatibility Check 🔍

A useful fixture makes its signals visible, not merely available in the
configuration. The 🧪 marks a synthetic sample; the 🔍 asks the reader to inspect
its origin. Both should remain recognisable beside ordinary prose.

- 🧪 Keep the sample small enough to repeat.
- 🔍 Check the evidence rather than trusting the resemblance.

| Check | Signal | What to inspect |
|-------|--------|-----------------|
| Synthetic sample | 🧪 | The stated purpose matches the sample. |
| Origin review | 🔍 | Someone else can follow the evidence. |

The same two signals appear in a heading, a paragraph, a list and a table. That
is a visible compatibility sample, not a promise that every Unicode character
works in every font or that every emoji sequence is supported.

```mermaid
flowchart LR
    subgraph Honest["Honest fake"]
        A1[Stated purpose] --> A2[Scoped claim]
        A2 --> A3[Verifiable origin]
    end
    subgraph Suspicious["Something else"]
        B1[Unstated purpose] --> B2[Broad resemblance]
        B2 --> B3[Plausible artifact]
    end
    Honest -->|survives scrutiny| R[Useful]
    Suspicious -->|looks fine until it doesn't| S[Expensive]
```

Thank you for reading the fixture. It is, as promised, entirely fake — and one
hundred percent accurate about the machinery that produced it. 🔍
