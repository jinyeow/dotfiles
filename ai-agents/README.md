# AI agent resources

This directory owns portable agent resources. Runtime-native skills live in their runtime
modules, and ownership is expressed by the directory rather than inferred from skill prose:

- `skills/` — portable (agent-agnostic) skills projected to supported runtimes, including
  `skills/_shared/` — the projected review-support contract (`dimensions.md`,
  `findings-schema.md`, `review-rubric.md`, `reviewer-models.md`) shared by `quick-review`,
  `deep-review`, `review-fix-loop`, and `fix-findings`, all four of which are portable skills
  under `skills/` too.
- `_shared/` — holds only `banned-ai-terms.txt`, the wordlist the AI-reference hooks read
  (symlinked individually by the installers). Not a skill and not projected; unrelated to
  `skills/_shared/`.
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

The skills taken from [mattpocock/skills](https://github.com/mattpocock/skills) are unedited copies of
upstream commit `6f7f783` (2026-11-25), each with its `agents/openai.yaml` Codex metadata. Re-sync
them by copying the upstream folders again; do not edit them in place.

- **`agent-staging`** — Per-workspace drop and exchange zone where the developer and their agents leave files for each other across sessions, with an `agent-inputs\` lane and an `agent-outputs\` lane.
- **`ask-matt`** — Ask which skill or flow fits your situation.
- **`azure-compliance`** — Run Azure compliance and security audits with azqr plus Key Vault expiration checks.
- **`azure-enterprise-infra-planner`** — Architect and provision enterprise Azure infrastructure from workload descriptions.
- **`azure-resource-manager`** — Expert knowledge for Azure Resource Manager development including troubleshooting, best practices, decision making, architecture & design patterns, limits & quotas, security, configuration, integrations & coding patterns, and deployment.
- **`bicep-tdd`** — Use when authoring or changing Azure Bicep and you want it validated test-first, a local RED→GREEN loop of `bicep build`/`lint`, PSRule for Azure (WAF policy-as-code), and a committed snapshot-compare regression gate, plus Pester golden-fixture tests over the compiled ARM. Needs the **Bicep CLI** on PATH and the **PSRule.Rules.Azure** module (`Install-Module PSRule.Rules.Azure -Scope CurrentUser`); stops at compiled ARM, never authenticates to a tenant.
- **`codebase-design`** — Shared vocabulary for designing deep modules.
- **`code-review`** — Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes: Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?).
- **`codex-review`** — Get a read-only Codex (OpenAI) second opinion on the current code changes, as a cross-model review.
- **`council`** — Cost-bounded adversarial review of a non-diff artifact.
- **`critique-plan`** *(trial)* — Stress-test a drafted plan against the project's domain model before any code is written: terminology drift, wrong bounded context, ADR contradictions, bad dependency edges, reinvented concepts. Adapted from [ayoubben18/ab-method](https://github.com/ayoubben18/ab-method) (MIT).
- **`deep-review`** — Heavy multi-dimension cross-model code review of a branch diff or PR, the opt-in deep pass, not the default.
- **`diagnosing-bugs`** — Diagnosis loop for hard bugs and performance regressions.
- **`domain-modeling`** — Build and sharpen a project's domain model.
- **`fix-findings`** — Apply fixes for findings produced by quick-review or deep-review.
- **`grill-me`** — A relentless interview to sharpen a plan or design.
- **`grill-with-docs`** — A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
- **`grilling`** — Grill the user relentlessly about a plan, decision, or idea.
- **`handoff`** — Compact the current conversation into a handoff document for another agent to pick up.
- **`health`** — Manual engineering health audit of your agent setup: Claude/Codex config drift, hooks, MCP, skills, memory and skill supply-chain security, and AI-maintainability drift.
- **`i-have-adhd`** — Shape output for a reader with ADHD: lead with the next action, number multi-step work, restate state across turns, suppress tangents, give specific time estimates, make wins visible. `disable-model-invocation: true` — invoke explicitly with `/i-have-adhd`; stays on until "stop adhd mode". Adapted from [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) (MIT).
- **`implement`** — Implement a piece of work based on a spec or set of tickets.
- **`implement-spec`** — Implement the result of /to-spec and /to-tickets in code.
- **`improve-codebase-architecture`** — Scan a codebase for deepening opportunities, present them as a visual HTML report, then grill through whichever one you pick.
- **`jj`** — Use when working in a Jujutsu (jj) repository: making/describing changes, syncing with a remote, rewriting history, managing bookmarks or workspaces, or recovering via the op log.
- **`linkedin-jobs`** — Read LinkedIn job alert emails and recruiter InMails, extract role details, and present them as structured cards grouped by inferred category.
- **`llmwiki-insights`** — Read an LLM-maintained wiki (Karpathy's LLM Wiki pattern) and synthesize prioritized, actionable findings about the subject matter it documents.
- **`project-brain`** — Load and maintain the "project brain": durable cross-repo initiative knowledge (core context, volatile STATUS, ADRs, research, reports) that lives in a git repo outside any single code repo, so work spanning multiple repos/worktrees/spikes stays coherent between sessions. Also packaged as a Claude Code plugin for machines without these dotfiles; see [Standalone project-brain plugin](#standalone-project-brain-plugin).
- **`prompt-draft`** — Draft a new prompt from a task description, applying the 12-lever prompting checklist from scratch.
- **`prompt-lint`** — Score, critique, and rewrite an existing prompt against the 12-lever prompting checklist: output format, acceptance criteria, scope, and reasoning-extraction risk.
- **`prototype`** — Build a throwaway prototype to answer a design question.
- **`prove-it`** — Empirically prove a fix or feature works by diffing observed behavior between the base branch and the current branch.
- **`quick-review`** — The default review pass over a branch diff or PR.
- **`redraft`** — Scrap the current fix and redo it properly, using everything learned while building the mediocre version.
- **`refactor-agents-md`** — Refactor an AGENTS.md file to follow progressive disclosure: split it into a minimal root file plus linked category files.
- **`research`** — Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the repo.
- **`retro`** — Conduct a retrospective on a coding session.
- **`review-ado-pr`** — Review an Azure DevOps pull request locally, end-to-end.
- **`review-fix-loop`** — Iterative review-fix cycle for a branch or PR.
- **`review-me`** — Interrogate the user on the current diff as an adversarial reviewer and withhold the PR until they pass.
- **`rfc`** — Draft and create an Azure DevOps "Request for Change RFC" work item in the configured work project.
- **`setup-home-repo`**: Set up or adopt a Home Repo (`gateroom`) for a workspace on any machine, in four steps with an approval gate before any change.
- **`setup-matt-pocock-skills`** — Configure this repo for the engineering skills: set up its issue tracker, triage label vocabulary, and domain doc layout.
- **`storm-research`** — Runs a 4-phase pipeline over a topic: five expert lenses (Practitioner, Academic, Skeptic, Economist, Historian), a contradiction map, a synthesized HTML report, and adversarial peer review plus primary-source verification.
- **`tdd`** — Test-driven development.
- **`teach`** — Teach the user a new skill or concept, within this workspace.
- **`teach-back`** — Grill the user until they can explain the current diff clearly to a junior engineer and defend it to a senior engineer.
- **`techdebt`** — Inventory non-architectural tech debt and hand approved findings to to-tickets.
- **`to-hld`** — Turn the current conversation and codebase understanding into a high-level design document: decisions plus logical mermaid diagrams, no interview.
- **`to-pullrequest`** — Create a pull request on GitHub (`gh pr create`) or Azure DevOps (`az repos pr create`) with a drafted title/body that has been run through the `write` skill first, so AI-sounding prose never ships in a PR description.
- **`to-questionnaire`** — Turn a decision you can't fully answer into a questionnaire for someone else to fill in.
- **`to-spec`** — Turn the current conversation into a spec and publish it to the project issue tracker: no interview, just synthesis of what you've already discussed.
- **`to-tickets`** — Break a plan, spec, or the current conversation into a set of tracer-bullet tickets, each declaring its blocking edges, published to the configured tracker (edges as text in one file per ticket locally, or native blocking links on a real tracker).
- **`triage`** — Move issues and external PRs through a state machine of triage roles, categorise, verify, grill if needed, and write agent-ready briefs.
- **`wait-what`** — Stop.
- **`walkthrough`** — Walk me through a diff like a senior mentoring a junior: pair-programming style, chunk by chunk, concise, open to questions.
- **`wayfinder`** — Plan a huge chunk of work (more than one agent session can hold) as a shared map of decision tickets on your issue tracker, and resolve them one at a time until the way to the destination is clear.
- **`wizard`** — Generate an interactive bash wizard that walks a human through steps only they can perform.
- **`worktree-janitor`** — Automate the post-merge worktree cleanup ritual for a bare-worktree repo layout: scan every worktree, check merge/completion status (GitHub or Azure DevOps) or the project-brain STATUS.md for local-only work, then remove and branch-delete what is confirmed safe.
- **`wrapup`** — Two-question self-review before ending a session, run before /clear, /compact, or quitting so the agent reflects while it still has the turn.
- **`write`** — Remove AI-sounding wording from any text another human will read (commit messages, code comments, config comments, CHANGELOG and README entries, in-repo docs, drafts, long-form articles, PR and ticket descriptions, acceptance criteria, and PR/ticket comments) while preserving the author's intent and voice.
- **`writing-for-agents`** — Writing documents for agents.

## Standalone project-brain plugin

`skills/project-brain/` is also a Claude Code plugin root. It holds `.claude-plugin/plugin.json`,
`hooks/hooks.json`, and the SessionStart loader script. The repo-root
`.claude-plugin/marketplace.json` lists it. Use this on a machine that does not run the dotfiles
setup:

```powershell
claude plugin marketplace add jinyeow/dotfiles
claude plugin install project-brain@dotfiles
```

The plugin sets no `version`, so each commit is a new version. Third-party marketplaces do not
auto-update by default. To get new commits, run `claude plugin marketplace update dotfiles`, then
`claude plugin update project-brain@dotfiles`.

The hook needs PowerShell 7 (`pwsh`) on `PATH`. The plugin does not create
`~/.claude/project-brain/brains.json`. Until a brain workspace exists, the hook loads nothing. To start
a brain, follow the `project-brain` skill's "New workspace" step. It creates the brain repo from the
skill's `templates/` and writes `brains.json`. The plugin does not include the separate
`setup-home-repo` skill, which sets up an optional Home Repo.

Do not install the plugin on a machine where `setup.ps1 -Module claude` has run. That setup
already links the skill into `~/.claude/skills/` and registers the same hook in `settings.json`,
so the plugin would load both twice. The Codex and Pi projections are unaffected by the plugin.
