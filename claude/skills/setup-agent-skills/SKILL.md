---
name: setup-agent-skills
description: Configure the agent-skill workflow for this repo — where specs/designs/tickets land, whether an issue tracker is used and its label vocabulary, the domain-doc layout, and how the tracker expresses wayfinding operations. Run once per repo before to-spec / to-hld / to-tickets / triage / wayfinder.
disable-model-invocation: true
---

# Setup Agent Skills

One-time per-repo configuration for the spec → design → tickets → implement workflow. Explore the repo, present options one at a time, confirm, then write the repository-root `agent-skills.md` file that the other skills read. If the file already exists, show it and confirm changes rather than starting over.

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

## 5. Wayfinding operations (tracker path only — local markdown works out of the box)

`wayfinder` charts a map of investigation tickets on the tracker. Record how *this* tracker expresses them, so `wayfinder` can consult it:

- **Map issue** — labelled `wayfinder:map`; its tickets are its **child issues**.
- **Ticket type labels** — `wayfinder:research` / `wayfinder:prototype` / `wayfinder:grilling` / `wayfinder:task`.
- **Blocking** — the tracker's **native** dependency link (GitHub "blocked by", Azure Boards Predecessor/Successor). Only a tracker without one falls back to a body convention.
- **Frontier query** — how to list the open, unblocked, unclaimed children (the takeable edge).
- **Claim** — assign the ticket to the driving dev before any work.

## Write the config

Write repository-root `agent-skills.md` capturing the five sections. Downstream skills (`to-spec`, `to-hld`, `to-tickets`, `triage`, `wayfinder`) read this file; absent it, they fall back to the bold defaults (and `wayfinder` to the local-markdown tracker). Do not store this configuration in `CLAUDE.md` or `AGENTS.md`; those files are runtime-loaded instructions, while this file is read only by skills that need the workflow configuration.
