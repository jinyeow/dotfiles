# Source BAU RFC field values by cloning the latest matching work item, not a static template

## Status

Accepted. Governs the `rfc-bau-nsg-fw` skill (`ai-agents/skills/rfc-bau-nsg-fw/`).

## Context

The BAU firewall/NSG "Request for Change" Azure DevOps work item type requires ~30
fields at create time (the CAB template rejects a partial create). Most of these are
identical across every sampled RFC, including a handful that are org-confidential in a
public repo: two internal SharePoint SOP document URLs, a distribution-list email, and a
named colleague's personal work email (`Custom.Secondary`'s observed default).

The first design considered hardcoding all ~30 fields as a static template inside the
skill, with the confidential subset pulled from a local, gitignored values file
(mirroring `git/gitconfig-work` → `~/.gitignore-work`). That would have required a new
runtime reference mechanism, a template/example values file, and either a gating check
or an accepted risk of the skill failing loudly with no values file present.

## Decision

Instead, the skill finds the most recent BAU RFC of the exact matching scope (NSG or
firewall, assigned to the invoking user) already in Azure DevOps and clones its field
values at runtime, overriding only what must be fresh per run: title, description
(edited in place, not regenerated), deployment window, parent-work-item relation, the
PR `ArtifactLink` relation, `System.AssignedTo`, and `Custom.Primary`. Every other field —
including the SOP URLs, distribution list, and `Custom.Secondary` — is copied verbatim
from the matched prior RFC. This first version is single-scope and single-PR only: a
both-scope change, more than one linked PR, or no exact-scope prior RFC are all hard
stops rather than handled cases; any-scope fallback and both-scope/multi-PR handling are
deferred to the follow-up ticket ([jinyeow/dotfiles#129](https://github.com/jinyeow/dotfiles/issues/129)).

No confidential literal is ever written into the committed skill file, so no local
values file, template/example file, or runtime-reference mechanism is needed. There is
also no explicit machine gate: the skill only works with Hollard Azure DevOps access,
and running it without that access fails cleanly at the `az` auth step rather than
leaking anything.

## Rejected alternatives

### Static field template + externalized gitignored values file

Rejected because it requires committing an intermediate template with confidential
fields deliberately left blank/placeholder, a new runtime mechanism to merge in the
local values file, and ongoing maintenance to keep the template in sync with whatever
Azure DevOps' RFC form actually expects — all solving a problem (secret literals in the
skill file) that cloning avoids by construction.

### Cloning as a fallback only, static template as primary

Rejected as unnecessary complexity: BAU firewall/NSG RFCs are a well-established
recurring process at Hollard, so "no prior matching RFC exists" is not a realistic
first-run scenario worth designing a fallback path for.
