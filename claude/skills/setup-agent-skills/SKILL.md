---
name: setup-agent-skills
description: Configure the agent-skill workflow for this repo — where specs/designs/tickets land, whether an issue tracker is used and its label vocabulary, and the domain-doc layout. Run once per repo before to-spec / to-hld / to-tickets / triage.
disable-model-invocation: true
---

# Setup Agent Skills

One-time per-repo configuration for the spec → design → tickets → implement workflow. Explore the repo, present options one at a time, confirm, then write an **Agent skills** block into the repo's `CLAUDE.md` (or `AGENTS.md`) that the other skills read. If a block already exists, show it and confirm changes rather than starting over.

## 1. Output locations

Confirm where each artifact lands (defaults in bold; detect an existing `docs/` tree first and prefer it):

- Specs → **`.claude/specs/`**
- High-level designs → **`docs/design/`**
- Tickets → a tracker (below) or **local `.claude/tickets.md`**

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

## Write the config

Write an `## Agent skills` block into `CLAUDE.md`/`AGENTS.md` capturing the four sections. Downstream skills (`to-spec`, `to-hld`, `to-tickets`, `triage`) read this block; absent it, they fall back to the bold defaults.
