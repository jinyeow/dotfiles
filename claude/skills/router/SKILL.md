---
name: router
description: Ask which skill or flow fits your situation. A router over the skills in this repo — invoke it when you can't remember what you have.
disable-model-invocation: true
---

# Router

You don't remember every skill, so ask.

**How to use this map.** Invoked bare (`/router`), orient: read the flows below and point yourself at the right entry skill. Invoked with a situation (`/router something in the pipeline keeps failing`), dispatch: jump to the matching section, name the single best-fit skill, say in one line why it over its neighbours, and give the exact `/command` to run next. Either way the router only ever **recommends** — you invoke the skill it points to; it never does the work itself. Before stating what a skill does or recommending a step be skipped, read that skill's SKILL.md. The one-line summaries here are for orientation only.

Two routers split the work. **`/ask-matt`** owns the mattpocock skills, vendored unedited from upstream: the main flow (grill, spec, tickets, implement, review), its on-ramps (`/triage`, `/diagnosing-bugs`, `/wayfinder`), codebase health (`/improve-codebase-architecture`, `/codebase-design`, `/domain-modeling`), phase boundaries (`/handoff`, compact, clear), and its standalone skills (`/prototype`, `/grill-me`, `/teach`, `/research`, `/retro`, `/wait-what`, `/to-questionnaire`, `/wizard`, `/writing-for-agents`, `/setup-matt-pocock-skills`). For any of those, run `/ask-matt <situation>`. This router covers the skills of your own and where they plug into that flow. Skills tagged **(built-in)** ship with Claude Code, not this repo.

## Your additions to the main flow

`/ask-matt` describes the flow. These steps are yours and slot into it:

1. **After grilling, before `/to-spec`: `/critique-plan`.** Always run it on the plan the grilling settled. One fresh-context critic checks it against `GLOSSARY.md` and the ADRs (terminology drift, wrong context, ADR contradictions, reinvented concepts, workarounds a reshape would remove) and stays silent when the plan is clean.
2. **After `/to-spec`: `/to-hld`** when the architecture is worth writing down. It derives a high-level design doc (decisions plus mermaid diagrams) for `docs/design/`.
3. **After implementing:** `/spec-review` checks the diff against what was asked for, and the review ladder below picks the code review. Not happy with how a fix came out? **`/redraft`** scraps it and redoes it properly.
4. **Understand what was built: `/walkthrough`** tours the diff like a senior pairing with a junior, framed against the driving spec or ticket, and remembers what you know through the learner profile.
5. **Prove you own it, then ship:** **`/review-me`** grills you on the diff and holds the PR until you pass; **`/teach-back`** checks you can explain it to a junior and defend it to a senior. **`/to-pullrequest`** opens the PR on GitHub or Azure DevOps with a body run through `/write`.
6. **Close the session: `/wrapup`** runs a two-question self-review before you clear or quit.

For upkeep beside `/improve-codebase-architecture`, **`/techdebt`** inventories non-architectural debt (dependency health, dead code, stale TODOs, test debt, suppressed checks, toolchain and doc drift) from existing tool output and hands approved findings to `/to-tickets`.

## Reviewing & verifying — a ladder by target

Pick by **what you're reviewing** and **how hard**. Each rung escalates.

- **`/code-review`** (built-in) — the diff, quality axis. `/implement` and `/implement-spec` call it before committing. Upstream's own two-axis `code-review` is not installed, so in Claude Code the name resolves to the built-in.
- **`/spec-review`** — the diff against its **spec or ticket**: missing requirements, scope creep, requirements built wrong. The conformance axis, not quality.
- **`/codex-review`** — a read-only **cross-model** (Codex/OpenAI) second opinion on the current changes. Standing OK to run after implementing a feature or non-trivial fix, before commit; delegating debugging to Codex needs a go-ahead; findings are never auto-applied; `council` needs explicit `--codex`.
- **`/quick-review`** — the **default** findings pass over a diff/PR: one folded reviewer (correctness + conventions + tests) plus Codex, verified into the same findings store. Two participants, not eight.
- **`/deep-review`** — the **opt-in** heavy version of the same pass: all seven dimensions (adds security, performance, structural, architecture) plus Codex. Reach for it when the diff's risk earns eight participants.
- **`/review-fix-loop`** — the loop: chains a review pass (**`/quick-review`** by default, **`/deep-review`** under `--deep`) with **`/fix-findings`** (apply + commit, one fix-unit at a time), looping until clean at the severity floor. Reach here for "review and fix until clean"; reach for the review skill alone when you only want the findings. `--reviewers <model>[:<effort>]` picks the reviewer models on both.
- **`/council`** — cost-bounded adversarial panel for **non-diff artifacts**. Quick mode is the default; `--debate` opts into rebuttals and `--codex` explicitly opts into an external seat. It auto-picks the panel; `/council code|business|plan|doc <target>` pins it. **Not for diffs** — use `/quick-review`.
- **`/security-review`** (built-in) — a security-focused pass over the pending changes.
- **`/prove-it`** — drive the change on the base branch and on yours and diff the observed behaviour, not just the tests.
- **`/review-ado-pr`** — an **Azure DevOps** PR end-to-end: fetch it into the review worktree, run the Bicep gates, review across models, and post threads or a vote only on your go-ahead.

