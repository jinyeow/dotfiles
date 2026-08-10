# Skill ownership

Ownership is explicit by source directory. Skills are portable by default; runtime-native
skills are reserved for instructions that directly require one runtime's hooks, tools, state,
or orchestration surface. PR #63 changes only source layout, not skill classification.

## Portable (`ai-agents/skills/`)

This is the canonical home for runtime-neutral Agent Skills. It is projected to Claude Code,
Codex CLI, and Pi where each runtime is configured to load it. This includes `council`,
`council-code`, `council-business`, `council-plan`, `council-doc`, and `project-brain` (the
`SessionStart` auto-injection hook is Claude-specific and stays a `claude/settings.json`
entry; the skill's resolve-and-read procedure itself is tool-agnostic).

## Portable support (`ai-agents/_shared/`)

Source-only portable review support resources live here. The directory has no `SKILL.md` and
is never projected as a standalone skill. Its files are independently owned from Claude's
projected support copy and the two directories may diverge.

## Claude-native (`claude/skills/`)

The #78 audit (full reasoning: `reports/2026-08-07-skills-portability-audit.md` in the
dotfiles brain) re-derived each reason below from the current file content rather than
carrying forward the reasons written when this list was first drafted (some had gone
stale or were never quite right). **Desired end state: portable everywhere the underlying
capability makes sense** — every skill below is either already ticketed for migration or
blocked on a named, concrete dependency, not "fine as Claude-native" by default. Absence
of a ticket means not yet scoped, not "won't move."

The entries below describe a skill's current **technical dependency only** — what it
actually relies on today, with evidence — not a judgement about whether it's worth
migrating. That judgement is tracked per-skill by ticket, since it changes independently
of the technical facts (see the 2026-08-07 want-check round in the audit report).

**Blocked on an unresearched upstream mechanism** — the skill's core behavior needs a
capability that may not exist in Codex/Pi; confirming that is a prerequisite before a
migration ticket is even writable:

- `deep-review`, `fix-findings` — `deep-review` dispatches one differently-*scoped*
  subagent per reviewer dimension in parallel; `fix-findings` inherits the blocker via
  composition. Research spike: #93. (#101 split off `quick-review` as the lightweight
  default; the full-fan-out dependency described here stayed with `deep-review`.)
- `azure-boards-organiser` — depends on the per-skill `commands/` subfolder convention
  (`claude/README.md` line 174, 12 files under `commands/`), documented only for Claude
  Code and unproven elsewhere. (Not just its config path or MCP tool names, which are
  themselves portable in concept — an earlier pass in this audit missed the `commands/`
  directory and wrongly called this one portable before catching the mistake.) Research
  spike: #94.
- `storm-research` — needs parallel agent spawn with distinct prompts, but not
  `deep-review`'s per-agent tool-scoping — a lighter, separately-tracked requirement.
  Research spike: #95.
- `git-guardrails-claude-code` — installs a Claude Code `PreToolUse` hook; needs an
  equivalent pre-execution interception mechanism in Codex/Pi, not yet confirmed to
  exist. Research spike: #97.

**Content-coupled** — depends on a Claude-scoped copy of shared content, not a missing
mechanism; fixable by repointing the reference:

- `_shared` — Claude review-support resources, projected with Claude skills.
- `quick-review` — the #101 default review pass. Two participants only, so it does not
  need `deep-review`'s per-dimension tool-scoping; it is coupled to the Claude-scoped
  `claude/skills/_shared/` copies (`dimensions.md`, `findings-schema.md`,
  `review-rubric.md`, `reviewer-models.md`) and shares `deep-review`'s REFERENCE for scope
  and store resolution, so it moves when that cluster moves. Migration ticket: none yet.
- `codex-review` — links to `claude/skills/_shared/review-rubric.md`, a Claude-scoped
  copy, not `ai-agents/_shared/`. Migration ticket: #98.

**Needs design work** — the skill's value depends on a Claude-only *convenience trigger*
(not a missing primitive), so portability needs a designed equivalent, not a spike:

- `handoff` — the value is the *next Claude Code session's* `SessionStart` hook
  auto-picking up `.claude/handoff.md`. Design ticket: #99.
- `router` — hardcodes references to skill names/built-ins that are themselves still
  being migrated; its map can't be rebuilt until those land. Design ticket: #100,
  explicitly blocked on #91/#92/#93/#94/#95/#97/#98/#99.

**Portable candidates — migration ticket filed, not yet moved:**

- `fastmail` — only coupling is Claude Code's `mcp__fastmail__*` tool-name syntax in the
  prose; the Fastmail MCP server itself is portable in concept. Migration ticket: #92.
- `walkthrough` — only coupling is two hardcoded paths (`~/.claude/learner-profile.md`,
  `.claude/tickets.md`/`.claude/specs/*.md`); already resolves project-brain the portable
  way. Migration ticket: #91.

Claude-native skills are projected only to Claude Code, while portable skills are projected
there alongside them. If names collide, the Claude-native variant wins.

## Codex-native (`codex/skills/`)

Codex-native variants live here only when they must differ from a portable skill and win name
collisions during projection. The directory is currently empty. Linux Codex projection is a
follow-up requirement, not part of this layout migration.

## Pi-native (`pi/skills/`)

Pi-native variants remain in the Pi runtime module and win name collisions over portable
skills during both Windows and Linux projection.

## Agents

Agent definitions under `ai-agents/agents/` are canonical source-owned definitions. They use
Claude Code's flat agent-file adapter and are projected only to `~/.claude/agents/`; the
directory is repository ownership, not cross-runtime projection. Installers recognize the
historical `ai-agents/shared/agents/` target only to safely migrate existing managed links.
Codex has no separate top-level agent directory, and Pi packages/extensions provide isolation.
