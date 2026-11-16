---
initiative: <PBI-id>-<slug>
type: core
updated: YYYY-MM-DD
generated:
  by: <agent-or-session>
  at: YYYY-MM-DDTHH:MM:SSZ
---

# <Initiative title> — core

> Stable context. Auto-loaded every session in this initiative's directories. Keep it small and durable;
> volatile state lives in `STATUS.md`, not here. Edit rarely.

## What this is
<1-3 sentences: the goal, why it exists, definition of done.>

## Where the work lives
<the repos/worktrees/spikes this spans — the same set registered in registry.json.>

## Durable facts & gotchas
<conventions, contracts, "X looks safe but does Y" — the things a fresh session must know and can't
re-derive from the code. Not status.>

## Key decisions
<one line per accepted ADR, linking it: - [ADR-NNNN](adr/NNNN-slug.md) — <decision>.>

## Map — where to find more (read on demand)
- Status: `STATUS.md`
- Research: `research/index.md`
- ADRs: `adr/`
- Reports: `reports/index.md`
- Codebase knowledge: `../../wiki/` (link specific pages; do not duplicate them here)
