---
name: techdebt
description: Inventory non-architectural tech debt and hand approved findings to to-tickets. Use when the user wants a tech-debt sweep or asks "what debt do we have". Not for architectural/structural debt (shallow modules, tight coupling) — use improve-codebase-architecture for that.
---

# Tech Debt

Produce a **ticket-ready inventory** of non-architectural tech debt. This skill aggregates and prioritizes evidence from tools you already have — it does not reimplement them.

## Boundaries

- **Not architecture.** Shallow modules, tight coupling, and structural duplication belong to [improve-codebase-architecture](../improve-codebase-architecture/SKILL.md). If a finding is really "this needs a deepened interface," name it in the report but hand it off rather than scoping it here.
- **Not a scanner.** Read the output of existing tools (package-manager audit, linter, coverage report, clone detector) rather than re-detecting what they already detect.
- **Not a security review.** Vulnerable dependencies are flagged as a pointer ("N vulnerabilities found, run `security-review` / your audit tool") — this skill does not judge severity.

## Categories

The canonical rule for each category — what counts as debt and what to check before listing it. [TOOLS.md](TOOLS.md) maps each one to the actual stack-specific command; it does not restate these rules.

1. **Dependency health** — outdated or unsupported (deprecated/abandoned) dependencies. Vulnerable ones: count and point to an audit tool, don't triage them here.
2. **Dead code (linter-invisible tier)** — obsolete feature flags, unused shims/fallbacks, unreachable branches, dead cross-file exports the linter can't see. Skip plain unused imports/locals — that's the linter's job. Before listing, confirm it isn't reached via reflection/dynamic dispatch/DI registration.
3. **Stale debt markers** — TODO/FIXME/HACK comments that are ownerless, undated, or contradicted by the current code around them.
4. **Test debt** — skipped/quarantined/flaky tests, and behavior with real risk (error paths, money/security-relevant logic) that has no meaningful coverage. A raw coverage percentage is not a finding on its own; a skip gated on a real condition (platform, missing optional dependency) isn't either.
5. **Duplicated behavior** — copy-pasted business rules likely to drift apart. Before listing, confirm the rules are genuinely duplicated business logic, not superficially similar code. Excludes merely-similar syntax and anything whose fix is a structural redesign — hand those to `improve-codebase-architecture`.
6. **Suppressed quality failures** — `// eslint-disable`, `# noqa`, `@ts-ignore`/`#pragma warning disable`-style suppressions, disabled checks, permanently-skipped CI steps. Before listing, check the inline justification and `docs/adr/` — a suppression with a real, current reason isn't debt.
7. **Toolchain/platform obsolescence** — deprecated API usage, EOL runtimes/language versions, CI actions or base images approaching removal.
8. **Documentation/config drift** — README/docs describing commands, flags, or schemas that no longer match the executable behavior or checked-in config.

## Process

### 1. Gather evidence

Detect the repo's stack(s) from its package manifests, CI config, and linter config, then work through every category above for every detected stack — see [TOOLS.md](TOOLS.md) for the detection markers and the category → command mapping. Two categories (stale markers, suppressions) have no dedicated tool in any stack and are always evidenced by `git grep` instead — that's their real evidence source, not a fallback. The rest genuinely require a stack-specific tool; when none is configured, that category is **skipped** and carried into the "Not assessed" list in step 3 with a one-line reason. This step is done when every category has either a result or a recorded "Not assessed" reason — none silently dropped.

### 2. Verify before listing

Apply each category's before-listing check from the Categories list above — don't list a raw tool hit as a finding without it.

### 3. Present the inventory

Present findings as a prioritized numbered list, grouped by category. For each:

- **What**: one-line description
- **Where**: file(s)/path(s)
- **Evidence**: which tool/check surfaced it, or what you verified
- **Confidence**: `High` / `Medium` / `Low`
- **Impact**: one line on what it costs to leave it

End with a **Not assessed** list: every category skipped for lack of a stack tool, one line each (category + why).

Ask the user which findings to turn into tickets.

### 4. Hand off to to-tickets

Pass only the findings the user approves to [to-tickets](../to-tickets/SKILL.md) as source material — one ticket per finding or small related cluster, following its normal breakdown-and-quiz process.
