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

## Subagent Orchestration

- **Parallel by default**. Decompose independent work across subagents in one message; relay their conclusions, not their file dumps.
- **Model to task**. Opus for judgement (design, debugging, review), Sonnet for mechanical (renames, scaffolding, single-file edits). In `ultracode`, never let Sonnet leak onto judgement stages (find/verify/design/synthesize).
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
- **Exception — `deep-review` / `review-fix-loop`:** invoking either skill is itself standing
  consent to include Codex as a reviewer/verifier when its MCP is present, without a per-run offer.
  The offer-first rule above still governs all *ad-hoc* Codex use. When the loop uses Codex, report
  it visibly in the run summary.
