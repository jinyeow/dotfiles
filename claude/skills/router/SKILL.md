---
name: router
description: Ask which skill or flow fits your situation. A router over the skills in this repo — invoke it when you can't remember what you have.
disable-model-invocation: true
---

# Router

You don't remember every skill, so ask.

**How to use this map.** Invoked bare (`/router`), orient: read the flows below and point yourself at the right entry skill. Invoked with a situation (`/router something in the pipeline keeps failing`), dispatch: jump to the matching section, name the single best-fit skill, say in one line why it over its neighbours, and give the exact `/command` to run next. Either way the router only ever **recommends** — you invoke the skill it points to; it never does the work itself.

A **flow** is a path through the skills. Most work runs along one **main flow**; a few **on-ramps** merge onto it. The rest are clusters you reach into directly — review, Azure, prompting, writing — each organised so you pick *which one when*, not just *what exists*. Skills tagged **(built-in)** ship with Claude Code, not this repo.

## The main flow: idea → ship

The route most feature work travels. You have an idea and want it built.

1. **`/grill-with-docs`** — sharpen the idea by interview. Start here when you **have a codebase**: it's stateful, challenging the plan against the project's language and retaining what it learns in `CONTEXT.md` and ADRs. (No codebase, or a plan that doesn't live in a repo? Use **`/grilling`** — the same relentless interview, stateless, saving nothing. `grill-with-docs` is the one that leaves a paper trail.)
2. **Branch — can you settle every question in conversation?** If a question needs a runnable answer (a state model, business logic, a UI you have to see), detour through a prototype, bridged by **`/handoff`** in both directions (see Crossing sessions):
   - **`/handoff`** out, then open a fresh session against that file,
   - **`/prototype`** to answer the question with throwaway code,
   - **`/handoff`** back what you learned, and reference it from the original thread.
3. **Branch — is this a multi-session build?**
   - **Yes** → **`/to-spec`** (turn the thread into a spec) first. Then, when the architecture is worth writing down, **`/to-hld`** derives a high-level design doc from that spec — decisions plus mermaid diagrams — for `docs/` or the wiki (the spec drives the build; the HLD documents the shape). Then **`/to-tickets`** splits the work into tracer-bullet tickets with **blocking edges** — an ordered `.claude/tickets.md` you work by hand, or native blocking links on a real tracker. Kick off **`/implement`** per ticket, **clearing context between each one**.
   - **No** → **`/implement`** right here, in the same context window.

   Either way, **`/implement`** builds each piece by driving **`/tdd`** internally — one red-green slice at a time — then closes out by running **`/code-review`** (built-in) on the diff before committing. Reach for **`/tdd`** on its own to build a concrete behaviour test-first without a full spec. After implementing from a spec or ticket, **`/spec-review`** checks the diff against what was *asked for* (missing requirements, scope creep) — the conformance axis that `/code-review`'s quality axis doesn't cover.

4. **Understand what was built** — once the reviews have run, **`/walkthrough`** walks *you* through the diff like a senior pairing with a junior: chunked into narrative beats, framed against the driving spec/ticket, in your choice of checkpoint tour / overview / socratic mode. It explains rather than judges, and it remembers what you know across sessions via the learner profile (global + project-brain).

**Precondition — `/setup-agent-skills`.** Run once per repo before your first `to-spec` / `to-hld` / `to-tickets` / `triage`: it records in private repository-root `.agents/workflow.local.md` (default) or shared repository-root `.agents/workflow.md` where specs/designs/tickets land, whether a tracker is used and its labels, and the doc layout the flow assumes.

### Context hygiene

Keep steps 1–3 in **one unbroken context window** — don't compact or clear until after `/to-tickets` — so the grilling, spec, and tickets all build on the same thinking. Each `/implement` then starts fresh from its ticket. If a session grows too long before `/to-tickets`, don't push on degraded — `/handoff` and continue in a fresh thread.

## On-ramps

A starting situation that generates work, then merges onto the main flow.

- **Bugs and requests piling up** → **`/triage`**. Moves issues and external PRs through triage roles and produces agent-ready briefs, which **`/implement`** later picks up. Only for issues **you didn't create** — tickets `/to-tickets` produced are already agent-ready, so don't triage them.
- **Something's broken** → **`/diagnosing-bugs`**. For the hard ones: the bug that resists a first glance, the intermittent flake, the regression between two known-good states. It refuses to theorise until it has a **tight feedback loop** — one command already going red on *this* bug — then fixes with a regression test.
- **A huge, foggy effort too big for one session** → **`/wayfinder`**. When the way to the destination isn't visible yet, it charts a **shared map** of investigation tickets on the tracker and resolves them one at a time — producing **decisions, not deliverables** — until the fog lifts. Then it merges onto the main flow at **`/to-spec`** (or, if the effort turned out small, straight to **`/implement`**). Where `/grill-with-docs` sharpens an idea you can hold in one session, wayfinder is for the one you can't.

## Codebase health

Not feature work — upkeep.

- **`/improve-codebase-architecture`** — run in a spare moment to keep the codebase good for agents to operate in. It surfaces **deepening opportunities**; picking one *generates an idea* you take into the main flow at `/grill-with-docs`. The survey that finds candidates.
- **`/codebase-design`** — the deep-module vocabulary (module, interface, depth, seam, adapter, leverage, locality) for designing a module's *shape*. The bench you design a chosen candidate on. `/tdd` and `/improve-codebase-architecture` both speak it.

*Domain modeling has no separate skill because `/grill-with-docs` carries the full active discipline — challenging terms, keeping `CONTEXT.md` a clean glossary, recording ADRs, with its own `CONTEXT-FORMAT.md` / `ADR-FORMAT.md`. `/codebase-design` owns module shape. Between them the vocabulary is covered.*

## Reviewing & verifying — a ladder by target

Pick by **what you're reviewing** and **how hard**. Each rung escalates.

- **`/code-review`** (built-in) — the diff, quality axis. Fast standards pass; `/implement` runs it internally before committing.
- **`/spec-review`** — the diff against its **spec or ticket**: missing requirements, scope creep, requirements built wrong. The conformance axis, not quality.
- **`/codex-review`** — a read-only **cross-model** (Codex/OpenAI) second opinion on the current changes. Offer-first for ad-hoc use; standing consent only inside `deep-review` and `review-fix-loop`.
- **`/review-fix-loop`** — the heavy loop: chains **`/deep-review`** (multi-dimension parallel reviewers + Codex, findings adversarially verified into a store) and **`/fix-findings`** (apply + commit, one fix-unit at a time), looping until clean at the severity floor. Reach here for "review and fix until clean"; reach for `/deep-review` alone when you only want the findings.
- **`/council`** — cost-bounded adversarial panel for **non-diff artifacts**. Quick mode is the default; `--debate` opts into rebuttals and `--codex` explicitly opts into an external seat. It auto-picks the panel; the four `/council-*` aliases pin it. **Not for diffs** — use `/deep-review`.
- **`/security-review`** (built-in) — a security-focused pass over the pending changes. **`/verify`** (built-in) — drive the change end-to-end and observe behaviour, not just tests.

*Not a rung: to have a diff **explained to you** rather than judged, use **`/walkthrough`** (see Writing & docs) — it tours the change like a senior pairing with a junior and emits no findings.*

## Prompting

Two halves of the 12-lever prompting checklist.

- **`/prompt-draft`** — write a *new* prompt (system prompt, subagent prompt) from a task description, applying the levers from scratch.
- **`/prompt-lint`** — score, critique, and rewrite an *existing* prompt against the levers, including reasoning-extraction risk.

## Azure & cloud — which one when

Nine skills; the value is disambiguation. Match the task, not the keyword.

| You're doing… | Skill |
|---|---|
| Boards work items — PBIs/Bugs/Tasks, sprint planning, standups | **`/azure-boards-organiser`** |
| Azure DevOps knowledge — org/projects, repos, permissions, Analytics | **`/azure-devops`** |
| Pipeline YAML, service connections, agents, Key Vault in pipelines | **`/azure-pipelines`** |
| ARM/Bicep template & deployment-stack *knowledge* and patterns | **`/azure-resource-manager`** |
| *Authoring* Bicep test-first — offline RED→GREEN, WAF policy, snapshot gate | **`/bicep-tdd`** |
| Scaffolding an app to deploy — `azure.yaml`, Dockerfiles, infra | **`/azure-prepare`** |
| Architecting enterprise topology — landing zone, hub-spoke, multi-region DR | **`/azure-enterprise-infra-planner`** |
| Pre-deploy validation — config, RBAC, managed identity, what-if | **`/azure-validate`** |
| Compliance / security audit — azqr, Key Vault expiry, orphaned resources | **`/azure-compliance`** |

Key forks: `azure-resource-manager` is *knowledge*, `bicep-tdd` is the *authoring loop*; `azure-prepare` scaffolds a single app, `azure-enterprise-infra-planner` designs the whole topology; `azure-validate` gates one deploy, `azure-compliance` audits standing posture.

## Writing & docs

- **`/write`** — de-AI and polish English prose: drafts, READMEs, release notes, long-form. Not code comments or commit messages.
- **`/teach`** — learn a concept over multiple sessions, using the current directory as a stateful workspace.
- **`/zoom-out`** — ask for broader context or a higher-level perspective when you're unfamiliar with a section of code or how it fits the whole.
- **`/walkthrough`** — have a **diff** explained to you like a senior pairing with a junior: checkpoint tour, overview, or socratic mode, framed against the driving spec/ticket. The diff-scoped sibling of `/zoom-out` (which maps static code) and the post-`/implement` stage of the main flow. Tracks what you know in a learner profile — general skills in `~/.claude/learner-profile.md`, domain knowledge in the project-brain's `learner.md`.

## Research

Three weights, lightest first:

- **`/quick-research`** — delegate reading legwork to a **background agent**: it investigates a question against primary sources and leaves a short cited Markdown file in the repo, so you keep working while it reads.
- **`/deep-research`** (built-in) — fan-out web searches, adversarially verify, synthesize a cited **Markdown** report. The general research harness.
- **`/storm-research`** — a multi-perspective, citation-verified **HTML briefing** (five expert lenses → contradiction map → synthesis → adversarial verification). For topics where viewpoints and fact-checking matter.

Research feeds the main flow — take its output *into* `/grill-with-docs`; it doesn't replace the thinking.

## Version control

- **`/jj`** — working in a **Jujutsu** repo: making/describing changes, syncing, rewriting history, bookmarks, op-log recovery. Windows/pwsh-native. Doesn't fire in pure-git repos.
- **`/resolving-merge-conflicts`** — an in-progress git merge/rebase conflict to resolve.
- **`/git-guardrails-claude-code`** — install Claude Code hooks that block destructive git (push, `reset --hard`, `clean`, `branch -D`) before they run.

## Crossing sessions & durable memory

- **`/handoff`** — compact the conversation into a markdown file, then open a **new session** and reference it. The bridge between context windows, in either direction. Use it when you want a fresh session but need the current thread preserved.
- **`/compact`** (built-in) — stay in the **same** conversation, letting earlier turns be summarized. Use at intentional breaks between phases, not mid-phase. `/handoff` forks; `/compact` continues.
- **`/project-brain`** — durable **cross-repo** initiative knowledge (core context, volatile STATUS, ADRs, research) in a git repo *outside* any code repo. Reach for it when an effort spans multiple repos/worktrees and must stay coherent between sessions.

## Config & upkeep

- **`/health`** — audit your **agent setup**: Claude/Codex config drift, hooks, MCP, skills, memory, skill supply-chain security, AI-maintainability drift. Not for application code.
- **`/setup-agent-skills`** — the per-repo precondition for the main flow (see above).

## Inbox & personal

- **`/fastmail`** — a live inbox + calendar digest.
- **`/linkedin-jobs`** — read LinkedIn job-alert emails and recruiter InMails into structured cards.

## Standalone

Off the flows entirely.

- **`/prototype`** — a small throwaway program that answers one design question (does this state model feel right; what should this UI look like). Keep the answer, delete the code. The detour in step 2 of the main flow, but reach for it any time a design question is hard to settle on paper.
- **`/grilling`** — the relentless interview primitive, stateless. The no-codebase path into the main flow, and reachable directly to stress-test any plan.
- **`/caveman`** — ultra-compressed communication mode; cuts tokens ~75% while keeping technical accuracy.
- **`/writing-great-skills`** — reference for writing and editing skills well, so a new one is predictable.
