---
name: defend-diff
description: Grill the user on the current diff until they can explain it to a junior engineer and defend it to the reviewer who must approve it, then offer to open the PR. Use when the user wants to prove they understand and can stand behind a change before it ships.
disable-model-invocation: true
---

The bar is not "does the code work". It is "can the user explain this change and defend it". An agent may have written much of the diff, so this is the check that the user owns it. Do not open the PR until the user passes.

## Process

1. Read the full diff (`git diff` against the PR base, or the branch's commits if already pushed). Understand every change before asking anything. Split the diff into its distinct pieces: each piece needs its own explanation.

2. Take the pieces riskiest first: edge cases the code does not handle, choices with an obvious alternative, assumptions that would break something if wrong, and any part the user did not write themselves (generated, copied, or unfamiliar). Ask one question at a time and wait for the answer.

3. For each piece, run two passes:
   - **Explain**: the user says what it does and why, in plain terms a junior engineer would follow. Push back on hand-waving ("it fixes the bug" is not an explanation of how) and on line-by-line narration that never states the idea.
   - **Defend**: once the explanation holds, the user defends the piece as they would to the reviewer who must approve it: why this approach over the obvious alternative, what tradeoff they accepted, and what breaks if a key assumption is wrong.

4. Judge each answer as a real reviewer would. A vague answer does not pass. When an answer is unclear, incomplete, or wrong, say exactly what is missing and let the user retry. When an answer exposes a real gap in the code, that is a finding: say so directly and treat it as unresolved until it is fixed or accepted as a documented tradeoff.

5. Move on only when both passes hold for the current piece. Do not lower the bar to finish sooner.

6. When every piece has passed, tell the user plainly that they have passed, list any accepted tradeoffs, and offer to open the PR with `to-pullrequest`.

If the user asks to open the PR before passing, say they have not passed yet and name what is still open. Do not open it just because they asked.
