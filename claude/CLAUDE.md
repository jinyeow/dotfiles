# Claude Code — global user instructions

@../ai-agents/AGENTS.md

The shared coding conventions live in `ai-agents/AGENTS.md` (imported above), so Claude Code and
Codex CLI follow the same rules. Everything below is Claude-specific.

## Code intelligence tools

Route by capability and language; see `ai-agents/AGENTS.md` → "Code navigation" for the portable principle behind this split.

- **Reading, `.cs`/`.lua` files**: prefer the built-in `LSP` tool (go-to-definition,
  find-references, hover, symbol overview, call hierarchy) — no separate process, no
  downloaded binaries. Serena's equivalent read tools (`find_symbol`, `find_declaration`,
  `find_referencing_symbols`, `find_implementations`, `get_symbols_overview`) are redundant
  there.
- **Reading, everything else** (PowerShell, Python, Go, TypeScript, Zig, Gleam, Bicep, …):
  no `LSP`-tool backend exists — use Serena's read tools.
- **Editing** (symbol-scoped rename/replace/insert/delete), any language: use Serena's
  `rename_symbol`, `replace_symbol_body`, `insert_before_symbol`, `insert_after_symbol`,
  `safe_delete_symbol` — the built-in `LSP` tool has no edit operations. Per-language Serena
  reliability: see `claude/README.md`.
- **Always re-diff after a Serena edit** before treating it as done — its issue tracker
  documents cases where a rename reports success while silently omitting edits in files
  that weren't already open.
- `get_diagnostics_for_file`, `search_for_pattern`, `read_file`, `list_dir`, `find_file`,
  `replace_content`, `replace_in_files`, `create_text_file`, and Serena's project-memory
  tools (`write_memory`/`read_memory`/`list_memories`) have no `LSP`-tool equivalent and
  stay available regardless of language.

## Auto-memory hygiene

Auto-memory (the `~/.claude/projects/<slug>/memory/` store auto-loaded via `MEMORY.md`) is
Claude-Code-only, so keep it small and prefer a durable, discoverable home over a new memory.

- **Raise the save bar.** Before writing a memory, check whether the fact belongs somewhere
  more durable: a standing rule/convention → `ai-agents/AGENTS.md` (shared) or `claude/CLAUDE.md`
  (Claude-specific); cross-repo initiative knowledge → the project brain
  (`core.md`/`STATUS.md`/ADR); a decision with rejected alternatives → an ADR under `docs/adr/`.
  Save to auto-memory **only** when it fits none of those — a genuinely session-scoped
  feedback/gotcha with no better home. When unsure, propose the durable home rather than
  defaulting to a memory.
- **Prune on review.** The `memory-review-nudge.ps1` SessionStart hook nudges (every 14 days,
  current project only) when memories are overdue for review. On "review memory", classify each
  entry keep / delete (stale or now-false) / migrate to a durable home, apply any moves, then —
  on every completed review, including one that changed nothing — stamp it by writing an ISO-8601
  UTC timestamp to the memory dir's `.last-reviewed`, or the nudge repeats every session.

## Subagent Orchestration

See `AGENTS.md` → "Subagent Orchestration" for the tool-agnostic parallel-dispatch default; the rest below is Claude Code-specific.

- **Plan → implement → review loop**. Non-trivial changes run this loop, each stage dispatched to a fit-for-purpose subagent: **plan** — a Fable subagent is fine; **implement** — Opus or Sonnet subagents, never Fable; **review** — a Fable subagent for a light pass, or the `council` skill for a thorough one. Council and fixer seat model selection, including what the `opus`/`sonnet`/`haiku`/`fable` aliases resolve to today (the bare `opus` alias is whatever Opus build Claude Code currently defaults to, Opus 5 today), is centralized in [`ai-agents/skills/_shared/reviewer-models.md`](../ai-agents/skills/_shared/reviewer-models.md). The **`review-fix-loop`** reviews on **Opus or Sonnet, never Fable unless I explicitly ask** (its `--reviewers` flag overrides that per run); its `fix-findings` children stay pinned per that same doc's Fixer pin section.
- **Model to task**. Fable 5.1 for judgement work: planning, design, review, decisions. Sonnet for execution. Opus for reviews, refactors, or execution that needs more judgement than Sonnet gives. For effort on routine execution, run Sonnet 5 at `high`, stepping down to `medium` where quality holds; reserve `xhigh`/`max` for hard or agentic coding, or when correctness outweighs cost. Prefer per-task `/effort` over a model downgrade for routine work.
- **Fable subagents**. Subagents often run Fable even under the pinned main-loop model, so lever-5 prompting hygiene applies to the prompts you write for them — never demand their private step-by-step reasoning (a standing 'explain your reasoning step by step' trips Fable's `reasoning_extraction` → Opus fallback); ask for short rationale + assumptions + evidence instead. See `AGENTS.md` → "Prompting downstream models" for the full lever set.
- **Lock the contract first**. Fix shared schemas/signatures and assign non-overlapping files before fanning out.
- **Orchestrator stays lean**. Don't redo an agent's work; integrate and verify once at the end, or once per item in orchestrator mode (see AGENTS.md → "Subagent Orchestration").
- **Orchestrator mode dispatch**. Rule text is in AGENTS.md → "Subagent Orchestration"; only Claude mechanics here. Pass `model:` on every `Agent` call (`haiku`, `sonnet`, `opus`; `fable` for a plan or light-review seat only). Effort has no call parameter: custom definitions under `ai-agents/agents/` take an `effort:` frontmatter key (`low` to `max`, default inherits the session); built-in `Explore` and `general-purpose` inherit the session effort. Research and verification go to `Explore` or `general-purpose` on Sonnet or Haiku; fixes follow the Plan → implement → review pins above; Fable seats get short-rationale prompts per "Fable subagents".
- **No writes to shared files without a merge step**.

## Codex second opinion

Codex CLI is wired in as a read-only MCP reviewer (the `codex` MCP server). Use it as a
cross-model second opinion — its strengths differ from mine, so it catches things I miss.

- After implementing a feature or non-trivial fix, **offer** a Codex review before I commit:
  one short line, e.g. "Run this past Codex? (y/n)". Do not call Codex or apply anything
  without my yes — never review automatically, never auto-apply findings.
- On my yes, run `/codex-review` (or call the `codex` MCP tool on the current diff), then
  summarise the findings grouped by severity (HIGH / MEDIUM / LOW). I decide what to apply.
- When I am stuck on a bug after ~2 attempts, suggest delegating the debugging context to
  Codex for a second opinion before trying a third approach — again, only on my go-ahead.
- The reviewer is read-only and non-interactive; it returns findings only and cannot edit
  my working tree. Applying fixes is your job (with my approval), not Codex's.
- **Exception — `quick-review` / `deep-review` / `review-fix-loop`:** invoking any of these skills is
  standing consent to include Codex as a reviewer/verifier when its MCP is present, without a per-run offer.
  Council never implies consent: it includes external Codex only with explicit `--codex`.
  The offer-first rule above still governs all *ad-hoc* Codex use. When a run uses Codex,
  report it visibly in the run summary.
