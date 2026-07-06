---
name: council
description: "Adversarial review council for NON-DIFF artifacts: an idea, business case, technical design or ADR, project plan, presentation, or important document. Fans out perspective critics in parallel (panel picked by artifact type: code|business|plan|doc), runs a rebuttal round, and a chair issues a verdict (PROCEED / PROCEED WITH CHANGES / RETHINK / KILL) with dissent preserved. Use when asked to 'run a council', 'red-team this idea/design/plan', 'stress-test from multiple perspectives', or 'adversarial review' of something that is not code changes. NOT for reviewing a branch diff or PR — use deep-review; NOT for fixing anything."
metadata:
  author: justin
  version: "1.0.0"
---

# Council — adversarial multi-perspective review

Convene a panel of adversarial critics over one artifact, make them rebut each other, and
have a chair synthesize a verdict. The goal is **meaningful critique, not consensus**: the
council exists to find the reasons this idea/design/plan fails, while preserving honest
disagreement instead of averaging it away.

Contracts: the seat registry + charters are
[`references/perspectives.md`](references/perspectives.md) — read it before dispatching.
The two agents are `council-critic` (one per seat) and `council-chair` (synthesis judge).

## Quick start

```
/council [panel] [target] [+seat] [-seat] [--quick]
```

- `panel` — `code` | `business` | `plan` | `doc`. Omit to auto-detect from the artifact.
- `target` — file path(s), a PR/issue/doc reference, or inline text after a colon
  (`/council business: subscription box for hot sauce`).
- `+seat` / `-seat` — add or drop seats by registry name (`+contrarian -compliance-privacy`).
  Cross-cutting seats (`contrarian`, `completeness`) are seatable on any panel; seat
  `contrarian` by default when the artifact asks a go/no-go question.
- `--quick` — skip the DEBATE round (independent critiques + chair only).

## Pipeline

```
SELECT → BRIEF → CRITIQUE → DEBATE → JUDGE → REPORT
```

You (the main loop) are the orchestrator and the **sole writer** of the report. Seats and
the chair return their output to you; they never write files. Two hard rules from the
research this design borrows (LLM Council, ChatEval): round-1 critiques are **blind** —
no seat sees another seat's output before returning its own — and rebuttals only count
when they carry **new evidence**.

### 1 — SELECT

Pick the panel: explicit arg wins; otherwise classify the artifact (technical design/ADR →
`code`; idea/business case → `business`; schedule/roadmap/migration → `plan`;
presentation/proposal/prose → `doc`). Apply `+`/`-` seats. Keep the panel ≤7 seats —
swap for diversity rather than grow.

When the **codex MCP is present**, seat it as one extra cross-model member (full-panel
lens, no single charter) — invoking `/council` is standing consent for this, the same
documented exception as `deep-review` (see `claude/CLAUDE.md`); name its inclusion in the
report. If absent, omit it cleanly.

The ≤7 cap counts **charter seats only** (codex is extra). When default-seating
`contrarian` would push a panel past the cap, swap out the least decision-relevant default
seat and say so in the panel line.

**Done when:** panel list is fixed and stated to the user (one line), before any dispatch.

### 2 — BRIEF

Assemble one context pack every seat receives identically:

- the artifact verbatim (or the file paths to read, for repo-resident artifacts);
- **the decision this review informs** and who makes it;
- constraints the author has already accepted (budget, deadline, mandated tech);
- what's explicitly out of scope.

If the decision-being-made isn't stated and can't be inferred, ask the user **one**
question before dispatching — a council can't judge an artifact without knowing what it's
for. Don't ask about anything else.

**Done when:** the brief exists as a single block you can paste into every dispatch.

### 3 — CRITIQUE (blind, parallel)

Dispatch **all seats in a single message**: one `council-critic` per seat, each prompt
containing (in order) the brief, that seat's charter **verbatim** from
`references/perspectives.md`, and the reminder that its Return shape and line cap apply.
Never include another seat's output, and never ask a seat for `step-by-step reasoning` —
short rationale + assumptions + evidence only (Fable `reasoning_extraction` guard).

The **codex seat** is not a `council-critic` dispatch: call its MCP tool directly with the
brief and the critic's Return shape as the requested output format, over the full panel's
lens. It is **round-1 only** — it does not join DEBATE (rebuttal duty binds
`council-critic` seats); its findings still enter the digest so charter seats can rebut
them, and the chair scores it like any seat.

A seat that errors or returns nothing is recorded in the report's run notes — never
silently dropped, never invented for.

**Done when:** every seat has returned (or errored visibly).

### 4 — DEBATE (skip on `--quick`)

Compile a findings digest: per seat — its verdict + top findings (id, claim, severity ×
likelihood, one-line evidence). Send back to **each** charter critic (same charter, same
brief): the digest of the *other* seats plus that seat's **own complete round-1 output**
(a rebuttal is a fresh context — the seat must see its full self, digest-form is only for
others), with its rebuttal duty: attack or endorse **at least two** findings from other
seats with *new* evidence; revising its own verdict requires stating the evidence that
moved it. Dispatch all rebuttals in a single message (parallel).

**Done when:** every seat's rebuttal is in (or its absence recorded).

### 5 — JUDGE

Dispatch `council-chair` once with: the brief, all round-1 critiques, all rebuttals (or
`--quick` note), and the seat list including any errored seats. The chair dedupes,
adjudicates disputes on evidence weight, discounts evidence-free position changes, flags
suspicious unanimity, preserves dissent, and returns the full report in its fixed shape.

**Done when:** the chair's report is back and internally consistent (verdict matches the
surviving blocker set — spot-check before publishing; if inconsistent, re-dispatch the
chair with the inconsistency named, once).

### 6 — REPORT

1. Write the chair's report verbatim to `.claude/council/<artifact-slug>-<yyyymmdd>.md`
   in the workspace (if that path already exists — a same-day re-run — append `-2`, `-3`,
   …). Keep it out of version control the same way the `handoff` skill does (via
   `git rev-parse --git-path info/exclude`, worktree-safe; skip silently outside a git
   repo) unless the user asks to commit it.
2. Relay in chat: the verdict card (verdict, confidence, one-line rationale), the
   blockers/majors count by seat, the kill-shot questions, and the dissent section —
   plus the report path. Do not re-paste the whole report into chat.

**Done when:** file written, verdict card relayed, Codex inclusion (if any) named.

## Re-running

A council re-run after revisions is a **new** review of the new artifact: fresh blind
round, new report file (date-suffixed). Reference the prior report's blockers in the brief
so seats can check whether they were actually addressed — that's the one place prior
output is allowed in.
