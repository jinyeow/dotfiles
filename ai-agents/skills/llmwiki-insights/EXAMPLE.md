# Worked example (trimmed from a real run)

Source wiki: a 48-page llmwiki over a 34-repo Azure estate, schema at `wiki/AGENTS.md` (page types
`sources/`/`concepts/`/`entities/`, staleness field `status:`, citation form `` `repo/path:line` ``).
Default three-category lens used (user asked generically what to improve/fix/automate).

## 1. Codebase improvements worth making (prioritised)

1. **Execute the accepted-but-undone ADR** — the wiki's own accepted-direction ADR
   ([[adr-simplify-adls-synapse-permissioning]]) documents three vocabularies, three copy-pasted retry
   helpers, and contradictory RBAC-vs-ACL grants on the same personas.
   *Signal: recorded-but-unimplemented status (ADR accepted, code not updated).*
   *Re-verified 2026-08-15: retry-helper duplication confirmed live in
   `ALM13.AzureModules/PSModules/Azure/Public/*`.*
2. **Bump the one repo missed by the last version-pin sweep** — pinned at `3877dd2`/tag `0.8.6`
   (2026-06-08) while the shared catalogue is at `0.9.0`; excluded from the seven-repo bump wave.
   *Signal: blast radius (spoke deployments run pre-refactor modules) + recurrence (flagged in two
   separate lint passes).*
   *Re-verified 2026-08-15 via `git ls-tree origin/main` on the pin.*

*(list continues, same shape, lower-ranked items get thinner justification)*

## 2. Bugs / failures to prioritise (by blast radius)

1. **Plaintext credential committed in a repo driving ~40 downstream spokes**, unremediated since a
   named date, replicated into two stale clones.
   *Signal: blast radius (highest in the estate) + recurrence (unresolved across multiple passes).*
   *Re-verified minutes before the report: still present on `origin/main`.*

*(each item: one-line finding, why-it-matters signal, citation, re-verify mark — never omit the mark)*

## 3. Worth automating

1. **Tag-cutting on shared repos** — the wiki's single most-repeated failure mode (one repo went 24
   days untagged through a breaking change).
   *Signal: recurrence across log entries naming the same root cause on different repos.*

## Meta: how to use this wiki (only needed when the question was about the wiki itself)

- Query flow per the wiki's own schema: index → drill into pages → follow links → verify before acting.
- Trust boundaries found while researching: which claim classes this wiki cannot currently verify
  (named explicitly, not implied).
- One line on what's cheap to automate about keeping the wiki itself current, if relevant.

## What NOT to do (anti-patterns this example avoids)

- No RICE/ICE-style numeric score — the wiki carries no Reach or Effort estimate, so none was invented.
- No item shipped without a citation and a re-verify mark, including low-ranked ones.
- Thin categories were stated as thin, not padded with filler findings to look complete.
