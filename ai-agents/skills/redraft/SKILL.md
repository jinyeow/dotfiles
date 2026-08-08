---
name: redraft
description: Scrap the current fix and redo it properly, using everything learned while building the mediocre version. Use when the user says the current fix is a hack/patch/band-aid and wants it redone elegantly.
disable-model-invocation: true
---

The current fix works but was arrived at by patching, not designing — it earned its bugs and edge cases the hard way. Throw it away and redesign, carrying only the *knowledge*, not the code.

## Process

1. Before touching anything, write down what the mediocre version taught you: every edge case it hit, every wrong assumption it corrected, every constraint discovered mid-fix. This is the payoff for the throwaway work — don't skip it.

2. State what's actually wrong with the current version — not "it's ugly" but the concrete cost: duplicated logic, a special case that should be the general case, a fix bolted onto the wrong layer, a seam in the wrong place. If nothing concrete is wrong, say so — a rewrite isn't automatically owed just because the user asked; a hack that's simple, contained, and correct may already be the right shape.

3. Design the version you'd write if you'd known all of this from the start. Reuse the existing seam if one already fits; only introduce a new one if the old fix was patched in at the wrong layer.

4. Discard the old implementation rather than editing it into shape — build the new one clean, then confirm it covers every edge case captured in step 1.

5. Run the existing tests (and the reproduction case for the original bug, if one exists) against the new version before calling it done.
