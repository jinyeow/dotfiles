---
name: retro
description: Conduct a retrospective on a coding session, surfacing improvements to the agent's environment (docs, checks, conventions) rather than to the code itself.
disable-model-invocation: true
---

The user has asked for a **retrospective**. The goal is improvements to the coding agent's
**environment** — its docs, checks, and conventions — that make future sessions go better.
This is not a code review of the session's diff; it is a review of the scaffolding around it.

## Steps

1. Call the `write` skill for this repo's tone rules before drafting any proposed wording (no
   AI-sounding phrasing, no em-dash, plain prose). If a candidate touches a skill file, call
   `writing-great-skills` too, for the vocabulary that keeps a skill predictable.

2. Read the primary sources for the session the user specifies. This may mean searching
   through session logs on this machine. If the user doesn't specify a session, default to
   the current one.

3. Look for candidates for improvement in these categories.

- **Navigation**: how easy was it for the agent to find the right files? Are there hidden
  dependencies between files? Would a pointer in `AGENTS.md`, `ai-agents/AGENTS.md`, or a
  skill's own body make it easier? _Use when_ the session took a long time to find a piece
  of information.
- **Automated checks**: are there automated checks that could catch errors the agent made?
  Linting (`PSScriptAnalyzer`), typing, tests, filesystem linters? _Use when_ the agent made
  a mistake that could have been caught by an automated check.
- **Conventions and review rubric**: should `quick-review`/`deep-review` (via
  `ai-agents/skills/_shared/review-rubric.md`) be given a new rule to enforce, or the shared
  `ai-agents/AGENTS.md` conventions gain a new standing rule? Should an existing rule be
  removed or clarified? _Use when_ review missed a mistake, or the same correction keeps
  recurring across sessions.
- **Root steering files**: are there instructions in the root `AGENTS.md`, `ai-agents/AGENTS.md`,
  or `claude/CLAUDE.md` that would serve better as a review-rubric rule or an automated check
  instead? _Use when_ one of these files is growing large relative to what every task needs.
- **Tool economy**: did the agent make expensive tool calls that could be streamlined? Is
  there any custom tooling (CLIs, MCP servers, skills) that is particularly token-inefficient?
  _Use when_ the agent made an expensive tool call.
- **No-ops**: look for instructions in steering files that don't change the agent's behavior.
  _Use when_ the steering files are large and unwieldy.
- **Information access**: look for opportunities to widen the agent's access to information —
  tailing logs, read-only access to a third-party service. _Use when_ a piece of information
  the agent needed wasn't available to it.

4. Present these candidates to the user, in order of severity. Do not apply any of them
   without the user's go-ahead.

## Reference

### Implementation vs review

Work in this repo goes through two stages: implementation and review (`quick-review`,
`deep-review`, or the `review-fix-loop`). The implementation agent carries the most context
pressure — it does the exploring, the writing, the debugging. The review agent carries the
least — it works from a diff, so it does no exploration and rarely writes or debugs code.

That split is why the review rubric (`ai-agents/skills/_shared/review-rubric.md`), not the
implementation agent's own prompt, is the right place to add a new standing convention: it
reaches every diff without adding context load to every implementation session.

### Files

Relevant files in this repo:

- Root `AGENTS.md` and `claude/CLAUDE.md`: pushed into the context window of every agent
  working in this repo. Keep these lean — pointers to detail, not the detail itself (see the
  Authority index in the root `AGENTS.md`).
- `ai-agents/AGENTS.md`: shared coding conventions for Claude Code and Codex CLI. The natural
  home for a new standing rule, ahead of a one-off note in the root file.
- `ai-agents/skills/_shared/review-rubric.md` (plus `dimensions.md`, `findings-schema.md`):
  read during review, not implementation. This is where a convention becomes an enforced
  check rather than a hope.
- `docs/adr/`: historical rationale and rejected alternatives, not a second copy of current
  instructions.
- Skills under `ai-agents/skills/`: use a skill for a workflow the agent should follow, or for
  reference the agent should consult on demand — its description sits in context every turn
  when model-invoked, so keep it earning that cost. See `writing-great-skills` for the full
  vocabulary.
