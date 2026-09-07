---
name: grilling
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree in batched rounds. Use when the user wants to stress-test a plan before building, get grilled on their design, or uses any "grill" trigger phrase.
disable-model-invocation: true
---

Interview me relentlessly until we reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled — the questions you can ask now without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for my answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Each round my answers reshape the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a later round, not this one.

Finding *facts* is your job, never mine. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a subagent to find it; don't ask me for anything you could look up yourself. Don't block the round on it — a running exploration is an unsettled prerequisite, so only the questions downstream of it wait; ask the rest of the frontier now. The *decisions* are mine — put each one to me and wait for my answer.

## Decision status

Track every open branch of the tree under one of three states:

- **Resolved** — I gave an explicit answer, captured verbatim or faithfully paraphrased. Never mark a decision resolved from my silence, from a follow-up that moved past it, or from your own recommended answer standing unchallenged. No answer means the decision stays open.
- **Open** — asked, not yet answered.
- **Needs codebase check** — a fact, not a decision; dispatched to a subagent, pending its result.

## Session end

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Before handing off to implementation, give a short wrap-up:

- **Agreed decisions** — the resolved list, one line each.
- **Open risks** — anything resolved with caveats, or a resolved decision worth flagging for revisit later.
- **Next decision needed** — if the session is cutting short with the frontier not actually empty, name what's still open.

Do not act on any of this until I confirm we have reached a shared understanding.
