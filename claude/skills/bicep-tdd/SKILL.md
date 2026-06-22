---
name: bicep-tdd
description: "Use when authoring or changing Azure Bicep and you want it validated test-first — a local RED→GREEN loop of bicep build, bicep lint, and PSRule for Azure (WAF policy-as-code), plus Pester golden-fixture tests over the compiled ARM. Fully offline: no tenant auth, no what-if, no deploy. Does not fire for Terraform or for live-Azure tasks."
metadata:
  author: justin
  version: "1.0.0"
---

# Bicep TDD (local, offline)

Drive Azure Bicep with a **red**-green loop that never deploys, runs `what-if`, or queries
the tenant control plane — so it creates no deployment audit-log entry. The gate is three
local checks plus optional fixtures, run against source and compiled ARM on disk.

> **One network caveat.** Bicep *module restore* can reach a registry — public MCR/AVM, or a
> private ACR, which **authenticates**. Pass `--no-restore` on the gates (below) once modules
> are cached to keep the loop fully offline; PSRule's expansion shells out to the same Bicep
> CLI and inherits this behaviour.

The loop goes **red** when any gate fails; green only when all pass:

1. **compile** — `bicep build` succeeds (syntax + type errors are hard failures)
2. **lint** — `bicep lint` is clean at the repo's configured severity
3. **policy** — `Assert-PSRule -Module PSRule.Rules.Azure` passes (WAF + security rules)
4. **fixtures** (where they earn it) — Pester assertions over the compiled ARM shape

> **Out of scope — these touch the tenant.** `az deployment ... what-if`, `azd provision`,
> `New-AzResourceGroupDeployment`, deployment stacks. That's the `azure-validate` →
> `azure-deploy` path, and it leaves audit-log traces. This skill stops at compiled ARM.

> Written against **Bicep CLI 0.44** and **PSRule.Rules.Azure 1.x**. If a flag below is
> rejected, check `bicep <cmd> --help` / `Get-Help Assert-PSRule` rather than guessing.

## Prerequisites (one-time)

```powershell
bicep --version                                   # Bicep CLI must be on PATH
Install-Module PSRule.Rules.Azure -Scope CurrentUser -Force   # one-time PSGallery pull (online); or Install-PSResource
```

PSRule **shells out to the Bicep CLI** to expand `.bicep` itself — you do *not* pre-build
for the policy gate. The CLI just has to be resolvable when PSRule runs.

A repo `ps-rule.yaml` at the root turns on Bicep expansion and scopes what gets analysed:

```yaml
# ps-rule.yaml
configuration:
  AZURE_BICEP_FILE_EXPANSION: true   # expand .bicep source for analysis (needs Bicep CLI)
input:
  pathIgnore:
  - 'modules/**/*.bicep'             # modules are analysed via their callers, not directly
  - '!modules/**/*.tests.bicep'      # ...but keep test fixtures in scope
  - '.bicep-out/**'                  # don't re-analyse compiled ARM (PSRule scans files regardless of .gitignore)
```

## The loop

Write the expectation first, watch it go **red**, then write the minimal Bicep to reach
green. Where the expectation lives depends on what you're constraining:

| You're constraining… | Write the failing check as… |
|---|---|
| a syntax/type contract | nothing extra — `bicep build` is already the red gate |
| an org/WAF/security rule | a PSRule expectation (the standing rule set is usually enough) |
| a module's emitted shape | a Pester golden-fixture test over the compiled ARM (below) |

1. **RED** — Add or identify the check that currently fails. For a new resource property
   or required tag, the Pester fixture or PSRule rule should fail *before* you touch the
   `.bicep`. Run the gate and confirm it is red for the reason you expect.
2. **GREEN** — Write the minimal Bicep to pass. Re-run the gate.
3. **REFACTOR** — Extract modules/params, tidy naming; the gate stays green throughout.

Completion criterion: **every** changed `.bicep` (and any module it calls) passes all four
gates, and the fixtures you added are green for the right reason — not skipped, not green by
accident.

