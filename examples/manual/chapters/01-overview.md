# Overview

The Honest Machine is a desk appliance that answers one question: **is this claim
checkable, and if so, what check settles it?** It is not a fact-checker. It does
not know whether a sentence is true. It knows whether a sentence comes with
enough structure for anyone to find out.

## What it does

You give it a claim and whatever evidence you have. It returns one of four
verdicts, and the verdict is always about the *evidence*, never about the world.

- **Settleable** — the claim names a check that can be run.
- **Underdetermined** — the claim is meaningful but no check is named.
- **Unfalsifiable** — no observation could disagree with it.
- **Malformed** — it is not a claim: a question, a slogan, a shopping list.

Only the first verdict is an invitation to work. The other three are descriptions
of a dead end, which is a more useful output than a confident guess.

### What it refuses to do

The machine refuses three requests on principle, and prints the same message for
all of them:

1. Rank two claims by how likely they are to be true.
2. Judge a claim by who made it.
3. Judge a claim by how many people repeat it.

#### Why the refusals are structural

These are not settings. There is no hidden menu, no engineering mode, no firmware
update that adds them. The refusal is implemented as the absence of a code path,
because a machine that can be persuaded to guess will eventually be persuaded by
the most persistent person in the room.[^1]

[^1]: The engineering note is more precise: the verdict engine has no access to
    provenance or popularity, so those inputs cannot influence it even by
    accident.

## What you should expect from it

A short answer, a named check when one exists, and no encouragement to skip the
check. If you were hoping for a score, the second paragraph of this manual is the
closest thing to one: the machine has opinions about evidence and none about
truth.
