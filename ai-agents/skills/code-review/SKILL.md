---
name: code-review
description: "Review the diff since a fixed point on Standards, Spec and Bugs, plus Security, Performance, Tests, Architecture, Pipelines and Docs lenses picked by what the diff touches. Validates every finding against the code with an independent validator, rates it likelihood × impact, labels it blocking (by severity or a blocking criterion) or non-blocking, and ends with a merge verdict. Replaces the built-in /code-review. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to \"review since X\". pr-review runs it in others' PR mode."
---

Adapted from mattpocock/skills `code-review` at commit `6f7f783`; steps 1–3 and the two-axis rule come from there.

Review the diff between `HEAD` and a fixed point. Find real defects, check each one against the code, and say whether the change can merge. This skill reports findings and writes them to the findings store. `fix-findings` fixes them, and `refine-until-ready` runs the two in a loop.

Read these contracts before you start:

- [`../_shared/review-rubric.md`](../_shared/review-rubric.md) has the quality bar, the likelihood × impact matrix, the blocking rule and the "Do not flag" list.
- [`../_shared/lenses.md`](../_shared/lenses.md) has each lens charter, its trigger, and the validation pass.
- [`../_shared/findings-schema.md`](../_shared/findings-schema.md) has the record schema and the store rules.
- [`../_shared/reviewer-models.md`](../_shared/reviewer-models.md) has the reviewer models, when to escalate, and the read-only Codex call shape.

The issue tracker should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.

```
/code-review [ref-or-range | --pr <n-or-url>]
```

The process is fixed. The user can ask in plain words to "include nits" (report LOW findings in full) or to "run all lenses" (run every conditional lens).

## Others' PR mode

The default mode reviews the user's own change. Others' PR mode reviews a pull request someone else wrote. It is on when `pr-review` runs this skill, or when `--pr` targets a PR whose author is not the signed-in user (`gh api user --jq .login`, or `az account show --query user.name`). The process is the same, with these differences, each marked at its step:

- Step 2 builds the acceptance-criteria checklist from the linked work items or issues.
- Step 3 limits the convention sources to files on the target branch and the configured team standards.
- Step 4 runs the checks on the merged tree.
- Step 9 writes a report file and does not write the findings store, so `fix-findings` never fixes someone else's PR.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point: a commit SHA, branch name, tag, `main`, `HEAD~5`, a range, or `--pr <n>`. If they gave none, use the merge-base with the default branch.

