# dispatch-implement

## Problem Statement

The user regularly wants to hand off one or more tickets to a subagent to implement, and
today does this by hand-typing "dispatch subagent(s) to `/implement` #ticketXYZ,#ticketABC"
every time — a repeated manual step with no skill backing it. `implement/SKILL.md`
(Matt Pocock-minimal: run `/tdd` at agreed seams, checks, review, commit) has no dispatch
logic and, per
[docs/adr/implement-stays-minimal-dispatch-in-wrapper-skill.md](../../docs/adr/implement-stays-minimal-dispatch-in-wrapper-skill.md),
should not gain any — folding ticket parsing, conflict judgment, and three different
per-runtime dispatch mechanisms into it would break its minimal upstream shape.

## Solution

Add a new thin wrapper skill, `dispatch-implement`, that owns everything the manual prefix
did by hand: parse one or more ticket references, decide whether they can run in parallel or
must run sequentially, pick a model and effort per ticket (or honor an explicit override), and
dispatch one subagent per ticket through whichever primitive the current runtime provides —
calling `/implement` unmodified inside each. `implement/SKILL.md` itself does not change.

## User Stories

1. As the user, I want to say `/dispatch-implement #123` and have it run in a dispatched
   subagent, so that I don't have to manually type "dispatch subagent to /implement" every
   time.
2. As the user, I want to pass multiple tickets in one call (`/dispatch-implement
   #123,#124`), so that I don't have to invoke the skill once per ticket.
3. As the user, I want tickets that don't share file/scope ownership to run in parallel
   automatically, so that independent work finishes faster.
4. As the user, I want tickets whose file/scope overlap can't be confirmed as safe to run
   sequentially instead of in parallel, so that two subagents never race on the same file.
5. As the user, I want each ticket to get a model and effort appropriate to its own size and
   difficulty by default, so that a trivial ticket doesn't cost an oversized model call and a
   hard one isn't underpowered.
6. As the user, I want to explicitly override the model and effort for a dispatch (e.g.
   "using Opus on low"), so that I can force a specific model when I know better than the
   auto-judgment.
7. As the user on Claude Code, I want my explicit model/effort override applied to the actual
   subagent dispatch call, so that the override does something real.
8. As the user on Codex CLI, I want an explicit override to be refused with a clear message
   rather than silently ignored or silently reinterpreted, so that I'm not misled into
   thinking a per-invocation override took effect when Codex CLI has no such mechanism.
9. As the user on any runtime, I want each dispatched unit to actually run `/implement`
   unmodified (TDD at agreed seams, checks, review, commit), so that dispatched work behaves
   identically to running `/implement` directly.
10. As a maintainer, I want `implement/SKILL.md` completely untouched by this change, so that
    its Matt Pocock-minimal shape is preserved and it keeps working standalone.
11. As the user on Pi, I want the skill to fall back to sequential single-session
    `/implement` calls if Pi's subagent/task dispatch mechanism isn't available or working,
    rather than fail outright.

## Implementation Decisions

- **New skill**: `ai-agents/skills/dispatch-implement/SKILL.md`, portable
  (`ai-agents/skills/`), projected to Claude Code, Codex CLI, and Pi. `disable-model-invocation:
  true` (user-invoked action skill, matching `implement`'s own frontmatter and the repo's
  other action skills).
- **Shape**: thin orchestrator, same pattern as `review-fix-loop` wrapping
  `quick-review`/`fix-findings` — it does not implement anything itself, only sequences
  dispatch and invokes `/implement`.
- **Two seams it crosses**, both existing surfaces, no new ones introduced:
  1. The runtime's dispatch primitive — Claude Code's `Agent` tool; a new
     `[agents.implementer]` table in `codex/config.toml` (same shape as the existing
     `[agents.fixer]` table: description-only spawn guidance, since per-role
     `sandbox_mode`/`mcp_servers` enforcement is unsupported at codex-cli 0.147.0 per
     `ai-agents/SKILL-OWNERSHIP.md`); Pi's subagent/task mechanism (`pi-subagents`, per
     #189 — support for the `tasks` input is contingent on the pinned version, not yet
     confirmed post-deprecation of `tasks` in favor of `workflowScript`/`runs.all(...)`).
  2. `/implement` itself, invoked once per ticket inside each dispatched unit, unmodified.
- **Ticket parsing**: accepts one or more `#ticket` references in a single invocation
  (`/dispatch-implement #123,#124`).
