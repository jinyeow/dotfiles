---
name: review-fix-loop
description: Iterative review-fix cycle for a branch or PR. Runs a code review, logs each finding as a KANBAN ticket, implements the fixes, runs tests and linter, commits, then loops until the review passes clean or the user sends a stop message. Use when asked to "review and fix", "fix all issues", "clean up the branch", "iterative review loop", "review until no issues", or "keep fixing until clean".
---

# Review-Fix Loop

## Quick start

```
/review-fix-loop [kanban-path]
```

`kanban-path` — path to KANBAN.md. If omitted, search upward from the git repo root; create one at the repo root if not found. The user may supply a specific path in their message (e.g. `E:\...\TSC Cloud Platform Engineering\KANBAN.md`).

---

## Loop

Repeat until the review returns no findings, or the user sends any message:

```
REVIEW → KANBAN → FIX → TEST → COMMIT → repeat
```

### Step 1 — Review

Invoke the `code-review` skill on the current branch diff.
- Use effort `high` for the first cycle, `medium` for subsequent cycles.
- Collect all findings as a JSON array.
- If findings list is empty → exit loop cleanly.

### Step 2 — KANBAN update

Read the existing KANBAN.md. Find the highest existing `TICKET-NNN` number; new tickets start from `NNN+1` (or `TICKET-001` if none exist).

Add each finding as a ticket under `## To Do`. See [REFERENCE.md](REFERENCE.md) for the exact ticket format.

Do not duplicate tickets that are already present (match on file + line + summary).

### Step 3 — Fix

Work through every `## To Do` ticket in priority order (CRITICAL → HIGH → MEDIUM → LOW → CLEANUP):

For each ticket:
1. Move it to `## In Progress` in KANBAN.md.
2. State a one-sentence "why" before every file edit (the defect being fixed or invariant being enforced).
3. Apply the fix. Use splatting over backticks; `foreach ($singular in $plural)`; no aligned `=` outside hashtables.
4. Run the linter (see [REFERENCE.md](REFERENCE.md) for detection logic). Fix any violations introduced by the edit before moving on.
5. Move the ticket to `## Done` in KANBAN.md.

If a ticket's fix depends on another ticket (noted in the ticket body), fix the dependency first.

### Step 4 — Test

After all tickets for this cycle are fixed, run the full test suite. See [REFERENCE.md](REFERENCE.md) for test runner detection.

- All tests must pass before committing.
- If tests fail: diagnose, fix, re-run. Update the relevant KANBAN ticket if the fix was incomplete.
- Do not commit with a failing test suite.

### Step 5 — Commit

Stage only the files changed by the fixes. Write a commit message that:
- Uses `fix(Scope): ...` prefix
- Lists each logical change as a bullet
- Does not mention AI, Claude, or this skill
- Does not include `Co-Authored-By`

Then return to Step 1.

---

## Exit conditions

- Review returns zero findings → print a one-line "Review clean — no findings." and stop.
- User sends any message during the loop → stop after the current step completes cleanly.

---

## Notes

- One logical unit per commit — do not bundle unrelated fixes.
- Never skip or suppress linter rules to make the check pass; fix the underlying issue.
- Never commit with `--no-verify`.
- Working docs (KANBAN.md, HANDOFF.md) live outside the repo — do not commit them.
