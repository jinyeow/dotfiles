# rfc-bau-nsg-fw

> **Superseded**: this spec covered the first version of the skill, shipped at
> `ai-agents/skills/rfc-bau-nsg-fw/` as single-scope/single-PR only. The skill was
> renamed to `rfc` (`ai-agents/skills/rfc/`) and gained both-scope handling, multi-PR
> support, and any-scope fallback in
> [jinyeow/dotfiles#129](https://github.com/jinyeow/dotfiles/issues/129). Kept here as
> the historical record of the first slice; the current behavior is documented in the
> skill file itself. Filename kept as-is — not renamed alongside the skill.

## Problem Statement

Creating a BAU (pre-approved, low-risk) "Request for Change RFC" in Azure DevOps for a
firewall or NSG rule change requires filling in roughly 30 fields in the CAB's "TSC
Change Control" project, most of which repeat unchanged across every such RFC. Doing
this by hand is slow and error-prone (a wrong picklist value or a missing field silently
rejects the create). A prototype skill (`~/.claude/skills/rfc/SKILL.md`, Claude-only,
not versioned in this repo) already automates the mechanics, but it hardcodes the
repeated field values directly in the skill file — including two internal SharePoint SOP
document URLs, a distribution-list email, and a colleague's personal work email. This
repo is public, so that file can't be imported into it as-is.

## Solution

Add a portable skill, `rfc-bau-nsg-fw`, that creates a BAU firewall/NSG RFC by finding
the most recent matching RFC already in Azure DevOps (assigned to the invoking user) and
cloning its field values as the starting point, overriding only what must be fresh for
the current change. Because the repeated field values come from an existing Azure DevOps
work item at runtime rather than from the skill file itself, no confidential value is
ever written into the committed skill — no separate secrets file, template, or gating
mechanism is needed. See
[docs/adr/rfc-bau-nsg-fw-clone-latest-instead-of-static-template.md](../../docs/adr/rfc-bau-nsg-fw-clone-latest-instead-of-static-template.md)
for the full rationale.

## User Stories

1. As the developer maintaining Hollard's firewall/NSG rules, I want to create a BAU RFC in one command, so that I don't have to hand-fill ~30 CAB fields for a routine, low-risk change.
2. As the developer, I want the skill to auto-detect whether my change is firewall-only or NSG-only from the linked PR diff, so that I don't have to classify the change myself. (Both-scope changes are a hard stop in this slice; see Out of Scope.)
3. As the developer, I want the RFC's repeated fields (SOP links, distribution list, secondary contact) sourced from my own prior RFCs rather than typed into the skill, so that no confidential value has to live in a public repo.
4. As the developer, I want the deployment window computed automatically (next full clock hour + 2h, UTC), so that I don't have to do the timezone math by hand each time.
5. As the developer, I want to review a full confirmation table — title, scope, description, deployment window, parent work item, linked PRs, and any inferred/flagged values — before anything is written to Azure DevOps, so that a mistaken field never reaches a real CAB record.
6. As the developer, I want the RFC linked to its parent work item and to every relevant PR automatically, so that traceability from PR → RFC → parent PBI is preserved without manual linking.
7. As the developer, I want the skill to report the created RFC's URL back to me, so that I can jump straight to it in Azure DevOps without searching.
8. As the developer, I want the skill to validate the created work item against the intended field table immediately after creation, so that a silently-rejected field (wrong picklist value, wrong reference name) is caught and reported rather than reported as a false success.
9. As a maintainer of this dotfiles repo who does not work at Hollard, I want `rfc-bau-nsg-fw` to fail cleanly (an Azure CLI auth error) rather than expose or require any secret if I happen to invoke it, so that the skill being present in a portable skills directory carries no confidentiality risk.
10. As the developer, I want to keep this skill scoped to BAU firewall/NSG RFCs only, so that other RFC types and non-BAU RFCs remain explicitly unimplemented rather than half-guessed.

## Implementation Decisions

- **New skill**: `ai-agents/skills/rfc-bau-nsg-fw/SKILL.md` — portable (projected to Claude, Codex, and Pi by `setup.ps1`/`setup.sh`'s existing auto-discovery of `ai-agents/skills/*`; no installer changes needed). `disable-model-invocation: true` (user-invoked only, matching the prototype and the repo's other action skills like `to-tickets`).
- **Matching the source RFC**: query Azure DevOps for BAU firewall/NSG RFCs assigned to the invoking user, most recent first, and require an exact scope match (firewall or NSG, per the scope detected for the current change). If no exact-scope match exists, that is a hard stop reported to the user — no fallback to an any-scope RFC and no fallback to a static template (BAU RFCs of this type are an established recurring process; a true first-run is not a realistic case to design around). Any-scope fallback, both-scope changes, and multi-PR RFCs are deferred to the follow-up ticket ([#129](https://github.com/jinyeow/dotfiles/issues/129)); this skill's first version is single-scope, single-PR only.
- **Cloning**: read the matched RFC's fields via `az boards work-item show --id <matchedId> -o json` and reuse them as the base field set for the new RFC.
- **Fields forced fresh on every run** (not taken from the clone): `System.Title`, `System.AssignedTo` (always the creating user), `Custom.Primary` (always the creating user), the deployment-window fields, the parent-work-item relation, and the PR `ArtifactLink` relations.
- **Description handling**: edit-in-place. Keep the cloned RFC's description text and structure; swap only the concrete specifics that changed (rule/hostname/IP details, ticket references) for the current change. Do not regenerate the description from scratch.
- **Fields copied verbatim from the clone**: everything not listed above as forced-fresh — including `Custom.Secondary`, the SOP document URLs, the distribution list, and every other static CAB field. This is the mechanism that removes confidential literals from the skill file; it must not be reintroduced as a hardcoded fallback.
- **Reused prototype logic** (already implemented and validated in `~/.claude/skills/rfc/SKILL.md` against a real created RFC, #798465): parent work item resolution (context-derived from the active PBI/PR, or asked if absent), firewall/NSG/both scope detection from linked PR diffs, deployment-window computation, the pre-write confirmation gate (full resolved field table, explicit go-ahead required, no implied confirmation), the `az devops invoke` JSON-patch creation call (required because the RFC template rejects partial creates and two static fields contain unescaped `&` that breaks `az` on Windows when passed as `--fields` args), the `ArtifactLink` relation for the linked PR (this skill handles exactly one linked PR; multiple linked PRs are a hard stop, deferred to #129), returning the created RFC's URL, and post-write validation (`az boards work-item show` diffed against the intended field table before reporting success).
- **No values file, no template/example file**: superseded by the clone-based design; do not add one.
- **No explicit gating mechanism**: the skill always loads for every runtime it's projected to. Running it without Hollard Azure DevOps access fails at the `az` authentication step with a normal CLI error — that failure is accepted as the gate, rather than adding a bespoke tenant/account check.
- **Org/project identifiers** (`https://dev.azure.com/HollardInsuranceRetail`, "TSC Change Control" project, custom field reference names) remain hardcoded in the skill — these are org-specific but not confidential, matching the prototype and the ticket's original scope decision.

## Testing Decisions

- This skill has no automated test suite — it is a prose `SKILL.md`, like every other skill under `ai-agents/skills/`, and this repo has no prior art for testing skill *content* (skills are validated by use, not unit tests).
- Validation instead happens at the mechanics level, already covered by the reused prototype logic: the post-write `az boards work-item show` diff against the intended field table (step 9 of the prototype) is the functional check that a real run produced the correct RFC, and should be preserved verbatim in the new skill.
- No repo-level test changes are expected: `tests/setup.Tests.ps1` already covers skill auto-discovery/projection generically and needs no per-skill update (confirmed in `setup.ps1:953-997`, which enumerates `ai-agents/skills/*` directories rather than naming individual skills).

## Out of Scope

- Any-scope RFC fallback, both-scope (firewall + NSG) changes, and multi-PR RFCs — this skill covers single-scope, single-PR only; hard-stopping on these cases instead of handling them is deliberate for this first version and deferred to [jinyeow/dotfiles#129](https://github.com/jinyeow/dotfiles/issues/129).
- Generalizing to other Azure DevOps orgs, or to non-BAU / non-firewall-NSG RFC types (`/rfc <description>`, `/rfc bau <other-type>`) — explicitly deferred by the prototype skill; would need its own field-pattern research against real completed RFCs of that type before templating.
- Any "search and suggest a similar prior RFC for the user to review before cloning" UX beyond deterministic latest-match selection — if that need emerges, it's a separate follow-up, not part of this skill's first version.
- A local externalized-values file or any secrets-management mechanism — superseded by the clone-based design; do not add one as a fallback path.
- An explicit machine/tenant gating check — deliberately not built; the natural `az` auth failure is the accepted gate.

## Further Notes

- Originating ticket: [jinyeow/dotfiles#127](https://github.com/jinyeow/dotfiles/issues/127), currently labeled `ready`.
- The prototype skill this replaces remains at `~/.claude/skills/rfc/SKILL.md` (not versioned in this repo) and should be treated as reference material for the reused logic (step numbers referenced above correspond to its structure), not as the thing being copied wholesale — its static-field-block design (steps 5 and part of step 7) is exactly what this spec replaces.
- Architecture rationale lives in `docs/adr/rfc-bau-nsg-fw-clone-latest-instead-of-static-template.md`; keep that ADR and this spec in sync if either changes during implementation.
