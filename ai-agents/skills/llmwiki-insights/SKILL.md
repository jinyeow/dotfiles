---
name: llmwiki-insights
description: Read an LLM-maintained wiki (Karpathy's LLM Wiki pattern — raw sources / wiki / schema) and synthesize prioritized, actionable findings about the subject matter it documents. Use when the user asks what to improve, what's broken, what to prioritise, or what's worth automating, based on an llmwiki/second-brain they maintain — not for reading a codebase directly (see techdebt / improve-codebase-architecture), and not for the wiki's own structural lint (contradictions, orphans, staleness — that's the wiki's own AGENTS.md "Lint" operation).
---

# LLM Wiki Insights

Turns an accumulated llmwiki into a **prioritized, actionable** report — not a summary, not a
structural health check. No published tool does this end-to-end as of 2026-08 — this skill combines two
separately-established patterns: the wiki's own lint (structural integrity) and a scoring/synthesis
layer borrowed from tech-debt-audit tooling, applied here to wiki *content* instead of source code.

**Boundary**: this reads the wiki, not the underlying repos directly (beyond the re-verify step below).
For a direct codebase sweep with no wiki in the loop, use `techdebt` (non-architectural debt) or
`improve-codebase-architecture` (structural). For the wiki's own contradictions/orphans/staleness, run
its own schema's Lint operation, not this skill.

## Step 0: Locate the wiki and its schema

Find the wiki root: a directory holding an `index.md`, a `log.md`, and a schema file (commonly
`AGENTS.md` or `CLAUDE.md` — Karpathy's gist calls this "the schema"). If the user names a path, use
it; otherwise look for one in or near the current working directory. If none is found, stop and ask —
don't assume a layout.

**Read the schema file in full before anything else.** Every wiki instance defines its own
conventions — page-type folders, frontmatter field names, staleness-detection method, log format. Do
not hard-code assumptions from any wiki you've analyzed before (e.g. `sources/`/`concepts/`/`entities/`
folder names, a `status:` or `timestamp:` field) — extract these from *this* wiki's own schema. Record,
for use in later steps:
- the page-type directories and what each type means
- the frontmatter field that marks staleness/currency (name varies)
- the log file's entry format (for the write-back in step 5)
- the wiki's own citation convention (so findings cite the same way the wiki does)

Completion: you can name this wiki's page-type folders, its staleness field, and its log format without
re-opening the schema file.

## Step 1: Read the corpus

Read `index.md` first — it's the catalog. Then every page under each page-type directory the schema
named, plus any top-level overview/architecture pages. Read the tail of `log.md` too: recent lint and
ingest entries often already name defects, gaps, and open items — free signal, don't re-derive it.

For a wiki with enough pages that one linear read would blow the context budget, fan this out: dispatch
parallel reader passes over disjoint page sets, using whatever your runtime provides for that (a
subagent/task-dispatch mechanism, or parallel tool calls) — the point is breadth without single-context
overflow, not any specific tool. Each reader returns citations, not just conclusions.

Completion: every page in every page-type directory has been read (by you or a dispatched reader), and
you can point to where each candidate finding came from.

## Step 2: Score, don't just list

Do not invent numeric inputs the corpus doesn't carry — a wiki has no Reach or Effort estimate, so
RICE/ICE-style scoring is fabrication here, not rigor. Rank instead on signals the wiki actually
records:

- **Blast radius** — how many other pages/repos/tiers `[[link]]` to or depend on the thing in question.
  A finding on a page ten other pages reference outranks one on an orphan.
- **Recorded-but-unimplemented status** — the wiki's own staleness/status field reading
  "proposed"/"needs-verification"/equivalent, or an ADR-type page whose decision isn't reflected in the
  cited code yet.
- **Recurrence** — a finding re-flagged across multiple `log.md` entries outranks one seen for the
  first time; grep the log for repeat mentions of the same page/claim before scoring.

Group findings into whatever categories the user asked for (e.g. improvements / bugs-failures /
automation candidates) or, absent a specific ask, use those three as the default lens — they cover
"what's wrong with the code," "what's actively broken," and "what's manual toil that repeats." Within
each category, order by the signals above, highest first.

Completion: every finding kept for the report has at least one of the three signals named explicitly,
not just a severity adjective.

## Step 3: Re-verify the top findings against live sources

The wiki is a cache, not truth — its own schema says so. Before a finding lands in the final report,
re-check it against whatever the wiki cites (the live repo, the live config, the live resource) for at
least the top-ranked items in each category — don't ship a wiki claim you haven't confirmed still
holds. Where you can't re-verify (no access, would require fabricating a check), say so as a caveat on
that finding rather than silently keeping the wiki's confidence level.

Completion: every top-ranked finding in the report is marked either "re-verified <date>" or "not
re-verified: <reason>" — no finding ships unmarked.

## Step 4: Write the report — external, not into the wiki

Findings are point-in-time analysis, not durable architecture — most wiki schemas explicitly say
durable content belongs in the wiki and point-in-time status does not (check this wiki's own schema for
that rule; if it states one, follow it). Write the report as a dated file **outside** the wiki's own
page-type directories: alongside wherever this repo already keeps this kind of cross-cutting note (a
`reports/`, `research/`, or `brain/` convention if one exists — check before picking a location), or ask
the user where to put it if none does.

Report structure — see [`EXAMPLE.md`](EXAMPLE.md) for a worked one from a real run:
- One prioritized list per category, highest-signal item first.
- Each item: one-line finding, why it matters (which signal from step 2 drove its rank), its wiki
  citation, and its re-verification mark from step 3.
- A short "how to use this wiki" section if the user's question was about the wiki itself, not just its
  contents.
- State plainly when a category came up thin — don't pad it to look complete.

Completion: the report file exists, every item is citation-and-signal-tagged, and no category was
padded to hide thinness.

## Step 5: Point the wiki back at the report

Append one entry to the wiki's own `log.md`, in the wiki's own log format, naming the report's path and
a one-line summary of what it covers. This is the only wiki-internal write this skill makes — it lets
the next lint or insights pass know one already ran, and gives anyone reading the wiki a pointer to the
analysis. Do not edit any other wiki page.

Completion: one new `log.md` line exists, correctly formatted, naming the report path.

## Step 6: Offer next steps

If the host repo has a tickets/backlog skill (e.g. `to-tickets`, a project's own board-triage command),
offer to hand approved findings to it — one item or small cluster at a time, per that skill's own
process. Don't auto-create tickets; ask which findings the user wants turned into work first.