## Commands (PowerShell)

```powershell
# compile + lint gates — fast, run on every edit
New-Item -ItemType Directory -Force .\.bicep-out | Out-Null          # bicep won't create the outfile dir
bicep build .\main.bicep --no-restore --outfile .\.bicep-out\main.json   # red on syntax/type errors
bicep lint  .\main.bicep --no-restore   # red on errors (a warning gates only when its rule is 'error' in bicepconfig.json)

# policy gate — PSRule expands .bicep itself; -ErrorAction Stop makes a failed rule throw and fail the command
Assert-PSRule -InputPath . -Module PSRule.Rules.Azure -Format File -ErrorAction Stop

# investigate failures without throwing (detailed, per-rule output)
Invoke-PSRule -InputPath . -Module PSRule.Rules.Azure -Format File -Outcome Fail
```

`Assert-PSRule` is the **gate** — with `-ErrorAction Stop` a failed rule throws and fails the
command (→ red). `Invoke-PSRule -Outcome Fail` is the **lens** — use it to read which rule
failed and why, then fix and re-assert.

## Golden-fixture tests (the genuine test-first piece)

When a module must emit a specific ARM shape (resource present, property set, tag required),
assert it in Pester against the compiled JSON. This is the check you write *first*:

```powershell
# main.Tests.ps1
BeforeAll {
  $out = Join-Path $PSScriptRoot '.bicep-out\main.json'
  New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
  bicep build (Join-Path $PSScriptRoot 'main.bicep') --no-restore --outfile $out
  if ($LASTEXITCODE -ne 0) { throw "bicep build failed ($LASTEXITCODE)" }   # native failure doesn't throw in pwsh 7
  $script:Template = Get-Content $out -Raw | ConvertFrom-Json
}

Describe 'main.bicep' {
  It 'tags every resource with CostCentre' {
    foreach ($r in $script:Template.resources) {
      $r.tags.CostCentre | Should -Not -BeNullOrEmpty
    }
  }
  It 'provisions exactly one storage account at TLS 1.2 minimum' {
    $sa = $script:Template.resources |
      Where-Object type -eq 'Microsoft.Storage/storageAccounts'
    $sa | Should -HaveCount 1
    $sa.properties.minimumTlsVersion | Should -Be 'TLS1_2'
  }
}
```

Run with `Invoke-Pester`; adjust paths to your repo layout. Keep `.bicep-out/` out of
version control (compiled artefact).

## Triage — read the red, fix the cause

| Symptom | Gate | Fix at |
|---|---|---|
| `Error BCPnnn` | compile | Bicep source — type/reference error, never suppress |
| `Warning no-unused-params`, `prefer-interpolation`, … | lint | source, or adjust `bicepconfig.json` severity if a rule is wrong for the repo |
| `Azure.Storage.MinTLS` (and similar) failed | policy | source — satisfy the rule; suppress only with a justified `ps-rule.yaml` `suppression` and a comment |
| Pester shape assertion failed | fixture | source if the shape regressed; the test if the contract genuinely changed |

Never make a gate green by deleting its check. A suppressed PSRule rule needs a one-line
reason; a relaxed lint severity belongs in `bicepconfig.json`, not an inline ignore.

## Notes

- `bicep build` runs the linter as a side effect and emits warnings inline; `bicep lint` is
  the dedicated pass when you want lint without writing the JSON.
- PSRule auto-discovers **all** `.bicep` under the input path when expansion is on — scope it
  with `input.pathIgnore` so module files aren't double-analysed (they're covered via their
  callers).
- Keep `.bicep-out/` (and any `ps-rule.yaml`-built artefacts) gitignored.

---

PSRule for Azure is the local policy engine here — the same WAF rule set CI runs *when you
pin the same module version and options* (`ps-rule.yaml`, baseline, suppressions), executed
against compiled ARM on your machine. Bicep linting and golden fixtures are the fast inner
gates; PSRule is the deep one.
