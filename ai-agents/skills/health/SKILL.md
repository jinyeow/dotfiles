---
name: health
description: "Manual engineering health audit of your agent setup: Claude/Codex config drift, hooks, MCP, skills, memory and skill supply-chain security, and AI-maintainability drift. Run via /health when you want to audit agent configuration or maintainability. Not for debugging application code or reviewing PRs."
disable-model-invocation: true
---

# Health: Agent-Assisted Engineering Health

Audit the current project's agent setup and AI coding maintainability against this framework:
`agent config → instruction surfaces → tools/runtime → verifiers → maintainability`

This is a **manual, agent-driven** audit. You collect the config surfaces yourself with Read/Grep/Glob/Bash (no external collector scripts) and interpret them against the checks below. Find violations, identify the misaligned layer, calibrate to project complexity. Report in English.

## Outcome Contract

- Outcome: a budget-aware health report that separates agent-configuration risk from AI-maintainability risk.
- Done when: each finding names the misaligned layer, the concrete evidence (file:line), and a copy-pasteable action or diagnostic command.
- Evidence: the config surfaces you read, runtime config summaries, verifier presence, hooks/MCP surfaces, and live MCP probes when needed.
- Output: prioritized findings with status, impact, and next action, or a clear clean bill with residual risk.

Two lanes share one report:

- **Agent config health**: Claude/Codex instruction drift, permissions, hooks, MCP, skills, and memory supply chain.
- **AI maintainability health**: project context surface, verifier wrapper, generated-artifact checks, hotspot ownership, and stale or misleading durable docs.

## Budget posture

Start with the summary audit. Escalate to a deep pass only when the user asks for a deep/full/thorough audit, names a specific concern (config drift, missing verification, AI code rot, supply chain), the project is Complex, or the summary pass exposes a critical ambiguity that cannot be resolved locally. A deep pass reads full skill bodies, nested rules, and git history, and costs materially more tokens. Tell the user before escalating.

**Prune requests.** When the user asks to slim, prune, or trim guidance, skills, or rules, read only the instruction and config surfaces and return a ledger in place of the finding list. Give one row per passage: `file:line`, action (`fix`, `delete`, `move`, `edit`, `keep`), destination for a move, and reason. Fix stale references and contradictions first. Delete only what a capable model already does by default. Keep constraints, user preferences and silent traps, and never compress one-way-door rules (deleting user data, publishing, privilege, rewriting pushed history). Move before compressing. Apply only the rows the user confirms, even when the request said to fix, then check `git diff` against the base revision so every vanished line matches a confirmed `delete` or `edit` row.

## Step 0: Assess project tier

Pick one. Apply only that tier's requirements.

| Tier | Signal | What's expected |
|---|---|---|
| **Simple** | <500 files, 1 contributor, no CI | CLAUDE.md only; 0-1 skills; hooks optional |
| **Standard** | 500-5K files, small team or CI | CLAUDE.md + 1-2 rules; 2-4 skills; basic hooks |
| **Complex** | >5K files, multi-contributor, active CI | Full six-layer setup required |

## Step 1: Collect data

Read the config surfaces directly. Skip any that are absent; **absent is insufficient data, not a finding**. On this Windows/pwsh setup the canonical locations are:

