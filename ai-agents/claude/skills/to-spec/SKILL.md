---
name: to-spec
description: Turn the current conversation into a spec and publish it — no interview, just synthesis of what you've already discussed.
disable-model-invocation: true
---

This skill takes the current conversation context and codebase understanding and produces a spec (you may know this document as a PRD). Do NOT interview the user — just synthesize what you already know.

Resolve output location and any tracker target from repository-root `.agents/workflow.local.md` when present, otherwise repository-root `.agents/workflow.md`; run `/setup-agent-skills` if neither exists. Default: write `.claude/specs/<slug>.md` (`<slug>` = kebab-cased title, no date prefix).

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching.

2. Sketch out the deep modules you will need to build or modify, and the seams at which you'll test them. A deep module encapsulates a lot of functionality behind a simple, testable interface that rarely changes. Prefer existing seams to new ones and use the highest seam possible — the fewer seams across the codebase, the better; the ideal number is one. If new seams are needed, propose them at the highest point you can.

Check with the user that these modules and seams match their expectations.

3. Write the spec using the template below, then output it:
   - Default → write `.claude/specs/<slug>.md`.
   - If config names a tracker → publish there and apply the `spec-ready` label.

<spec-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A long, numbered list of user stories, each in the format:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

Be extensive and cover every actor and aspect of the feature — but stop when a new story only restates one you already have.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this spec.

## Further Notes

Any further notes about the feature.

</spec-template>
