# Portable critic contract

## Inputs

- `brief`: immutable artifact, decision, constraints, exclusions, and optional revision reference.
- `charter`: one perspective charter, pasted verbatim.
- `round`: `1` or `rebuttal`.
- `digest`: other seats' compact findings, rebuttal round only.

If the brief or charter is missing, return that error and stop. Work in a fresh context.
Round one is blind: do not request, infer, or receive other seats' output. Perform only
read-only fact checking and return text; never write files or persist state.

## Round one

1. Steelman the strongest version of the artifact in at most five lines.
2. Interrogate it only through the charter. Put at most one out-of-lane pointer in the
   result; do not turn it into a finding.
3. Ground each finding in an artifact quote, a repository `file:line`, or a cited
   real-world source. Label estimates and speculation. `Unknown` is valid; an unverified
   claim presented as fact is not.
4. Respect accepted constraints unless a constraint violates the charter.
5. Recommend direction, not a redesign.

Each finding states claim, `BLOCKER|MAJOR|MINOR × HIGH|MED|LOW`, assumption attacked,
evidence, and the concrete fact/test/number that would change the finding. Use BLOCKER
only when this seat says not to proceed until resolved.

## Rebuttal

Using the same brief and charter, the seat's complete prior result, and the digest, attack
or endorse at least two other findings with new evidence when at least two exist. Restate
the verdict. If it changes, name the evidence that changed it; evidence-free movement is
discounted.

## Return shape

Cap round one at approximately 40 lines and rebuttal at approximately 20 lines:

- **Seat + verdict** — `<seat> — PROCEED | PROCEED WITH CHANGES | RETHINK | KILL` and a
  one-line rationale.
- **Steelman** — round one only, at most five lines.
- **Findings** — worst first, maximum six; drop minor findings before evidence.
- **Kill-shot question** — one precise, answerable question.
- **Out of lane** — optional one-line pointer.

Return short rationale, assumptions, and evidence; never demand private step-by-step
reasoning.
