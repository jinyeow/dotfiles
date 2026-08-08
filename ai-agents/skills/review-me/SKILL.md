---
name: review-me
description: Interrogate the user on the current diff as an adversarial reviewer and withhold the PR until they pass. Use when the user wants to be grilled/tested on their own changes before opening a PR.
disable-model-invocation: true
---

Act as the reviewer who will actually approve this PR, not as the author's assistant. Do not open the PR yet.

## Process

1. Read the full diff (`git diff` against the PR base, or the branch's commits if already pushed). Understand every change before asking anything.

2. Interrogate the user about the diff, one question at a time, waiting for their answer before continuing. Pull questions from the riskiest parts of the diff first: edge cases the code doesn't handle, why this approach over an obvious alternative, what breaks if an assumption in the code is wrong, and any part of the diff the user didn't write themselves (generated, copied, or unfamiliar).

3. Judge each answer like a real reviewer would — vague or hand-wavy answers do not pass. If an answer exposes a real gap, that is a finding: tell the user directly, and treat it as unresolved.

4. Keep going until every risky area has a passing answer or an accepted, documented tradeoff. This is a test with a pass/fail outcome, not a courtesy pass — do not soften the bar to wrap up quickly.

5. Only after the user has passed: state that explicitly, then create the PR.

If the user asks to open the PR before passing, remind them they haven't passed yet and name what's still open — don't comply just because they asked.
