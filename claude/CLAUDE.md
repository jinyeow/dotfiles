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

## Auto-memory hygiene

Auto-memory (the `~/.claude/projects/<slug>/memory/` store auto-loaded via `MEMORY.md`) is
Claude-Code-only, so keep it small and prefer a durable, discoverable home over a new memory.

- **Raise the save bar.** Before writing a memory, check whether the fact belongs somewhere
  more durable: a standing rule/convention → `claude/AGENTS.md` (shared) or `claude/CLAUDE.md`
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
