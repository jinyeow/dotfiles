---
name: codex-review
description: "Get a read-only Codex (OpenAI) second opinion on the current code changes, as a cross-model review. Use when the user says 'codex review', 'ask codex', 'get codex's opinion', 'second opinion on this', or accepts an offer to run changes past Codex before committing. Returns findings grouped by severity; never edits files on its own."
metadata:
  author: justin
  version: "1.0.0"
---

# Codex cross-model review

Run the current changes past **Codex CLI** (OpenAI) for an independent, cross-model review.
Codex is wired in as the read-only `codex` MCP server, so it can read the repo and reason
about the diff but cannot modify the working tree. This skill gathers the diff, hands it to
Codex with review instructions, and reports back. **You** apply any fixes the user approves —
Codex only returns findings.

## When to use

- The user asks for a Codex review / second opinion, or accepts an offer to run a change past Codex.
- After implementing a feature or non-trivial fix, before committing.
- As a tie-breaker when stuck on a bug after a couple of attempts.

## Preconditions

- The `codex` MCP server must be available. If it is not, tell the user to run
  `setup.ps1 -Module codex` (Windows) or `setup.sh -m codex` (Linux/macOS) and `codex login`,
  then stop — do not silently skip the review. This registration currently only wires the
  `codex` MCP server into Claude Code (`claude mcp add`); Pi has no equivalent MCP registration
  yet, so on Pi this precondition cannot be satisfied until #208 closes that gap.

## Steps

1. **Determine scope.** Default to the uncommitted diff. Run, in the repo root:
   - `git --no-pager diff --stat` and `git --no-pager diff` for unstaged + staged work, or
   - `git --no-pager diff <base>...HEAD` if the user names a branch/PR/commit range.
   If the diff is empty, say so and stop.

2. **Call the `codex` MCP tool** with a prompt that includes:
   - The role: an independent reviewer giving a second opinion; **findings only, do not approve or block**.
   - The review criteria: the shared quality bar in [`../_shared/review-rubric.md`](../_shared/review-rubric.md) —
     Layer 1 (`AGENTS.md` conformance) is the floor; Layer 2 (thermo-nuclear structural quality) is the
     ambition. Paste its substance into the prompt (Codex does not auto-load it). Be ambitious: surface
     code-judo restructurings that delete complexity, not just local nits. (The full multi-dimension
     fan-out version of this bar lives in [`../_shared/dimensions.md`](../_shared/dimensions.md), used
     by `deep-review`; this skill is the lightweight standalone Codex pass.)
   - Instruction to tag each finding **HIGH** (blocks merge), **MEDIUM** (should fix), or **LOW** (style/preference),
     each with file:line and a one-line rationale — collapsing the rubric's 5-level scale per its mapping.
   - The diff (or the changed file paths if the diff is too large for the prompt — Codex can read the files itself).

3. **Summarise** Codex's response back to the user, grouped by severity, most severe first.
   Keep it tight. Add a one-line take on which findings you agree/disagree with and why.

4. **Apply nothing yet.** Wait for the user to choose what to fix. Apply approved fixes
   yourself following the normal TDD/error-handling conventions; re-review only if asked.

## Notes

- The reviewer runs read-only and non-interactive (pinned via `-c sandbox_mode=read-only
  -c approval_policy=never` on the MCP registration), so it will not prompt mid-review.
  Reasoning effort is pinned to `medium` there too (standalone codex stays at config.toml's `low`).
- Do not auto-apply HIGH findings. Surface everything; the human decides.
