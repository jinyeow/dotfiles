---
name: spec-review
description: Review a diff for conformance to its originating spec or ticket — missing requirements, scope creep, and requirements implemented wrong. Use after implementing from a spec/ticket, or when the user asks whether the code matches what was asked for. Not for code quality (use /code-review).
---

# Spec Review

Review the diff between `HEAD` and a fixed point for **conformance to the spec or ticket it came from** — not code quality (that's `/code-review`), only: did we build what was asked?

## Process

### 1. Pin the fixed point

Use whatever fixed point the user supplies — a commit SHA, branch, tag, `main`, `HEAD~5`. If none is given, default to the merge-base with the default branch (`git merge-base HEAD main`) and say so. Confirm it resolves (`git rev-parse <point>`) and the diff is non-empty before going further:

- `git diff <fixed-point>...HEAD` (three-dot — against the merge-base)
- `git log <fixed-point>..HEAD --oneline` for the commit list

### 2. Find the spec

Locate the originating spec/ticket, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, Azure Boards `AB#123`) — fetch via the tracker in repository-root `agent-skills.md` (`/setup-agent-skills` if absent).
2. A path the user passed as an argument.
3. A spec/ticket file under `.claude/specs/`, `.claude/tickets.md`, `docs/design/`, or `docs/`.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, report "no spec available" and stop — there is nothing to conform to.

### 3. Review for conformance

Compare the diff against the spec and report, quoting the spec line for each finding:

- **Missing** — requirements the spec asked for that are absent or only partially implemented.
- **Scope creep** — behaviour in the diff the spec did not ask for.
- **Wrong** — requirements that look implemented but where the implementation doesn't match what the spec described.

Report under those three headings; if an axis is clean, say so. End with a one-line summary: counts per heading and the single worst gap. Do NOT review code quality, style, or correctness bugs unrelated to the spec — that is `/code-review`'s job.
