# Prompting levers checklist

Shared source for `prompt-lint` and `prompt-draft`. 12 levers distilled from
`prompting-claude-fable-5.md`. Score every lever; mark `n/a` when the prompt's task genuinely has
no surface for it (e.g. lever 10 provenance on a code-refactor prompt).

| # | Lever | Check | Note |
|---|---|---|---|
| 1 | Lead with the why | Purpose + audience + what the output enables, stated before the instructions | |
| 2 | Bound scope both ways | Every "don't touch X" paired with the positive deliverable | Bare negatives drift once forgotten |
| 3 | Set the inertia | Decisive-by-default stated, OR a short plan-first step required for high-ambiguity/high-risk work | Independent of lever 2 — not the same dial |
| 4 | Prove it | Asks for evidence before "done" (diff, test output, command result) — not just a status claim | |
| 5 | No reasoning extraction | No "explain your reasoning step by step" / "think out loud" / chain-of-thought demand; asks for rationale + assumptions + evidence instead | **HIGH severity.** Trips Fable's `reasoning_extraction` refusal → fallback to Opus (Claude Code: transcript notice; raw API: `stop_reason: "refusal"`) |
| 6 | Say less, say the right things | No restated procedure the model already does by default; the real signal (why/format/acceptance) still present | Padding, not brevity for its own sake |
| 7 | Name the output format | Structure (list/table/prose/code) + a length cap | Most commonly missing lever |
| 8 | Show an example | 1–2 input→output pairs, when format matters | Skip when the format is trivial (a single sentence, a yes/no) |
| 9 | State acceptance criteria | What "good" looks like and how it's judged | |
| 10 | Set provenance rules | Cite sources / quote evidence / say "unknown" when unsupported | Only applies to research or claim-bearing prompts |
| 11 | Handle assumptions + conflicts | Lists assumptions instead of asking; asks only when genuinely blocked; stops and flags on conflicting instructions | |
| 12 | Iterate, don't one-shot | Asks for draft → self-critique → revise, when quality matters more than latency | Skip for low-stakes/one-shot tasks |

## Fable 5 mechanics (appendix)

- **Effort is per-task**, not global: `high` default, `xhigh` for capability-sensitive work,
  `low`/`medium` for routine work (`/effort` in Claude Code).
- **Security / CTF / biology tasks default to Opus** (`/model opus`) — these domains trigger the
  fallback frequently, often on the first request.
- **Fallback can fire on the first message** — workspace context (CLAUDE.md, git status) is sent
  with the first request, so a security- or biology-heavy repo can trip the classifier before the
  user types anything unusual.
