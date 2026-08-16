---
name: setup-agent-skills
description: Configure the agent-skill workflow for this repo — where specs/designs/tickets land, whether an issue tracker is used and its label vocabulary, the domain-doc layout, and how the tracker expresses wayfinding operations. Run once per repo before to-spec / to-hld / to-tickets / triage / wayfinder.
disable-model-invocation: true
---

# Setup Agent Skills

One-time per-repo configuration for the spec → design → tickets → implement workflow. Explore the repo, present options one at a time, and confirm them. Read repository-root `.agents/workflow.local.md` first when it exists, otherwise repository-root `.agents/workflow.md`. Show the effective configuration and confirm changes rather than starting over.

## 1. Output locations

Confirm where each artifact lands (defaults in bold; detect an existing `docs/` tree first and prefer it):

- Specs → **`.agents/specs/`**
- High-level designs → **`docs/design/`**
- Tickets → a tracker (below) or **local `.agents/tickets.md`**

## 2. Issue tracker (optional)

Default is **local markdown files** — no tracker needed. If this repo uses one, record it so downstream skills publish there:

- GitHub Issues / Azure Boards / Azure DevOps Wiki / other
- For a real tracker, optionally treat external PRs as a triage surface (used by `triage`).

## 3. Label vocabulary (tracker path only — local files need no labels)

Map the canonical states to the repo's actual label strings:

- `spec-ready` — spec complete, ready to break into tickets
- `design-ready` — HLD complete/approved
- `triaged` — ticket assessed & scoped
- `ready` — AFK ticket; an agent may grab & implement
- `needs-info` — blocked awaiting clarification *(optional)*
- `wontfix` — will not be actioned *(optional)*

## 4. Domain-doc layout

Confirm how domain knowledge is arranged so skills use the right vocabulary and respect decisions:

- **Single-context** — one root `CONTEXT.md` + `docs/adr/`
- **Multi-context** — a `CONTEXT-MAP.md` pointing at per-area docs (monorepo)

## 5. Wayfinding operations (tracker path only — local markdown works out of the box)

`wayfinder` charts a map of investigation tickets on the tracker. Record how *this* tracker expresses them, so `wayfinder` can consult it:

- **Map issue** — labelled `wayfinder:map`; its tickets are its **child issues**.
- **Ticket type labels** — `wayfinder:research` / `wayfinder:prototype` / `wayfinder:grilling` / `wayfinder:task`.
- **Blocking** — the tracker's **native** dependency link (GitHub "blocked by", Azure Boards Predecessor/Successor). Only a tracker without one falls back to a body convention.
- **Frontier query** — how to list the open, unblocked, unclaimed children (the takeable edge).
- **Claim** — assign the ticket to the driving dev before any work.

## Write the config

Ask whether the configuration is private to this checkout or intentionally shared with the repository:

- **Private (default)** — write repository-root `.agents/workflow.local.md`. If this is a git repository, resolve its root with `git rev-parse --show-toplevel`. From that root, if `git check-ignore -q .agents/workflow.local.md` reports it is not already ignored, append `/.agents/workflow.local.md` to the local exclude file returned by `git rev-parse --git-path info/exclude`. Create its parent directory if needed. This is idempotent, applies across linked worktrees through Git's resolved path, and never modifies a tracked ignore file.
- **Shared** — write repository-root `.agents/workflow.md`, which may be committed for the team.

Capture the five sections under an `# Agent workflow` heading. Downstream skills (`to-spec`, `to-hld`, `to-tickets`, `triage`, `wayfinder`) resolve `.agents/workflow.local.md` first, then `.agents/workflow.md`; if neither exists, they fall back to the bold defaults (and `wayfinder` to the local-markdown tracker). Do not duplicate this configuration under `.claude/`, `.codex/`, or `.pi/`, and do not store it in `CLAUDE.md` or `AGENTS.md`: all three harnesses read this one file explicitly only when a workflow skill needs it.

Repos configured before this convention moved from `.claude/` to `.agents/` may still have `.claude/tickets.md` / `.claude/specs/`. Those legacy paths keep working — `to-spec` and `spec-review` still read from a `.claude/specs/` directory when found, and `to-tickets` appends to an existing `.claude/tickets.md` rather than starting a second file. New output otherwise goes under the `.agents/` defaults above.
