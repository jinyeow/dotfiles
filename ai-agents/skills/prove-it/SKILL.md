---
name: prove-it
description: Empirically prove a fix or feature works by diffing observed behavior between the base branch and the current branch. Use when the user wants proof a change works, not just an explanation of it.
disable-model-invocation: true
---

Do not explain why the change should work. Show that it does, by running both versions and comparing what actually happens.

## Process

1. Identify the base branch (usually the PR base or `main`) and the current branch, and the specific behavior the change claims to fix or add.

2. Design a concrete case that exercises that behavior — a specific input, command, request, or test that a human could run and check by eye. Prefer an existing test or repro the user already described over inventing a new one.

3. Run the case against the base branch first (`git stash` / `git worktree` / checkout, whichever fits the repo) and capture the actual output.

4. Run the same case against the current branch and capture the actual output.

5. Present both outputs side by side and state plainly whether they differ in the way the change claims. If they don't — the fix doesn't do what it's supposed to — say so; do not soften a null result into a partial win.

6. If no single case can prove it (behavior is probabilistic, environment-dependent, or hard to isolate), say so explicitly and propose the closest verifiable substitute rather than asserting proof you don't have.

Never claim proof from reading the diff alone — proof means both versions were actually executed.
