# Appendix

Terms used with a specific meaning, then the short theory behind the design.

## Glossary

| Term | Meaning in this manual |
| --- | --- |
| Claim | A sentence presented to the machine for assessment |
| Check | An observation that could disagree with the claim |
| Verdict | The machine's statement about the evidence, never about truth |
| Scope | The part of the world a check would have to look at |
| Settle | Run the named check and record what it showed |

## Theory, in one page

A claim is checkable when you can describe an observation that would make you
abandon it. Everything else is rhetoric wearing the clothes of a hypothesis. The
machine implements that definition and nothing more:

- It reads structure, not meaning, because structure is what can be checked
  mechanically without pretending to understand.
- It refuses to rank, because ranking requires a baseline the machine does not
  have and should not invent.
- It names one check, not a list, because a list is an invitation to pick the
  cheapest.

### Why one check

A claim settled by any of five observations is a claim nobody will settle. The
machine names the smallest check that would do, and if the operator runs it, the
verdict is reproducible by anyone else who owns a unit.

#### The failure mode we are avoiding

An appliance that produces a number where a sentence was expected becomes the
authority it was built to replace. Every refusal in this manual exists to make
that failure impossible rather than merely discouraged.

## Colophon

This manual, its diagrams, and the machine it describes are fictional. The text is
original and released under CC0, the diagrams are rendered from the Markdown
sources, and the document you are reading was produced from a configuration
example in the same repository.[^2]

[^2]: Nothing in this appendix describes a real device. The instructions are
    internally consistent, which is the most that any fictional appliance can
    honestly promise.
