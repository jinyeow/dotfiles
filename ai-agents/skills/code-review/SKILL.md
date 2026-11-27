---
name: code-review
description: "Review the diff since a fixed point on Standards, Spec and Bugs, plus Security, Performance, Tests and Architecture lenses picked by what the diff touches. Validates every finding against the code, rates it likelihood × impact, labels it blocking or non-blocking, and ends with a merge verdict. Replaces the built-in /code-review. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to \"review since X\"."
---

Adapted from mattpocock/skills `code-review` at commit `6f7f783`; steps 1–3 and the two-axis rule come from there.

Review the diff between `HEAD` and a fixed point. Find real defects, check each one against the code, and say whether the change can merge. This skill reports findings and writes them to the findings store. `fix-findings` fixes them, and `review-to-green` runs the two in a loop.

Read these contracts before you start:

- [`../_shared/review-rubric.md`](../_shared/review-rubric.md) has the quality bar, the likelihood × impact matrix and the "Do not flag" list.
- [`../_shared/lenses.md`](../_shared/lenses.md) has each lens charter and its trigger.
- [`../_shared/findings-schema.md`](../_shared/findings-schema.md) has the record schema and the store rules.
- [`../_shared/reviewer-models.md`](../_shared/reviewer-models.md) has the reviewer models and the read-only Codex call shape.

The issue tracker should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.

```
/code-review [ref-or-range | --pr <n>]
```

The process is fixed. The user can ask in plain words to "include nits" (report LOW findings in full) or to "run all lenses" (run every conditional lens).

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point: a commit SHA, branch name, tag, `main`, `HEAD~5`, a range, or `--pr <n>`. If they gave none, use the merge-base with the default branch.

- A ref or range goes to git as given. For a range, its merge-base is the fixed point.
- For `--pr <n>` on GitHub, `gh pr view <n> --json baseRefName,headRefName` gives the refs and `gh pr diff <n>` gives the diff.
- For `--pr <n>` on Azure DevOps, `az repos pr show --id <n>` gives `sourceRefName` and `targetRefName`. Diff with `git diff <target>...<source>`.
- If the CLI for the PR is missing or not signed in, stop and say which one. Do not guess the diff.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`. Record the merge-base SHA as `base_sha` for the store.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here, not inside parallel sub-agents.

If the diff is trivial (only whitespace, generated files, lockfiles, or typo fixes in docs), say so and stop.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.), fetched via the workflow in `docs/agents/issue-tracker.md`.
2. A path the user passed as an argument.
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, skip the Spec lens and list "no spec" under Not covered.

### 3. Identify the standards sources

Search the repo for every file that documents how code should be written: `CODING_STANDARDS.md`, `CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md`, and linter configs. When `CODING_STANDARDS.md` or `CONTRIBUTING.md` exists, it must be on the list.

On top of these, the Standards lens applies the rubric: Layer 1, Layer 2, the named smell baseline and the "Do not flag" list. A documented repo standard always overrides the smell baseline.

### 4. Facts first

Run the repo's own lint, type-check and test commands that apply to the changed files. Detect them as [`../fix-findings/REFERENCE.md`](../fix-findings/REFERENCE.md) does, and add the type-checker the repo configures. Give the output to every lens as facts. A lens does not report again what a tool already reports. A failing test or type-check goes in the summary, and the change is not ready while it fails. A command that cannot run goes under Not covered.

### 5. Run the lenses in parallel

Standards, Spec and Bugs always run. Security, Performance, Tests and Architecture run when the diff matches their trigger in `lenses.md`, or when the user asks to run all lenses.

Start each lens as a fresh-context, read-only subagent, all in one message. On Codex, use `agent_type: "reviewer"`. Give each lens a curated brief:

- the diff command and the commit list;
- the spec, for the Spec lens;
- the standards files from step 3;
- the tool output from step 4;
- its charter from `lenses.md`, and the rubric.

Each lens returns its findings, at most 400 words. Each finding has `file:line`, quoted evidence, likelihood and impact (HIGH, MED or LOW, as the rubric defines them), a suggested minimal fix, and origin (`introduced` or `pre-existing`). A lens that errors or returns nothing is recorded as "not covered". It never counts as clean.

### 6. Second opinion

Check whether a reviewer from another model family is available in this session: an MCP server for another coding agent (such as `codex`), or another agent's CLI on `PATH`. If none is found, skip this step and do not mention it.

If one is found, ask the user once before step 5 whether to add a second opinion, as AGENTS.md "Second opinions from another model" says, and name what you found. On yes, run it read-only, in parallel with the lenses. Give it the diff command, the commit list, the spec and the lens briefs. For the `codex` MCP server, use the read-only call shape in `reviewer-models.md`. Its findings go through the same validation as the lenses' findings.

### 7. Dedup, then validate

Fingerprint each finding as `findings-schema.md` defines it. Merge findings that share a fingerprint and keep every member's evidence. A finding that several lenses report appears once, under its primary lens.

Then give each merged finding to a separate validation subagent: fresh context, read-only, and on Codex `agent_type: "reviewer"`. Brief it to refute the finding against the actual code. It reads the cited lines and what calls them, and returns `confirmed` or `not reproduced` with a one-line reason. When it is unsure, it returns `not reproduced`. Validators run in parallel. Keep the confirmed findings only, with `validated: true`, and record the rest in the store as `not_reproduced`.

### 8. Rate severity

Rate each confirmed finding with the likelihood × impact matrix in the rubric. An introduced finding rated HIGH or MED is blocking. A LOW finding is non-blocking. A pre-existing finding never blocks, so report it separately. When the user explicitly accepts a blocking finding as a documented trade-off, it stops blocking: record it as `wontfix` with their reason.

### 9. Report

Write the report in this order:

1. A summary paragraph: what the change does, which lenses ran, and any failing tool from step 4.
2. Blocking findings, HIGH then MED, under `## Standards`, `## Spec`, `## Bugs` and one heading for each other lens that ran. Do not merge or rerank findings across headings (see "Why separate axes"). Give each finding its `file:line`, likelihood × impact, the quoted evidence and the suggested fix, and label it blocking.
3. Non-blocking findings (LOW) as a short list, one line each. Give them in full only when the user asked to include nits.
4. Pre-existing findings, one line each.
5. Findings that only the second opinion raised, under `## Second opinion (<model>)`, labelled the same way. They count toward the verdict like any other finding.
6. Not covered: lenses skipped or failed, tools that could not run, and "no spec" when there was none.
7. The verdict line: `Ready to merge` or `Not ready: N blocking findings`.

Write every confirmed and every `not_reproduced` finding to the findings store, as `findings-schema.md` describes. You are the only writer. Subagents return text and never write the store. `review-to-green` and `fix-findings` read the store.

## Why separate axes

A change can pass one axis and fail another:

- Code that follows every standard but implements the wrong thing passes Standards and fails Spec.
- Code that does exactly what the issue asked but breaks the project's conventions passes Spec and fails Standards.

Reporting them separately stops one axis from masking the other. The same holds for Bugs and for each conditional lens.
