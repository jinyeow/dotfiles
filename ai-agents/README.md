# AI agent resources

This directory owns portable agent resources. Runtime-native skills live in their runtime
modules, and ownership is expressed by the directory rather than inferred from skill prose:

- `skills/` — portable (agent-agnostic) skills projected to supported runtimes, including
  `skills/_shared/` — the projected review-support contract (`dimensions.md`,
  `findings-schema.md`, `review-rubric.md`, `reviewer-models.md`) shared by `quick-review`,
  `deep-review`, `review-fix-loop`, and `fix-findings`, all four of which are portable skills
  under `skills/` too.
- `_shared/` — a separate, source-only portable review-support copy; not a standalone skill and
  not projected. Independently owned from `skills/_shared/` and may diverge — do not confuse
  the two: `skills/_shared/` is live and reachable by installed skills, this one is not.
- `agents/` — the source of truth for current user-scope agent definitions, projected to
  Claude Code.

Claude-native skills and projected support content live in `../claude/skills/`; Codex-native
variants belong in `../codex/skills/`; Pi-native variants remain in `../pi/skills/`.

Codex has no separate top-level agent directory; Codex-specific agent metadata belongs in a
skill's `agents/openai.yaml`. The review skills' per-dimension `multi_agent` custom agents
(a different mechanism — `spawn_agent` role definitions, not skill-level identity) are
declared as `[agents.<name>]` tables in `codex/config.toml` instead; see
`ai-agents/skills/deep-review/DISPATCH.md`. Pi has no built-in custom-agent directory; use a
Pi package or extension when a custom agent needs runtime integration.

Installer projections consume these current source areas. The released historical roots
`ai-agents/shared/skills/`, `ai-agents/claude/skills/`, and `ai-agents/codex/skills/` remain
compatibility identifiers for safe upgrade ownership detection only; installers never recreate
them.

## Skills

Every portable skill under `skills/*/`, projected to Claude Code, Codex CLI, and Pi (`skills/_shared/`
is a shared-resource directory, not a skill, and is excluded below). Descriptions are each skill's
own `SKILL.md` frontmatter, trimmed to one line. Claude-native skills live in `../claude/skills/`
(see `../claude/README.md`); Codex-native and Pi-native skills would live in `../codex/skills/` and
`../pi/skills/` respectively, both currently empty.