- **Global agent instructions**: `~/.claude/CLAUDE.md`, `~/.claude/AGENTS.md`; Codex `~/.codex/config.toml`, `~/.codex/AGENTS.md`.
- **Global settings + hooks**: `~/.claude/settings.json` (plus `settings.local.json` if present; the local file shadows the committed one).
- **MCP registrations**: `~/.claude.json` (`mcpServers` for user scope, `projects.<path>.mcpServers` for local scope), the project's `.mcp.json` (project scope), and each enabled plugin's `.mcp.json`. Codex servers are `mcp_servers` in `~/.codex/config.toml`. Claude ignores `mcpServers` in any `settings*.json`; report such an entry as dead config.
- **Project instructions**: `./CLAUDE.md`, `./AGENTS.md`, nested `**/CLAUDE.md` and `**/AGENTS.md`, `.claude/rules/*.md`.
- **Which instruction files Claude loads**: Claude Code reads `AGENTS.md` through its built-in `cc-plugin-agents-md` mod (`agents-md@builtin` before v2.1.285). Since v2.1.277 the mod is on by default in `claude-md-or-agents-md` mode: a root `CLAUDE.md` wins, otherwise `AGENTS.md` loads. `pluginConfigs.<mod>.options.instructionFiles` in `~/.claude/settings.json` can set `claude-md`, `claude-md-or-agents-md`, `claude-md-and-agents-md` or `managed-only`. Setting the mod to `false` in `enabledPlugins` means `claude-md`. Under `claude-md` an `AGENTS.md`-only repo reaches Codex and Cursor and leaves Claude with no project guide. Under `claude-md` and `claude-md-or-agents-md`, a root `CLAUDE.md` takes the whole project off the `AGENTS.md` path, so nested `AGENTS.md` files stop reaching Claude. Under `claude-md-and-agents-md` they still load, unless the root `CLAUDE.md` is the same physical file as `AGENTS.md` (a symlink or hard link). Flag only the cases that really lose a guide.
- **Skills**: `~/.claude/skills/*/SKILL.md` (inventory + frontmatter). Note junction/symlink provenance (on Windows the skill dirs are junctioned into `~/.claude/skills` from the source repo).
- **Memory**: the project `MEMORY.md` and its `memory/` directory.
- `./.gitignore`, `./HANDOFF.md` or `.claude/handoff*.md`.

Compute tier metrics: file count (`Glob`, excluding `.git/`, `node_modules/`, `__pycache__/`, `.next/`, build dirs), contributors (`git shortlog -sn --all | wc -l`), CI workflows (`.github/workflows/`, `*.azure-pipelines.yml`). Do not interpret yet.

## Step 1b: MCP live check

Resolve each Claude server's effective entry before probing. A same-name server resolves local > project > user. A `.mcp.json` server loads only once approved through `enabledMcpjsonServers` or `enableAllProjectMcpServers` (in a settings file or the project's entry in `~/.claude.json`); until then it is pending. A name in `disabledMcpjsonServers` rejects it. A pending or rejected project server leaves a same-name user server live. `disabledMcpServers` in the project's entry in `~/.claude.json` disables a server by name; plugin servers appear there as `plugin:<plugin>:<server>`.

Test every enabled server: call one harmless read-only tool per server. Record `live=yes/no` with error detail. Record disabled, pending approval and untested servers as their own states, and skip them without flagging (this includes `enabled: false`). For API keys, only check that the env var is set (e.g. first few chars), never print the full key.

For each `command` hook, check the executable of every simple command in the chain (split on `&&`, `||`, `;` and `|`). Skip leading assignments, redirects, `!`, and prefixes such as `env`, `exec`, `command` and `time -p`, and skip builtins such as `cd`, `source`, `exit`, `unset` and `export`. Flag a missing executable or script anywhere in the chain, including one behind `cd <dir> &&`. Report a command that uses `$VAR` or a relative path as unverified.

## Step 1c: Safety and security checks

These run after collection and before the Step 2 analysis. The first two apply to every audit; the third only to projects with long-running or autonomous agents.

### Security Baseline Checks

Run these on every audit, regardless of tier. They are the floor, not the ceiling.

