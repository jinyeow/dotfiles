---
name: implement-spec
description: Implement a whole spec as one pull request — work the ticket frontier with concurrent implementer subagents until every ticket lands, then review and open the PR.
disable-model-invocation: true
---

# Implement Spec

Takes a spec and its tickets (`to-spec` + `to-tickets`, or their tracker equivalents) and lands
the whole thing as a single PR. The tickets are not a checklist — they are a task graph with
blocking edges, so there is always a **frontier** (`to-tickets`, `wayfinder`) of tickets ready to
grab. This skill drives that frontier to empty, then reviews and opens the PR.

This is an orchestrator, not an implementer: `dispatch-implement` already owns per-ticket
mechanics (parallel-vs-sequential judgment, per-child model pick, worktree isolation, cherry-pick
integration onto the branch) — this skill calls it per batch rather than reimplementing any of
that. Keep prompts to subagents sparse: point at the spec, the tickets, and prior commits rather
than restating their content.

## Steps

1. **Read the spec and tickets.** Resolve their location from `.agents/workflow.local.md` when
   present, otherwise `.agents/workflow.md` (`.agents/specs/<slug>.md` + `.agents/tickets.md` by
   default, or the configured tracker). Read enough to see the full task graph — which tickets
   block which — not just the first frontier.

2. **Explore first, if a ticket needs it (optional).** When a ticket depends on unfamiliar
   codebase areas or external documentation, delegate that reading to a background research
   agent before implementation starts. Have it save its notes to a file outside the repo so every
   later subagent can read it by path — a context pointer, not something repeated in each
   subagent's prompt.

3. **Branch and open a draft PR.** Create the branch per `AGENTS.md` → "Git worktrees" if this
   repo uses that layout, then run `/to-pullrequest` to open it as a draft that closes the spec
   issue and its tickets (GitHub linking keywords, or the tracker's native relationship).

4. **Work the frontier to empty.** While any ticket remains open: run `/dispatch-implement` with
   every ticket in the current frontier in one call — it judges which can run in parallel, isolates
   parallel children in their own worktree, and integrates each onto the branch. Once a batch
   lands, recompute the frontier (the tickets it just unblocked) and dispatch again. Repeat until
   no ticket remains.

5. **Review the whole branch.** With every ticket closed, run `/review-fix-loop` on the branch —
   this catches cross-ticket issues no single ticket's implementer could see.

6. **Mark the PR ready for review.** `to-pullrequest` stops at PR creation, so undraft directly:
   `gh pr ready <number>` (GitHub) or `az repos pr update --id <id> --draft false` (Azure DevOps).

7. **Report** the PR URL, the tickets landed, and any ticket that had to be resolved outside the
   normal frontier flow (rescoped, split, or dropped as out of scope).

## Related

- `to-spec`, `to-tickets` — produce the spec and task graph this skill consumes.
- `dispatch-implement` — owns the per-batch subagent mechanics (parallel judgment, worktree
  isolation, cherry-pick integration); this skill only decides which tickets go in each batch.
- `review-fix-loop` — the whole-branch quality gate before the PR goes up for review.
- `to-pullrequest` — opens the draft PR; this skill undrafts it directly once review passes.
- `wayfinder` — the frontier/task-graph vocabulary this skill reuses, for planning work larger
  than one spec.
