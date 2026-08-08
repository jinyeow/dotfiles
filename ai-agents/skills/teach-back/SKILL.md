---
name: teach-back
description: Grill the user until they can explain the current diff clearly to a junior engineer and defend it to a senior engineer. Use when the user wants to verify they actually understand a change, not just that it works.
disable-model-invocation: true
---

The bar isn't "does the code work" — it's "can the user explain it." Grill them until both explanations hold up; don't accept a recitation of the diff as understanding.

## Process

1. Read the full diff. Identify its distinct pieces — each one a thing that needs its own explanation, not the whole diff explained once.

2. For each piece, in order:
   - **Junior pass**: ask the user to explain what it does and why, in plain terms a junior engineer would follow — no jargon standing in for understanding. Push back on hand-waving ("it fixes the bug" isn't an explanation of *how*) and on anything that's just narrating the code line-by-line instead of explaining the idea.
   - **Senior pass**: once the junior explanation holds up, ask them to defend it at a senior level — why this approach over the obvious alternative, what tradeoff they accepted, what would break if a key assumption were wrong.

3. When an explanation is unclear, incomplete, or wrong, say specifically what's missing or off — don't just mark it failed. Let the user retry. Keep coaching and retesting the same piece until the explanation is genuinely solid; don't move on to spare their time.

4. Move to the next piece only once both passes hold for the current one. When every piece has passed both, tell the user plainly that they've passed — this is a standalone comprehension check, not a gate on committing or opening a PR.