- **`azure-compliance`** — Run Azure compliance and security audits with azqr plus Key Vault expiration checks.
- **`azure-devops`** — Expert knowledge for Azure DevOps development including troubleshooting, best practices, decision making, architecture & design patterns, limits & quotas, security, configuration, integrations & coding patterns, and deployment.
- **`azure-enterprise-infra-planner`** — Architect and provision enterprise Azure infrastructure from workload descriptions.
- **`azure-pipelines`** — Expert knowledge for Azure Pipelines development including troubleshooting, best practices, decision making, architecture & design patterns, limits & quotas, security, configuration, integrations & coding patterns, and deployment.
- **`azure-prepare`** — Prepare Azure apps for deployment (infra Bicep/Terraform, azure.yaml, Dockerfiles).
- **`azure-resource-manager`** — Expert knowledge for Azure Resource Manager development including troubleshooting, best practices, decision making, architecture & design patterns, limits & quotas, security, configuration, integrations & coding patterns, and deployment.
- **`azure-validate`** — Pre-deployment validation for Azure readiness.
- **`bicep-tdd`** — Use when authoring or changing Azure Bicep and you want it validated test-first, a local RED→GREEN loop of `bicep build`/`lint`, PSRule for Azure (WAF policy-as-code), and a committed snapshot-compare regression gate, plus Pester golden-fixture tests over the compiled ARM. Needs the **Bicep CLI** on PATH and the **PSRule.Rules.Azure** module (`Install-Module PSRule.Rules.Azure -Scope CurrentUser`); stops at compiled ARM, never authenticates to a tenant.
- **`codebase-design`** — Shared vocabulary for designing deep modules: module, interface, depth, seam, adapter, leverage, locality.
- **`codex-review`** — Get a read-only Codex (OpenAI) second opinion on the current code changes, as a cross-model review.
- **`council`** — Cost-bounded adversarial review of a non-diff artifact.
- **`council-business`** — Thin council alias for ideas, products, and business cases.
- **`council-code`** — Thin council alias for technical designs, ADRs, APIs, and approach documents.
- **`council-doc`** — Thin council alias for presentations, proposals, and important documents.
- **`council-plan`** — Thin council alias for project plans, roadmaps, and migrations.
- **`deep-review`** — Heavy multi-dimension cross-model code review of a branch diff or PR, the opt-in deep pass, not the default.
- **`diagnosing-bugs`** — Diagnosis loop for hard bugs and performance regressions.
- **`dispatch-implement`** — Dispatch one subagent per ticket to run `/implement` on it.
- **`fix-findings`** — Apply fixes for findings produced by quick-review or deep-review.
- **`grilling`** — Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree.
- **`grill-with-docs`** — Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise.
- **`health`** — Manual engineering health audit of your agent setup: Claude/Codex config drift, hooks, MCP, skills, memory and skill supply-chain security, and AI-maintainability drift.
- **`i-have-adhd`** — Shape output for a reader with ADHD: lead with the next action, number multi-step work, restate state across turns, suppress tangents, give specific time estimates, make wins visible. `disable-model-invocation: true` — invoke explicitly with `/i-have-adhd`; stays on until "stop adhd mode". Adapted from [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) (MIT).
- **`implement`** — Implement a piece of work from a spec or set of tickets: TDD at agreed seams, review, then commit.
- **`improve-codebase-architecture`** — Find deepening opportunities in a codebase, informed by the domain language in CONTEXT.md and the decisions in docs/adr/.
- **`jj`** — Use when working in a Jujutsu (jj) repository: making/describing changes, syncing with a remote, rewriting history, managing bookmarks or workspaces, or recovering via the op log.
- **`linkedin-jobs`** — Read LinkedIn job alert emails and recruiter InMails, extract role details, and present them as structured cards grouped by inferred category.
- **`project-brain`** — Load and maintain the "project brain": durable cross-repo initiative knowledge (core context, volatile STATUS, ADRs, research, reports) that lives in a git repo outside any single code repo, so work spanning multiple repos/worktrees/spikes stays coherent between sessions.
- **`prompt-draft`** — Draft a new prompt from a task description, applying the 12-lever prompting checklist from scratch.
- **`prompt-lint`** — Score, critique, and rewrite an existing prompt against the 12-lever prompting checklist: output format, acceptance criteria, scope, and reasoning-extraction risk.
- **`prototype`** — Build a throwaway prototype to flesh out a design before committing to it.
- **`prove-it`** — Empirically prove a fix or feature works by diffing observed behavior between the base branch and the current branch.
- **`quick-research`** — Delegate lightweight reading legwork to a background agent: investigate a question against primary sources and capture the findings as a short cited Markdown file in the repo, so you keep working while it reads.
- **`quick-review`** — The default review pass over a branch diff or PR.
- **`redraft`** — Scrap the current fix and redo it properly, using everything learned while building the mediocre version.
- **`refactor-agents-md`** — Refactor an AGENTS.md file to follow progressive disclosure: split it into a minimal root file plus linked category files.
- **`resolving-merge-conflicts`** — Use when you need to resolve an in-progress git merge/rebase conflict.
- **`review-ado-pr`** — Review an Azure DevOps pull request locally, end-to-end.
- **`review-fix-loop`** — Iterative review-fix cycle for a branch or PR.
- **`review-me`** — Interrogate the user on the current diff as an adversarial reviewer and withhold the PR until they pass.
- **`rfc`** — Draft and create an Azure DevOps "Request for Change RFC" work item in the "TSC Change Control" project.
- **`setup-agent-skills`** — Configure the agent-skill workflow for this repo: where specs/designs/tickets land, whether an issue tracker is used and its label vocabulary, the domain-doc layout, and how the tracker expresses wayfinding operations.
- **`spec-review`** — Review a diff for conformance to its originating spec or ticket: missing requirements, scope creep, and requirements implemented wrong.
- **`storm-research`** — Runs a 4-phase pipeline over a topic: five expert lenses (Practitioner, Academic, Skeptic, Economist, Historian), a contradiction map, a synthesized HTML report, and adversarial peer review plus primary-source verification.
- **`tdd`** — Test-driven development with red-green-refactor loop.
- **`teach`** — Teach the user a new skill or concept, within this workspace.
- **`teach-back`** — Grill the user until they can explain the current diff clearly to a junior engineer and defend it to a senior engineer.
- **`techdebt`** — Inventory non-architectural tech debt and hand approved findings to to-tickets.
- **`to-hld`** — Turn the current conversation and codebase understanding into a high-level design document: decisions plus logical mermaid diagrams, no interview.
- **`to-pullrequest`** — Create a pull request on GitHub (`gh pr create`) or Azure DevOps (`az repos pr create`) with a drafted title/body that has been run through the `write` skill first, so AI-sounding prose never ships in a PR description.
- **`to-spec`** — Turn the current conversation into a spec and publish it: no interview, just synthesis of what you've already discussed.
- **`to-tickets`** — Break a plan, spec, or conversation into tracer-bullet tickets with blocking edges, written to `.agents/tickets.md` or published to the configured tracker.
- **`triage`** — Move issues and external PRs through a state machine of triage roles: categorise, verify, grill if needed, and write agent-ready briefs.
- **`walkthrough`** — Walk me through a diff like a senior mentoring a junior: pair-programming style, chunk by chunk, concise, open to questions.
- **`wayfinder`** — Plan a huge chunk of work, more than one agent session can hold, as a shared map of investigation tickets on your issue tracker, and resolve them one at a time until the way to the destination is clear.
- **`worktree-janitor`** — Automate the post-merge worktree cleanup ritual for a bare-worktree repo layout: scan every worktree, check merge/completion status (GitHub or Azure DevOps) or the project-brain STATUS.md for local-only work, then remove and branch-delete what is confirmed safe.
- **`wrapup`** — Two-question self-review before ending a session, run before /clear, /compact, or quitting so the agent reflects while it still has the turn.
- **`write`** — Remove AI-sounding wording from any text another human will read (commit messages, code comments, config comments, CHANGELOG and README entries, in-repo docs, drafts, long-form articles, PR and ticket descriptions, acceptance criteria, and PR/ticket comments) while preserving the author's intent and voice.
- **`writing-great-skills`** — Reference for writing and editing skills well: the vocabulary and principles that make a skill predictable.
- **`zoom-out`** — Tell the agent to zoom out and give broader context or a higher-level perspective.