**Deny-list floor.** Apply this only when the runtime actually enforces the rule shape being recommended: agent permission settings, hook settings, MCP settings, allowed/denied tools, or a documented autonomous-agent launcher. In that case, the settings should deny, at minimum: credential and key directories (SSH, cloud providers, GPG, gh CLI), secret files (`.env`, `credentials*`, `secrets*`), and pipe-to-shell installers. Report this as one concise Structural finding with the missing categories; let the reviewer fill in exact local paths. Three calibrations: prefix/glob permission rules cannot reliably match pipes, so recommend the host's pre-execution hook for pipe-to-shell blocking instead of inventing glob variants, and name the hook's own tradeoff (string-matching hooks also fire on quoted text and heredocs that merely contain the pattern); do not credit an existing hook as that block when its command is prefixed with `!`, a redirect, or an assignment to `PATH`, `PYTHON*`, `LD_*` or `DYLD_*`, since each can invert its exit status, cut it off from the tool input on stdin, or swap the interpreter it runs; before predicting an outbound-shell deny's blast radius, check which layer it matches at: a command-prefix deny on `ssh` only blocks the agent invoking `ssh` directly and leaves git's internal SSH transport alone, while a process- or sandbox-level block does break git-over-SSH push; and when a runtime has no command-level deny surface (Codex: the levers are `sandbox_mode` and `approval_policy`), name that lever once as a user tradeoff instead of recommending deny keys the runtime cannot express. If no agent settings surface exists at all, report the deny-list as not applicable rather than a failure.

**Permission-layer vs instruction-layer gating.** An allowlist entry for a git write action (`git push`) next to an instruction-layer rule ("push only when the user says so") is not automatically a contradiction: instructions decide when the action happens, permissions decide whether it re-prompts, and a user who explicitly authorizes pushes every session may keep push in allow deliberately to avoid double confirmation. Calibrate by reversibility and the user's own rules: actions the instructions forbid outright (`git reset --hard`, `git stash`, force-push) belong in deny or ask; routine explicitly-authorized actions stay where the user put them, reported at most as a note. Escalate only when auto mode plus skipped prompts plus broad allow lets a write action run with zero user input in a session, and even then present the friction tradeoff for the user to choose instead of silently moving entries.

**Environment override surface.** Treat the following as attack surface, report when set in tracked files or shipped settings without a justification comment: API base-URL overrides (redirect all traffic to a third party), auto-trust flags for project-local MCP servers, wildcard tool allowlists (`allowedTools: ["*"]`), and permission-skip flags (`--dangerously-skip-permissions` or equivalents). Print file:line and the key name only; never print secrets.

### Memory and Skill Supply Chain

Treat agent memory and third-party skills as supply-chain artifacts. They run with the user's privileges.

**Memory hygiene.** Audit the project's long-term agent memory store for secrets, tokens, or credentials (Critical), and for entries written by untrusted runs (subagent invoked on attacker-controlled input, /loop iteration over external content); recommend rotation after such runs. For high-risk one-off runs (untrusted PDFs, uncontrolled scraping, third-party scripts), recommend disabling memory persistence for that session entirely.

**Skill supply chain.** Third-party skills, plugins, and MCP servers run with the user's privileges. For each one not authored in this repo, check: source pinned to a release tag or revision (not `main`, a branch, or a remote git marketplace left tracking its latest head), hook handlers do not write to credential directories, MCP servers have explicit user consent (not auto-trusted by wildcard). Report unpinned sources or unreviewed hook handlers as Structural, not Critical, unless an active exploit signal is present.

### Long-Running Agent Stop Conditions

For projects that use `/loop`, autonomous agents, or any long-running agent flow, the project must define explicit stop conditions. An agent that never stops is a budget and safety incident waiting to happen.

Audit for these four hard stop signals; flag the absence of each as a Structural finding:

1. **No progress across two consecutive checkpoints.** Same files touched, same errors logged, no new commits/tests/output. Recommend killing the loop and surfacing the state, not retrying.
2. **Repeated identical failure.** Same stack trace, same error message, same failed assertion three times in a row means the hypothesis is wrong; more attempts will not help.
3. **Cost or token budget exceeded.** Project should declare a per-run budget (tokens, API spend, wall-clock minutes). Loop exits when the budget is hit, not when work is done.
4. **External blockers.** Merge conflict on the target branch, dependency lock the agent cannot resolve, missing credential, network unreachable. Any of these halt the loop and ask the user, not retry forever.