- **Parallel-vs-sequential judgment**: conservative. For each pair of tickets, if their
  file/scope ownership cannot be confirmed non-overlapping, treat them as conflicting and run
  sequentially rather than in parallel — matching `ai-agents/AGENTS.md`'s "Lock the contract
  first" and "No writes to shared files without a merge step" rules. False-sequential (safe,
  slower) is preferred over false-parallel (risks a real shared-file clash).
- **Model/effort selection, default**: judged per ticket by `dispatch-implement`, not fixed.
  On Claude Code, subject to the existing model pin for the implement stage of the plan →
  implement → review loop (Opus or Sonnet, never Fable, per `claude/CLAUDE.md`).
- **Model/effort selection, explicit override**: the user may specify a model/effort in the
  invocation (e.g. "using Opus on low"). Runtime-dependent:
  - **Claude Code**: honored directly — the `Agent` tool's `model` param is set per call from
    the override. No native effort param exists for Claude subagents in this harness (same gap
    already documented in `ai-agents/skills/_shared/reviewer-models.md`); an effort suffix is
    recorded but not applied, and this is stated once rather than silently dropped.
  - **Codex CLI**: refused with an actionable error, not silently ignored or reinterpreted.
    `spawn_agent`'s only confirmed parameters are `agent_type` and the task — no per-call
    model/effort field exists; the only settable knobs (`agents.default_subagent_model` /
    `agents.default_subagent_reasoning_effort`) are session-global, and mutating them per
    dispatch would affect every other subagent spawned later in the same session. This
    mirrors the precedent and rationale already recorded in
    `docs/adr/reviewers-flag-unsupported-on-codex-cli.md` for the `--reviewers` flag.
  - **Pi**: no override mechanism designed in this slice — out of scope, see below.
- **`implement/SKILL.md`**: no changes. It only ever runs standalone or inside a dispatched
  subagent; it never orchestrates or knows dispatch exists.
- **`ai-agents/SKILL-OWNERSHIP.md`**: updated to register `dispatch-implement` and its
  per-runtime projection/support status, following the existing entries' format (e.g. how
  `codex-review`'s Pi-projection caveat was recorded before #208 resolved it).

## Testing Decisions

- This is skill/prompt content (a `SKILL.md`), not executable code — there is no Pester/xUnit
  suite to write. Verification is behavioral, by prior art: `review-fix-loop`'s own
  verification approach (real invocations against real tickets, checking the resulting
  dispatch calls and outcomes) is the closest precedent in this repo, as is `codex-review`'s
  #208 implementation, which verified its precondition with a live round-trip rather than a
  mocked check.
- Verify manually against real tickets before considering this done:
  - A single-ticket invocation dispatches exactly one subagent and that subagent's result
    reflects a real `/implement` run (TDD, checks, review, commit).
  - A multi-ticket invocation with non-overlapping tickets dispatches in parallel.
  - A multi-ticket invocation with overlapping/unconfirmed tickets dispatches sequentially.
  - An explicit model/effort override on Claude Code changes the actual `Agent` tool call's
    `model` param.
  - An explicit model/effort override on Codex CLI is refused with an actionable message,
    not silently dropped.
  - `implement/SKILL.md`'s own content is byte-for-byte unchanged by this ticket (diff check).

## Out of Scope

- Any change to `implement/SKILL.md` itself.
- A per-invocation model/effort override mechanism for Codex CLI (fixed `[agents.<name>]`
  tables per model/effort combination) — not designed here; only add if the auto-judged
  default plus refusal-on-override proves insufficient in practice.
- A per-invocation override mechanism for Pi.
- Confirming or migrating Pi's `pi-subagents` `tasks` support past its current pin (tracked
  separately by #189) — `dispatch-implement` depends on whatever that mechanism currently
  supports and falls back to sequential single-session `/implement` calls if dispatch isn't
  available, rather than blocking on #189.
- A generic cross-skill `--reviewers`-style flag grammar or shared `_shared/` contract file
  for model/effort selection — this skill's judgment is internal to it, not a flag other
  skills consume.

## Further Notes

- Full decision history and rejected alternatives (bake dispatch into `/implement` directly;
  leave the prefix as a manual habit) are recorded in
  [docs/adr/implement-stays-minimal-dispatch-in-wrapper-skill.md](../../docs/adr/implement-stays-minimal-dispatch-in-wrapper-skill.md).
- Originating ticket: [jinyeow/dotfiles#207](https://github.com/jinyeow/dotfiles/issues/207).
