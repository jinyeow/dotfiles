# AGENTS.md — work overlay template (Azure / Hollard TSC)

> Drop this into the ROOT of an Azure work repo as `AGENTS.md`. Codex reads it natively;
> for Claude Code, add `@AGENTS.md` to that repo's `CLAUDE.md` (or rename to `CLAUDE.md`).
>
> This is an OVERLAY. General coding conventions (typing, error handling, TDD, conventional
> commits, no Co-Authored-By, etc.) come from the global `~/.codex/AGENTS.md` /
> `~/.claude/AGENTS.md` and are concatenated automatically — do not repeat them here. Keep
> this file to the Azure/Bicep/PowerShell/Pipelines specifics only.

## Project context

- **Team:** TSC Cloud Platform Engineering, Hollard
- **Stack:** Azure Bicep (IaC), Azure DevOps Pipelines (CI/CD), PowerShell (automation/tooling)
- **Architecture:** Hub-and-spoke Azure Landing Zone with a management group hierarchy
- **Source control:** Azure DevOps Git, trunk-based development with feature branches

## Bicep

- Use `existing` + `getSecret()` for cross-resource references — never hardcode IDs or secrets.
- Build deterministic IDs with `resourceId()` / `subscriptionResourceId()` / `managementGroupResourceId()` — never rely on runtime `.id` from conditional resources (causes what-if short-circuiting).
- `targetScope` on line 1. Modules in a `modules/` subdir; no inline nested deployments.
- Every parameter has an `@description()`. Prefer user-defined types over `object` where the schema is known.
- Naming: camelCase for params/variables/outputs, kebab-case for resource names.
- Validate with `az bicep build` before presenting changes. Pin module versions with `bicep snapshot` in CI.

## PowerShell

- Verb-Noun naming, approved verbs only (`Get-Verb`). `[CmdletBinding()]`, typed params, `[OutputType()]` on all public functions.
- Comment-based help (`.SYNOPSIS`/`.DESCRIPTION`/`.PARAMETER`/`.EXAMPLE`) on every public function.
- `-ErrorAction Stop` with `try/catch`; never `-ErrorAction SilentlyContinue` without explicit justification.
- Splatting (`@params`) for calls with 3+ parameters. Module layout: `Public/` + `Private/`, dot-sourced from the `.psm1`.
- Prefer `Microsoft.Graph.*` over deprecated `AzureAD` / `Az.Resources` AD cmdlets. Watch for `Microsoft.Graph.Authentication` DLL conflicts with `Az` on Managed DevOps Pools.
- Pester tests are mandatory for public functions (`*.Tests.ps1`); scaffold the test alongside the function, run `Invoke-Pester` on affected tests before presenting.

## Azure DevOps Pipelines (YAML)

- Use templates (`extends`/`stages`/`jobs`/`steps`) — no monolithic pipeline files.
- Pin task versions explicitly (`AzureCLI@2`, not `AzureCLI@*`). Variable groups for env config; never inline secrets.
- IaC stage naming: `validate` → `plan` → `deploy`. PR pipelines run `bicep build` + `what-if`; deploy pipelines run `what-if` + `deploy`.
- Trace variable resolution through the full template chain. Verify `condition:` syntax (`succeeded()`, `eq()`, var refs) and cron schedules (UTC).

## Review criteria (any author)

1. **What-if safety** — conditional resources, missing `existing`, runtime `.id` on undeployed resources.
2. **Secret exposure** — no secrets in params files, logs, or outputs; use Key Vault refs + `@secure()`.
3. **Idempotency** — re-runnable; watch `uniqueString()` misuse, timestamp-based names, non-deterministic ordering.
4. **Least privilege** — custom roles scoped minimally; no `Owner`/`Contributor` at subscription scope without justification.
5. **Policy compliance** — no conflicts with existing Azure Policy (tag gates, deny policies, allowed locations).
6. **Pipeline correctness** — template expressions resolve; environment/spoke mapping is sound; cron is correct.
7. **Test coverage** — Pester for PowerShell; parameter-validation tests for Bicep modules.

## Formatting

- Indentation: 2 spaces for Bicep/YAML, 4 for PowerShell. Soft line limit 120.
- Encoding: UTF-8 **with** BOM for PowerShell, UTF-8 without BOM for everything else. Trailing newline; no trailing whitespace.

## Git

- Branch prefixes: `feature/`, `fix/`, `chore/`. PRs reference the work item. Squash merge to main.
