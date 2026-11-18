# Claude Code — global user instructions

@../ai-agents/AGENTS.md

The shared coding conventions live in `ai-agents/AGENTS.md` (imported above), so Claude Code and
Codex CLI follow the same rules. Everything below is Claude-specific.

## Code intelligence tools

Route by capability and language; see `ai-agents/AGENTS.md` → "Code navigation" for the portable principle behind this split. Check `claude plugin list` before assuming the built-in `LSP` tool covers a given language, since its supported set is whatever plugin that command shows enabled.

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

## Auto-memory

Auto-memory is off (`autoMemoryEnabled: false` in `settings.json`). When I ask you to remember
something, write it to its durable home per `AGENTS.md` → "Memory system boundaries", and say
where you put it.

## Subagent Orchestration

See `AGENTS.md` → "Subagent Orchestration" for the tool-agnostic parallel-dispatch default; the rest below is Claude Code-specific.

- **Plan → implement → review loop**. Non-trivial changes run this loop, each stage dispatched to a fit-for-purpose subagent: **plan** — a Fable subagent is fine; **implement** — Opus or Sonnet subagents, never Fable; **review** — a Fable subagent for a light pass, or the `council` skill for a thorough one. Council and fixer seat model selection, including what the `opus`/`sonnet`/`haiku`/`fable` aliases resolve to today (the bare `opus` alias is whatever Opus build Claude Code currently defaults to, Opus 5 today), is centralized in [`ai-agents/skills/_shared/reviewer-models.md`](../ai-agents/skills/_shared/reviewer-models.md). The **`review-fix-loop`** reviews on **Opus or Sonnet, never Fable unless I explicitly ask** (its `--reviewers` flag overrides that per run); its `fix-findings` children stay pinned per that same doc's Fixer pin section.
- **Model to task**. Fable 5.1 for judgement work: planning, design, review, decisions. Sonnet for execution. Opus for reviews, refactors, or execution that needs more judgement than Sonnet gives. For effort on routine execution, run Sonnet 5 at `high`, stepping down to `medium` where quality holds; reserve `xhigh`/`max` for hard or agentic coding, or when correctness outweighs cost. Prefer per-task `/effort` over a model downgrade for routine work.
- **Fable subagents**. When a subagent runs on Fable, lever-5 prompting hygiene applies to the prompts you write for it — never demand its private step-by-step reasoning (a standing 'explain your reasoning step by step' trips Fable's `reasoning_extraction` → Opus fallback); ask for short rationale + assumptions + evidence instead. See `AGENTS.md` → "Prompting downstream models" for the full lever set.
- **Lock the contract first**. Fix shared schemas/signatures and assign non-overlapping files before fanning out.
- **Orchestrator mode dispatch**. Rule text is in AGENTS.md → "Subagent Orchestration"; only Claude mechanics here. Pass `model:` on every `Agent` call (`haiku`, `sonnet`, `opus`; `fable` for a plan or light-review seat only). Effort has no call parameter; Claude subagents (custom or built-in, including `Explore` and `general-purpose`) inherit the session effort. Research and verification go to `Explore` or `general-purpose` on Sonnet or Haiku; fixes follow the Plan → implement → review pins above; Fable seats get short-rationale prompts per "Fable subagents".
- **No writes to shared files without a merge step**.

## Codex second opinion

Codex CLI is wired in as a read-only MCP reviewer (the `codex` MCP server). Use it as a
cross-model second opinion — its strengths differ from mine, so it catches things I miss.

- Codex reviews have my standing OK. After implementing a feature or non-trivial fix, run
  `/codex-review` (or call the `codex` MCP tool on the current diff) before I commit, without
  asking first. Summarise the findings grouped by severity (HIGH / MEDIUM / LOW). I decide what
  to apply; never auto-apply findings.
- The standing OK covers reviews only. When I am stuck on a bug after ~2 attempts, suggest
  delegating the debugging context to Codex before trying a third approach, and wait for my
  go-ahead.
- The reviewer is read-only and non-interactive; it returns findings only and cannot edit
  my working tree. Applying fixes is your job (with my approval).
- `quick-review` / `deep-review` / `review-fix-loop` include Codex as a reviewer/verifier when
  its MCP is present. Council includes external Codex only with explicit `--codex`. When a run
  uses Codex, report it visibly in the run summary.

## Local machine-specific context
@~/.claude/CLAUDE.local.md
