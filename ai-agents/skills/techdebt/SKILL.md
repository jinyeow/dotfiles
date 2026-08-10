---
name: techdebt
description: Inventory non-architectural tech debt (deps, dead code, stale TODOs, test debt, duplication, suppressed checks, toolchain drift, doc/config drift) and hand approved findings to to-tickets. Use when the user wants a tech-debt sweep, asks "what debt do we have", or runs /techdebt. Not for architectural/structural debt (shallow modules, tight coupling) — use improve-codebase-architecture for that.
---

# Tech Debt

Produce a **ticket-ready inventory** of non-architectural tech debt. This skill aggregates and prioritizes evidence from tools you already have — it does not reimplement them.

## Boundaries

- **Not architecture.** Shallow modules, tight coupling, and structural duplication belong to [improve-codebase-architecture](../improve-codebase-architecture/SKILL.md). If a finding is really "this needs a deepened interface," name it in the report but hand it off rather than scoping it here.
- **Not a scanner.** Read the output of existing tools (package-manager audit, linter, coverage report, clone detector) rather than re-detecting what they already detect. If a category's tool isn't available in this repo, say so and skip it — don't hand-roll a weaker version.
- **Not a security review.** Vulnerable dependencies are flagged as a pointer ("N vulnerabilities found, run `security-review` / your audit tool") — this skill does not judge severity.

## Categories

For each, prefer reading an existing tool's output over inspecting code directly:

1. **Dependency health** — outdated or unsupported (deprecated/abandoned) dependencies, via the project's package manager (`npm outdated`, `dotnet list package --outdated`, etc.). Vulnerable ones: count and point to an audit tool, don't triage them here.
2. **Dead code (linter-invisible tier)** — obsolete feature flags, unused shims/fallbacks, unreachable branches, dead cross-file exports the linter can't see. Skip plain unused imports/locals — that's the linter's job.
3. **Stale debt markers** — TODO/FIXME/HACK comments that are ownerless, undated, or contradicted by the current code around them.
4. **Test debt** — skipped/quarantined/flaky tests, and behavior with real risk (error paths, money/security-relevant logic) that has no meaningful coverage. A raw coverage percentage is not a finding on its own.
5. **Duplicated behavior** — copy-pasted business rules likely to drift apart. Excludes merely-similar syntax and anything whose fix is a structural redesign — hand those to `improve-codebase-architecture`.
6. **Suppressed quality failures** — `// eslint-disable`, `# noqa`, `@ts-ignore`/`#pragma warning disable`-style suppressions, disabled checks, permanently-skipped CI steps. Check `docs/adr/` first — a suppression an ADR explicitly accepted isn't debt, it's a recorded decision.
7. **Toolchain/platform obsolescence** — deprecated API usage, EOL runtimes/language versions, CI actions or base images approaching removal.
8. **Documentation/config drift** — README/docs describing commands, flags, or schemas that no longer match the executable behavior or checked-in config.

## Process

### 1. Gather evidence

Detect the repo's stack(s) from its package manifests, CI config, and linter config, then run or read each category's actual tool output for that stack — see [TOOLS.md](TOOLS.md) for the detection markers and the category → command mapping. A category with no available tool for this stack is **skipped**, not approximated with grep — carry it into the "Not assessed" list in step 3 with a one-line reason.

### 2. Verify before listing

Don't list a raw tool hit as a finding. For dead code, confirm it isn't reached via reflection/dynamic dispatch/DI registration before calling it dead. For suppressions, check ADRs. For duplication, confirm the rules are genuinely duplicated business logic, not superficially similar code.

### 3. Present the inventory

Present findings as a prioritized numbered list, grouped by category. For each:

- **What**: one-line description
- **Where**: file(s)/path(s)
- **Evidence**: which tool/check surfaced it, or what you verified
- **Confidence**: `High` / `Medium` / `Low`
- **Impact**: one line on what it costs to leave it

End with a **Not assessed** list: every category skipped for lack of a stack tool, one line each (category + why).

Ask which findings to turn into tickets — don't assume "all of them."

### 4. Hand off to to-tickets

For the findings the user approves, pass them as the source material to [to-tickets](../to-tickets/SKILL.md) — one ticket per finding or small related cluster, following its normal breakdown-and-quiz process. Do not draft tickets directly in this skill.
