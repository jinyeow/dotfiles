---
name: to-hld
description: Turn the current conversation and codebase understanding into a high-level design document — decisions plus logical mermaid diagrams, no interview. Output is markdown for docs/ or the wiki.
disable-model-invocation: true
---

# To HLD

Produce a **high-level design** — the *what and why* of an architecture: components, flows, key decisions, NFRs. Not the low-level *how* (ports, SKUs, exact rules) — that lives in code (`/to-tickets` + `bicep-tdd` + parameter/pipeline files). Do NOT interview the user; synthesize what you already know. If the design is still fuzzy, stop and run `/grill-with-docs` first.

Output location and any tracker/wiki target come from the repo's Agent-skills config — run `/setup-agent-skills` if absent. Default: `docs/design/<slug>.md` (`<slug>` = kebab-cased title, no date prefix).

## Process

1. **Explore** the repo and the decisions already recorded in `docs/adr/`. Use the project's domain glossary vocabulary throughout; link to ADRs, don't re-litigate them.

2. **Draft the architecture first** — components and responsibilities, the integration points, the one or two flows that carry the most risk, and the decisions that had real alternatives. Diagrams are **logical**: mermaid (C4-context/flowchart for structure, sequence for flows). Keep icon-rich Azure network topology to a *linked* diagram, not inline — mermaid renders it badly.

3. **Write** the doc using the template below.

4. **Output.**
   - Default → write `docs/design/<slug>.md`.
   - If config names the **Azure DevOps Wiki** (or any wiki repo) → **HITL**: present the rendered doc and the intended wiki location, and get explicit approval before committing or pushing. Never write to the wiki repo unattended.
   - Apply the `design-ready` label if publishing to a tracker.

<hld-template>
# HLD: <title>

## Context & Drivers

The problem, the business/technical driver, and who is asking for this.

## Scope

In scope / out of scope.

## Solution Overview

The chosen approach in prose — a few paragraphs a reviewer can grasp without reading code.

## Alternatives Considered

Each serious option: what it was, and why it was rejected or deferred. The option that won is the Solution Overview.

## Architecture

- **System context** — a mermaid diagram (C4-context or flowchart).
- **Components & responsibilities** — a table: component → what it owns.
- **Integration points** — upstream/downstream systems and their contracts.

## Flows

Mermaid sequence/flow diagrams for the key or riskiest scenarios.

## Key Decisions

A decision log. For each: the decision · options considered · rationale · consequences. Link to `docs/adr/` entries where they exist; promote a decision to a full ADR if it warrants one.

## Non-Functional Requirements

Availability/SLA, DR (RTO/RPO), scalability, performance, security posture.

## Cost & Sizing

Coarse resource sizing (tiers/SKUs at a high level) and the main cost drivers / rough estimate.

## Security & Network

Trust boundaries and zones (LOGICAL), the identity model, data classification. Detailed topology → a linked diagram.

## WAF & Compliance

Which Well-Architected pillars this touches and how; any regulatory/compliance constraints.

## Risks & Assumptions

Known risks, mitigations, and the assumptions the design rests on.

## Implementation

The LLD lives in the code. Point at the `/to-tickets` breakdown, `bicep-tdd`, and the parameter/pipeline files that carry the low-level detail.
</hld-template>
