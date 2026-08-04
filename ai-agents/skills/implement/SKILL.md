---
name: implement
description: Implement a piece of work from a spec or set of tickets — TDD at agreed seams, review, then commit.
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Use `/tdd` where possible, at pre-agreed seams.

Run the project's fast checks (typecheck / lint / analyzer) regularly and single test files as you go; run the full test suite once at the end.

Once done, review the work: run `/code-review` (correctness and cleanups) and `/spec-review` (conformance to the ticket), with `/codex-review` in parallel for a cross-model second opinion.

Commit your work to the current branch with a conventional-commit message.