- A ref or range goes to git as given. For a range, its merge-base is the fixed point.
- For `--pr <n>` on GitHub, `gh pr view <n> --json baseRefName,headRefName,headRefOid,author` gives the refs and `gh pr diff <n>` gives the diff.
- For `--pr <n>` on Azure DevOps, `az repos pr show --id <n>` gives `sourceRefName` and `targetRefName`. Diff with `git diff <target>...<source>`.
- If the CLI for the PR is missing or not signed in, stop and say which one. Do not guess the diff.
- When `pr-review` runs this skill, it passes the merge-base and the PR head commit, checked out in a review worktree. Use those.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`. Record the merge-base SHA as `base_sha` for the store.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here, not inside parallel sub-agents.

If the diff is trivial (only whitespace, generated files, lockfiles, or typo fixes in docs), say so and stop.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.), fetched via the workflow in `docs/agents/issue-tracker.md`.
2. A path the user passed as an argument.
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, skip the Spec lens and list "no spec" under Not covered.

In others' PR mode, the spec is the PR's linked work items or issues, which `pr-review` passes in: each one's title, description and acceptance criteria, plus every field change and comment made after the PR's last push, with its date and author. The Spec lens returns the acceptance-criteria checklist for them (see `lenses.md`). Before the lenses run, mark each criterion that is `after merge` by the rule in `lenses.md`, and give every lens and validator the same marked text. With no linked item, skip the checklist and list "objective unchecked: no linked work item" under Not covered.

### 3. Identify the standards sources

Search the repo for every file that documents how code should be written: `CODING_STANDARDS.md`, `CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md`, and linter configs. When `CODING_STANDARDS.md` or `CONTRIBUTING.md` exists, it must be on the list.

On top of these, the Standards lens applies the rubric: Layer 1, Layer 2, the named smell baseline and the "Do not flag" list. A documented repo standard always overrides the smell baseline.

In others' PR mode, the valid convention sources are only:

- files committed on the PR's target branch (read them with `git show origin/<target>:<path>`): a committed `AGENTS.md` or `CLAUDE.md`, a README, linter and analyzer settings, CI definitions;
- the team standards the user configured (`pr-review` passes them in);
- the linked work items.

The user's personal conventions (their own `AGENTS.md`, `CLAUDE.md`, memory and notes) are not sources there, and neither are files the PR itself adds. When the PR is in one of the user's own repositories, its committed `AGENTS.md` counts as a target-branch file.

### 4. Facts first

Run the repo's own lint, type-check and test commands that apply to the changed files. Detect them as [`../fix-findings/REFERENCE.md`](../fix-findings/REFERENCE.md) does, and add the type-checker the repo configures. A lens does not report again what a tool already reports. A failing test or type-check goes in the summary, and the change is not ready while it fails. A command that cannot run goes under Not covered.

In others' PR mode, run the target branch's current CI checks on the merged tree: merge the PR head into the target branch's tip in a temp worktree, never the review worktree, and run the checks there. A PR that predates a CI change often fails only there. Record whether the PR still merges cleanly and whether the target branch moved since the merge-base.

Write what you found to a facts file in the OS temp directory before any lens runs, and give its path to every lens and validator. It holds: the diff stats and commit list; the PR description verbatim, when there is one; the spec text; the standards sources from step 3; each command you ran with its duration, pass and fail counts and the failing names; and what `pr-review` passed in (earlier threads, gate results). Record the call, never the conclusion. A statement that something is missing, wrong or risky is a finding and stays out. Write "`GET .../checks/configurations` for the prod environment returned 0 checks", never "prod has no approval check".

### 5. Run the lenses in parallel

Standards, Spec and Bugs always run. Security, Performance, Tests, Architecture, Pipelines and Docs run when the diff matches their trigger in `lenses.md`, or when the user asks to run all lenses.

Start each lens as a fresh-context, read-only subagent, all in one message. On Codex, use `agent_type: "reviewer"`. Pick each lens's model with `reviewer-models.md`, escalation included. Give each lens a curated brief:

- the diff command and the commit list;
- the facts file from step 4;
- the spec, for the Spec lens;
- the standards files from step 3;
- its charter from `lenses.md`, and the rubric.

Each lens returns its findings, at most 400 words. Each finding has `file:line`, quoted evidence, likelihood and impact (HIGH, MED or LOW, as the rubric defines them), a blocking criterion from the rubric, a suggested minimal fix, and origin (`introduced` or `pre-existing`). A lens that errors or returns nothing is recorded as "not covered". It never counts as clean.

### 6. Second opinion

Check whether a reviewer from another model family is available in this session: an MCP server for another coding agent (such as `codex`), or another agent's CLI on `PATH`. If none is found, skip this step and do not mention it.

If one is found, ask the user once before step 5 whether to add a second opinion, as AGENTS.md "Second opinions from another model" says, and name what you found. On yes, run it read-only, in parallel with the lenses. Give it the diff command, the commit list, the spec and the lens briefs. For the `codex` MCP server, use the read-only call shape in `reviewer-models.md`. Its findings go through the same validation as the lenses' findings.

### 7. Dedup, then validate

Fingerprint each finding as `findings-schema.md` defines it. Merge findings that share a fingerprint and keep every member's evidence. A finding that several lenses report appears once, under its primary lens.

Then run the validation pass in `lenses.md`. Give each merged finding to a validation subagent that did not raise it, as a neutral claim and failure scenario, with no rating, no lens or model name, and no count of how many lenses raised it. Validators run in parallel and may run read-only commands to reproduce a claim. Each returns `CONFIRMED`, `PARTIAL`, `REFUTED` or `UNVERIFIABLE`, a corrected location when the given one is wrong, its own likelihood, impact and blocking criterion, and whether the problem is introduced or pre-existing.

Record the verdict as `validation_verdict`. Keep `CONFIRMED` findings as `confirmed`, and restate `PARTIAL` ones to the confirmed part. Record `REFUTED` findings as `not_reproduced`. Record `UNVERIFIABLE` findings as `unverified` and list them under Not covered with what was missing; never drop them silently.

### 8. Rate and decide blocking

Take each confirmed finding's likelihood, impact, blocking criterion and origin from its validator, and recompute severity with the matrix in the rubric. Apply the rubric's blocking rule: an introduced finding blocks when its severity is HIGH or MED, or when a blocking criterion holds (`spec`, `convention`, `untested-logic`, `mode-parameter`). Give each confirmed, introduced finding its disposition: `blocking`, `deferred` or `note`. A finding about docs, a comment or the PR description is always a LOW `note`. A pre-existing finding never blocks, so report it separately. When the user explicitly accepts a blocking finding as a documented trade-off, it stops blocking: record it as `wontfix` with their reason.

### 9. Report

Write the report in this order:

1. A summary paragraph: what the change does, which lenses ran, and any failing tool from step 4.
2. Blocking findings, HIGH then MED then LOW, under `## Standards`, `## Spec`, `## Bugs` and one heading for each other lens that ran. Do not merge or rerank findings across headings (see "Why separate axes"). Give each finding its `file:line`, likelihood × impact, blocking criterion, the quoted evidence and the suggested fix, and label it blocking.
3. Non-blocking findings (`deferred` and `note`) as a short list, one line each. Give them in full only when the user asked to include nits.
4. The acceptance-criteria checklist, when there is one: each criterion with its verdict and evidence, and the PR named for each `after merge` row.
5. Pre-existing findings, one line each.
6. Findings that only the second opinion raised, under `## Second opinion (<model>)`, labelled the same way. They count toward the verdict like any other finding.
7. Not covered: lenses skipped or failed, tools that could not run, `unverified` findings with what was missing, and "no spec" when there was none.
8. The verdict line: `Ready to merge` or `Not ready: N blocking findings`.

Write every confirmed, `not_reproduced` and `unverified` finding to the findings store, as `findings-schema.md` describes. You are the only writer. Subagents return text and never write the store. `refine-until-ready` and `fix-findings` read the store.

In others' PR mode, write the report to a file instead of the store: `PR-<id>-<repo>-review-<yyyy-MM-dd>.md` in the folder `pr-review` names (add `-iter<N>` on a re-review, and a suffix rather than overwrite). Add the PR's title, URL, author, source and target branches, the reviewed head commit and the target commit it merged against, the PR description verbatim, each seat's model, and the `deferred` findings in full. The next re-review compares against this file. The report may use finding IDs; posted comments never do (see `../_shared/review-comments.md`).

## Why separate axes

A change can pass one axis and fail another:

- Code that follows every standard but implements the wrong thing passes Standards and fails Spec.
- Code that does exactly what the issue asked but breaks the project's conventions passes Spec and fails Standards.

Reporting them separately stops one axis from masking the other. The same holds for Bugs and for each conditional lens.
