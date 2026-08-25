# Skill ownership

Ownership is explicit by source directory. Skills are portable by default; runtime-native
skills are reserved for instructions that directly require one runtime's hooks, tools, state,
or orchestration surface. PR #63 changes only source layout, not skill classification.

## Portable (`ai-agents/skills/`)

This is the canonical home for runtime-neutral Agent Skills. It is projected to Claude Code,
Codex CLI, and Pi where each runtime is configured to load it. This includes `council`,
`council-code`, `council-business`, `council-plan`, `council-doc`, `project-brain` (the
`SessionStart` auto-injection hook is Claude-specific and stays a `claude/settings.json`
entry; the skill's resolve-and-read procedure itself is tool-agnostic), and, since #115,
`quick-review`, `deep-review`, `review-fix-loop`, and `fix-findings` — the review→fix skill
set. `deep-review`'s per-dimension subagent fan-out (previously the blocker below) is proven
out on Pi via `pi-subagents`' `tools:` frontmatter allowlist (same grain as Claude's named-tool
allowlist); see `ai-agents/skills/deep-review/DISPATCH.md`. Codex-native porting of these four
skills is implemented by #116 (per
`docs/adr/portable-review-skills-migration-sequencing.md`): `[agents.<name>]` role tables in
`codex/config.toml` are description-only spawn guidance — per-role `sandbox_mode`/
`developer_instructions`/`mcp_servers` are unsupported at codex-cli 0.147.0, so enforcement
is the orchestrating session's own top-level `sandbox_mode` — which may itself be
`workspace-write`, in which case nothing enforces a reviewer's read-only posture — see
`ai-agents/skills/deep-review/DISPATCH.md` for the schema evidence; the orchestrator's
findings-store write path on Codex hosts remains an open gap. `storm-research` is portable
too, as of #172 resolving the #95 spike below: its five expert-lens prompts and
citation-verifier fan-out need only parallel dispatch with distinct per-child prompts, no
per-child tool scoping, on Pi via `pi-subagents`' `subagent({ tasks: [...] })` reusing the
builtin `researcher` agent; see `ai-agents/skills/storm-research/DISPATCH.md`. `walkthrough`
is portable too, as of #91: its `~/.claude/learner-profile.md` path now resolves to the
runtime's own config home (`~/.claude/`, `~/.codex/`, `~/.pi/agent/`); its stale
`.claude/tickets.md`/`.claude/specs/*.md` reference was corrected to the current
`.agents/tickets.md`/`.agents/specs/*.md` convention, and its project-brain resolution was
already portable. `codex-review` is portable too, as of #98: its only Claude coupling was its
own directory living under `claude/skills/` — its `../_shared/review-rubric.md` link already
resolved to the portable `ai-agents/skills/_shared/` copy at the installed destination (#115),
so the move itself was the fix. It is projected to Claude Code and Pi but deliberately excluded
from Codex CLI (`setup.ps1`/`setup.sh` filter it out of the Codex projection list) — asking
Codex to review its own changes has no target. Pi's projection is not yet functional: the
`codex` MCP server is only registered for Claude Code, so the skill's precondition fails on
Pi until #208 wires up the registration. `dispatch-implement` is portable too, as of #210:
its ticket parsing, parallel-vs-sequential overlap judgment, and per-ticket model selection are
runtime-neutral, and it wraps the portable `implement` without changing it. It is projected to
all three runtimes, but only Claude Code's dispatch is wired (the `Agent` tool, with
`isolation: "worktree"` for parallel children so they do not race one shared `.git/index`); on
Codex CLI (`[agents.implementer]` + `spawn_agent`, #211) and Pi (`pi-subagents`, #212) the skill
stops and reports instead of dispatching until those tickets land.

## Portable support (`ai-agents/skills/_shared/`)

Portable review support resources — `dimensions.md`, `findings-schema.md`, `review-rubric.md`,
`reviewer-models.md` — live here, projected alongside the skills above into every runtime's
skills directory (`quick-review` and friends reach it via `../_shared/<file>`, resolved at the
installed destination). Not a standalone skill (no `SKILL.md`). `reviewer-models.md` documents
only the Claude Code / Codex-MCP dispatch surfaces today — see its own scope note.

A separate, unrelated `ai-agents/_shared/` (no `skills/` in the path) holds an older,
independently-owned, source-only copy of the same three filenames, predating the #101 split
of `deep-review` into `quick-review` + `deep-review` — not projected, and not kept in sync.
No ticket currently tracks consolidating or removing it; do not confuse the two paths.

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

- `azure-boards-organiser` — depends on the per-skill `commands/` subfolder convention
  (`claude/README.md` line 174, 12 files under `commands/`), documented only for Claude
  Code and unproven elsewhere. (Not just its config path or MCP tool names, which are
  themselves portable in concept — an earlier pass in this audit missed the `commands/`
  directory and wrongly called this one portable before catching the mistake.) Research
  spike: #94.
- `git-guardrails-claude-code` — installs a Claude Code `PreToolUse` hook; needs an
  equivalent pre-execution interception mechanism in Codex/Pi, not yet confirmed to
  exist. Research spike: #97.

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