The stop conditions should live in tracked project docs (`AGENTS.md`, the loop's launch script, or a dedicated config), not only in the agent's prompt. Prompts are forgettable; tracked config is enforceable. Recommend hooks (PostToolUse on the relevant tools) over prompt instructions when the project supports them: a hook physically cannot be skipped, a prompt instruction can. Confirm the host's hook coverage before recommending one: some agents only fire PostToolUse for a subset of tools, so a fixup that must run after file edits belongs on a Stop or session-end hook there instead.

## Step 2: Analyze

Confirm the tier. Then:

- **Simple / Standard:** single-pass local analysis from what you read. Do not read full skill bodies or git history by default.
- **Deep / thorough / Complex / explicit AI-maintainability audit:** read more deeply (full skill bodies, nested rules, `git log`) using the same framework, one deeper pass. Tell the user about the token cost first.
- **Redact** all credentials to `[REDACTED]`.

Run these checks (fold the config + control intelligence inline):

### Context & configuration checks

- **Startup context budget.** Estimate `(global_claude_words + local_claude_words + rules_words + skill_description_words) × 1.3 + mcp_tokens`. Count a root `AGENTS.md` in `local_claude_words` when Claude loads it (see Step 1). For Codex, compare the root project doc (`AGENTS.override.md`, else `AGENTS.md`) with `project_doc_max_bytes` (32768 by default, also when `config.toml` is absent); `~/.codex/AGENTS.md` is not charged against it. Flag `> 30K tokens` as context pressure before the first user message. Flag a single always-loaded `CLAUDE.md > ~3800 words (~5K tokens)` as an oversized contract. The action is to move path-specific rules to `.claude/rules/*.md` with `paths` frontmatter, or to a nested-directory `CLAUDE.md` or a skill, so unrelated sessions stop paying their full context cost. The action is scoping, not deletion.
- **MCP token overhead.** Estimate `~200 tokens/tool, ~25 tools/server`. Flag if estimated MCP tokens exceed 10% of the 200K context (~20K tokens), or if there are more than 6 servers (~30K tokens, roughly 15% of a 200K context). Flag idle or unreachable servers (from Step 1b) to disconnect and reclaim context.
- **CLAUDE.md quality.** Short, executable, has build/test commands. Nested `CLAUDE.md` files make stacked context unpredictable, flag them. Global-vs-local duplicate rules are Incremental; direct conflicts are Critical.
- **Skill hygiene.** Descriptions should be concise and triggerable, include `Use when` and `Not for`, and avoid overlapping triggers between skills.
- **Model-name validation.** Any `model` field in settings must be a real `claude-*` model ID. A wrong or aliased name silently wastes the entire session with no output. Flag a non-`claude-*` value as Critical.
- **Prompt-cache hygiene.** Dynamic timestamps or dates injected into always-loaded context break the prompt cache. Mid-session model switches (Opus → Haiku → Opus) rebuild the cache and can cost more; recommend subagents over switching. Flag either.
- **Three-layer defense consistency.** For each critical NEVER/ALWAYS rule in `CLAUDE.md`, check it is backed across the three layers: intent (`CLAUDE.md` declares it), knowledge (a skill teaches the method), control (a hook enforces it deterministically). Single-layer safety rules are fragile: CLAUDE.md-only rules get ignored under context pressure; hook-only rules have no teaching or flexibility; skill-only rules have no enforcement. Focus on safety-critical rules (file protection, destructive-VCS, deploy gates).

## Step 3: Report

**Health Report: {project} ({tier} tier, {file_count} files)**

**Global findings report once.** Findings in machine-global config (`~/.claude`, `~/.codex`, global rules, skills, memory) are not project findings: label them `global`, report each once with its fix, and recommend one dedicated session for global cleanup instead of re-fixing per project. Before editing any global file, re-read its current state: another session may already have fixed or be mid-fix on the same file. Never edit the same global file from two concurrent sessions.

### [PASS] Passing checks (table, max 5 rows)

### Finding format

```
- [severity] <symptom> ({file}:{line} if known)
  Why: <one-line reason>
  Action: <exact command or edit to fix>
```

`Action:` must be copy-pasteable. Never write "investigate X" or "consider Y". If the fix is unknown, name the diagnostic command.

A finding refuted in the same breath (a TODO count that turns out to be vendored code or false positives) is not a finding; drop it or fold it into the passing table.

### [!] Critical -- fix now

Rules violated, dangerous allowedTools, MCP overhead >12.5%, invalid model name, security findings, leaked credentials.

Example:

- [!] `settings.local.json` committed to git (exposes MCP tokens)
Why: leaked token enables remote code execution via installed MCP servers
Action: `git rm --cached .claude/settings.local.json && echo '.claude/settings.local.json' >> .gitignore`

### [~] Structural -- fix soon

Agent instructions in the wrong layer, missing hooks, oversized descriptions, verifier gaps, single-layer safety rules.

**Claude/Codex instruction drift.** Report a Structural finding when `AGENTS.md` and runtime-specific files (`CLAUDE.md`) both contain substantial guidance without delegation, when Codex `config.toml` lacks trust for the current project, when project agent instructions are missing, or when runtime-specific instructions contradict the shared project source of truth. Also report when important rules live only in ignored or private local overlays but the tracked/public docs lack them; those overlays are private context, not durable project source of truth. Do not print raw config values. Secrets, tokens, keys, and passwords must appear only as `[REDACTED]`.

**AI-maintainability gaps.** Treat a total absence of any executable verification command, or of any agent instruction surface in a non-trivial repo, as **Critical**; broken doc references are handled below. Report as **Structural** when instructions exist but lack a project map, verification guidance, or boundary/non-goal language; when TODO/HACK markers are concentrated; when large source hotspots lack ownership/boundary and verification guidance; when durable docs contain raw one-off review reports, scorecards, dated line references, or diagnostic dumps instead of stable invariants; or when a runtime supports path-scoped instruction loading but a large always-loaded instruction file carries domain- or language-specific rules that only apply under certain paths. The action for the last case is to add `paths` frontmatter (or move the block to a nested `CLAUDE.md` / a skill), not to delete the rule. Treat missing `docs/`, `specs/`, `HANDOFF.md`, `CHANGELOG`, issue templates, and PR templates as **Incremental** unless project complexity makes them necessary for handoff.

**Conversation-derived guidance.** When a health audit draws on recent work, do not recommend copying a conversation or a scorecard into docs. Recommend a candidate-matrix pass instead:

| Field | Question |
|---|---|
| Repeated failure | Did this recur across fixes, releases, agents, or user reports? |
| Durable invariant | Can the lesson be stated as a stable rule, not a dated incident summary? |
| Target layer | Should it live in project instructions, a skill, a global rule, or private memory? |
| Verifier | Is there a deterministic command, script, artifact check, or runtime smoke that can enforce it? |
| Redaction risk | Does the lesson require local paths, issue numbers, customer details, machine state, secrets, or unpublished release facts? |

Layering rule: project-specific commands, app names, artifact names, and release rituals stay in the project; reusable workflows belong in skills; universal honesty and verification rules belong in global CLAUDE/AGENTS; private user preferences and one-machine facts stay in memory. If the lesson cannot pass the redaction-risk field, keep it out of public guidance.

Scope by load surface, not just by layer. A rule kept in the project still pays context on every session unless it is bound to where it applies: language and framework rules carry file-type `paths` scope, project-domain rules bind to their source directories, and only genuinely cross-cutting constraints load unconditionally in the always-loaded root.

**Concentrated fix chains.** Run `git log --oneline --since='2 weeks ago' | grep -i fix` and group by area (the prefix before `:` or `(`). When the same area has 3+ fix commits in a short window, it signals a missing structural invariant: each fix is a guess at a rule that was never written down. Report a Structural finding with the area name, fix count, and recommend adding an explicit rule to `AGENTS.md` / `CLAUDE.md` / project rules that captures the invariant those fixes were converging toward. A fix chain that touches the same file 4+ times is a stronger signal than scattered fixes.

**Hotspot ownership gaps.** In deep mode, find the largest source files (`Glob` + line counts). If a largest source file exceeds a reasonable hotspot threshold and `AGENTS.md` / `CLAUDE.md` / shared instruction files do not name who owns the hotspot, what boundary should stay stable, and which verification command covers it, report a Structural finding. Do not treat documented large files as code rot by size alone; some modules are intentionally large.

**Missing stable verifier wrapper.** If the repo exposes multiple verification commands through CI, scripts, or manifests but there is no single stable default entrypoint (`Makefile` `check`/`test`/`verify` target, or the project's documented equivalent), report a Structural finding. Agents need one stable default entrypoint.

**Broken doc references.** Grep `AGENTS.md`, `CLAUDE.md`, `.claude/rules/*.md`, and every `.claude/skills/*/SKILL.md` for references shaped like `@<path>`, `~/.claude/<name>`, `docs/<name>.md`, or `references/<name>.md`. For each match, check that the target exists on disk (expand `~`; resolve `references/...` relative to each skill's own directory; skip fenced code examples). Report every "referenced but missing" pointer with the source file and line as a Structural finding, unless the missing file is named as a hard dependency, then Critical.

Common offenders:
- A project-level rule references a global rule file that was never created.
- A `CLAUDE.md` uses an `@AGENTS.md` placeholder but the actual `AGENTS.md` is missing or empty.
- A skill body references `references/<name>.md` but only `references/<name>-v2.md` exists.
- A rule file references a deleted skill path.

**Stale verifier output.** Only when the user supplies a verifier log: scan it for `/tmp` or `/private/tmp` file references that no longer exist (the signature of a stale worktree/cache), and suggest the matching cache-clean command (`golangci-lint cache clean`, `go clean -cache -testcache`, `npm cache verify`, or a diagnostic rerun for unknown tools). Do not run project tests just to feed this check.

### [-] Incremental -- nice to have

Outdated items, global vs local placement, context hygiene, stale allowedTools entries.

---

If no issues: `All relevant checks passed. Nothing to fix.`

## Non-goals

- Never auto-apply fixes without confirmation.
- Never apply complex-tier checks to simple projects.
- Never act as a heavy lint, typecheck, duplication, or architecture-rewrite substitute; `/health` reports maintainability guardrails and concrete next actions only.

## Gotchas

| What happened | Rule |
|---|---|
| Missed the local override | Always read `settings.local.json` too; it shadows the committed file |
| Looked for MCP servers in settings.json | Claude reads MCP servers from `~/.claude.json`, `.mcp.json` and enabled plugins, and ignores `mcpServers` in settings files |
| Subagent/probe timeout reported as MCP failure | MCP failures come from the live probe, not from reading config |
| Flagged intentionally noisy hook as broken | Ask before calling a hook "broken" |
| Hook seemed not to fire, but it did -- a later UI element rendered above it | Hook firing order is not visual order. Before re-editing the hook config: (a) confirm with `--debug` or by piping output, (b) check whether a diff dialog or permission prompt rendered on top and pushed the hook output offscreen, (c) only then suspect the hook itself. |
| `/health` burned too much quota on first run | Stay in summary mode first. Full skill bodies, git history, and deep reads are deep-audit tools, not the default path for Standard projects. |
| Treated missing specs/docs as a failure | Decision artifacts are optional by default. Escalate missing docs/specs only when the tier, active handoff risk, or user request makes them necessary. |
| Treated an ignored AGENTS/CLAUDE file as durable project truth | Report whether the rule is tracked and distributed. Local overlays can inform the audit, but durable fixes belong in public repo docs or shipped skill/rule files. |
| Treated a review scorecard as maintainability documentation | Scorecards are snapshots. Extract the invariant and verification path, then remove or archive the report instead of calling the score itself a durable rule. |