*Not a rung: to have a diff **explained to you** rather than judged, use **`/walkthrough`** (see Writing & docs) — it tours the change like a senior pairing with a junior and emits no findings.*

## Prompting

Two halves of the 12-lever prompting checklist.

- **`/prompt-draft`** — write a *new* prompt (system prompt, subagent prompt) from a task description, applying the levers from scratch.
- **`/prompt-lint`** — score, critique, and rewrite an *existing* prompt against the levers, including reasoning-extraction risk.

## Azure & cloud — which one when

Six skills; the value is disambiguation. Match the task, not the keyword.

| You're doing… | Skill |
|---|---|
| Boards work items — PBIs/Bugs/Tasks, sprint planning, standups | **`/azure-boards-organiser`** |
| ARM/Bicep template & deployment-stack *knowledge* and patterns | **`/azure-resource-manager`** |
| *Authoring* Bicep test-first — offline RED→GREEN, WAF policy, snapshot gate | **`/bicep-tdd`** |
| Architecting enterprise topology — landing zone, hub-spoke, multi-region DR | **`/azure-enterprise-infra-planner`** |
| Compliance / security audit — azqr, Key Vault expiry, orphaned resources | **`/azure-compliance`** |
| Raising a Request for Change (RFC) work item — BAU firewall/NSG changes and other subtypes | **`/rfc`** |

Key forks: `azure-resource-manager` is *knowledge*, `bicep-tdd` is the *authoring loop*; `azure-enterprise-infra-planner` designs the whole topology; `azure-compliance` audits standing posture.

## Writing & docs

- **`/write`** — de-AI and polish English prose: drafts, READMEs, release notes, long-form. Not code comments or commit messages.
- **`/walkthrough`** — have a **diff** explained to you like a senior pairing with a junior: checkpoint tour, overview, or socratic mode, framed against the driving spec/ticket. The post-`/implement` stage of the main flow. Tracks what you know in a learner profile — general skills in `~/.claude/learner-profile.md`, domain knowledge in the project-brain's `learner.md`.

## Research

Lightest first (the lightest, `/research`, is under `/ask-matt`):

- **`/deep-research`** (built-in) — fan-out web searches, adversarially verify, synthesize a cited **Markdown** report. The general research harness.
- **`/llmwiki-insights`** — read an LLM-maintained wiki you already keep and turn it into prioritized findings about its subject.
- **`/storm-research`** — a multi-perspective, citation-verified **HTML briefing** (five expert lenses → contradiction map → synthesis → adversarial verification). For topics where viewpoints and fact-checking matter.

Research feeds the main flow — take its output *into* `/grill-with-docs`; it doesn't replace the thinking.

## Version control

- **`/worktree-janitor`** — post-merge cleanup for a bare-worktree layout: checks each worktree's merge status (GitHub, Azure DevOps, or the project-brain STATUS.md) and removes and branch-deletes only what is confirmed safe.
- **`/jj`** — working in a **Jujutsu** repo: making/describing changes, syncing, rewriting history, bookmarks, op-log recovery. Windows/pwsh-native. Doesn't fire in pure-git repos.

## Durable memory

When to hand off, clear or compact between phases is `/ask-matt`'s call (its Phase boundaries section). The durable stores are yours:

- **`/project-brain`** — durable **cross-repo** initiative knowledge (core context, volatile STATUS, ADRs, research) in a git repo *outside* any code repo. Reach for it when an effort spans multiple repos/worktrees and must stay coherent between sessions.
- **`/setup-home-repo`** — set up or adopt a workspace's Home Repo, the optional companion to `/project-brain`. One-time, with an approval gate before any change.
- **`/agent-staging`** — the per-workspace drop zone where you and your agents leave files for each other across sessions (`agent-inputs\` and `agent-outputs\`).

## Config & upkeep

- **`/health`** — audit your **agent setup**: Claude/Codex config drift, hooks, MCP, skills, memory, skill supply-chain security, AI-maintainability drift. Not for application code.
- **`/refactor-agents-md`** — split an overgrown AGENTS.md into a minimal root file plus linked category files.

## Inbox & personal

- **`/fastmail`** — a live inbox + calendar digest.
- **`/linkedin-jobs`** — read LinkedIn job-alert emails and recruiter InMails into structured cards.

## Standalone

Off the flows entirely.

- **`/i-have-adhd`** — shape every reply for a reader with ADHD (next action first, numbered steps, visible wins) until you say "stop adhd mode".
