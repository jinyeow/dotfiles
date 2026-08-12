# Claude Code — global user instructions

@AGENTS.md

The shared coding conventions live in `AGENTS.md` (imported above), so Claude Code and
Codex CLI follow the same rules. Everything below is Claude-specific.

## Claude Code Workflow

- Read the existing code and relevant `CLAUDE.md` files before editing
- Keep changes minimal and related to the current request
- Match the existing style of the repository even if it differs from my personal preference
- Do not revert unrelated changes
- If you are unsure, inspect the codebase instead of inventing patterns
- When project instructions include test or lint commands, run them before finishing

## Code intelligence tools

For code navigation and edits, split by capability — but the built-in `LSP` tool only covers
what has a language-server *plugin* actually enabled (`claude plugin list`), which today is
just `csharp-lsp` and `lua-lsp`. There is no marketplace plugin for PowerShell, Python, Go,
TypeScript, Zig, Gleam, or Bicep, so `LSP` errors outright on those files — Serena's read tools
are the only working option there, not a redundant fallback. This is documentation-only
guidance, not a `permissions.deny` block: a hard block would need to be file-extension-aware
(a `PreToolUse` hook), since blocking Serena's read tools globally would leave those languages
with no working read path at all.

- **Reading, `.cs`/`.lua` files**: prefer the built-in `LSP` tool (go-to-definition,
  find-references, hover, symbol overview, call hierarchy) — no separate process, no
  downloaded binaries. Serena's equivalent read tools (`find_symbol`, `find_declaration`,
  `find_referencing_symbols`, `find_implementations`, `get_symbols_overview`) are redundant
  there.
- **Reading, everything else** (PowerShell, Python, Go, TypeScript, Zig, Gleam, Bicep, …):
  no `LSP`-tool backend exists — use Serena's read tools.
- **Editing** (symbol-scoped rename/replace/insert/delete), any language: use Serena's
  `rename_symbol`, `replace_symbol_body`, `insert_before_symbol`, `insert_after_symbol`,
  `safe_delete_symbol` — the built-in `LSP` tool has no edit operations. Trust level is
  language-dependent (checked 2026-08-12): reliable on **C#**, **PowerShell**, **Python**;
  treat **Go**/**TypeScript** results with suspicion (both have had Windows-specific
  silent-failure issues upstream — an empty result can mean the backend died, not that
  there's nothing to find); never use on **Zig** (its `zls` backend hard-errors on Windows);
  **Bicep** has no Serena backend at all.
- **Always re-diff after a Serena edit** before treating it as done — its issue tracker
  documents cases where a rename reports success while silently omitting edits in files
  that weren't already open.
- `get_diagnostics_for_file`, `search_for_pattern`, `read_file`, `list_dir`, `find_file`,
  `replace_content`, `replace_in_files`, `create_text_file`, and Serena's project-memory
  tools (`write_memory`/`read_memory`/`list_memories`) have no `LSP`-tool equivalent and
  stay available regardless of language.
- Only the user-scope `serena` MCP (from `setup.ps1 -Module serena`, tools namespaced
  `mcp__serena__*`) is installed — the plugin-managed `serena@claude-plugins-official`
  duplicate was uninstalled (2026-08-12) after it turned out to be the actual source of
  cross-repo startup errors: its live `git+main` pull had migrated Serena's project-config
  schema (`languages:` → `language_servers:`) ahead of the pinned `uv tool install`
  (v1.6.1), so any `.serena/project.yml` the plugin last touched fatal-errored the pinned
  server with `KeyError: 'languages'` on activation — not scoped to one project, since
  `--project-from-cwd` loads the whole global registry (`~/.serena/serena_config.yml`) on
  every startup, so one stale entry broke every directory. Fixed by adding both keys to the
  affected `project.yml` files; if a `KeyError` on activation recurs, check the file's schema
  against both key names before assuming the install is broken.

## Subagent Orchestration

See `AGENTS.md` → "Subagent Orchestration" for the tool-agnostic parallel-dispatch default; the rest below is Claude Code-specific.

- **Plan → implement → review loop**. Non-trivial changes run this loop, each stage dispatched to a fit-for-purpose subagent: **plan** — a Fable subagent is fine; **implement** — Opus or Sonnet subagents, never Fable; **review** — a Fable subagent for a light pass, or the `council` skill with Opus/Sonnet seats for a thorough one. The **`review-fix-loop`** reviews on **Opus or Sonnet, never Fable unless I explicitly ask** (its `--reviewers` flag overrides that per run), and its `fix-findings` children run on **Opus 4.8/4.7/4.6 or Sonnet 5 (or lower) — never Opus 5, never Fable**, for now. This is the general default; `ultracode` is the stricter override below.
- **Model to task**. Sonnet is the current pinned default (`settings.json`). Reach for Opus per-task via `/model` for judgement work (design, debugging, review) and Fable for routine/fast work; keep Opus for security/CTF/biology — those domains are fallback-prone. Prefer per-task `/effort` over a model downgrade for routine work. In `ultracode`, never let Sonnet or Fable leak onto judgement stages (find/verify/design/synthesize).
- **Fable subagents**. Subagents often run Fable even under the pinned main-loop model, so lever-5 prompting hygiene applies to the prompts you write for them — never demand their private step-by-step reasoning (a standing 'explain your reasoning step by step' trips Fable's `reasoning_extraction` → Opus fallback); ask for short rationale + assumptions + evidence instead. See `AGENTS.md` → "Prompting downstream models" for the full lever set.
- **Lock the contract first**. Fix shared schemas/signatures and assign non-overlapping files before fanning out.
- **Orchestrator stays lean**. Don't redo an agent's work — integrate and verify once at the end.
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
