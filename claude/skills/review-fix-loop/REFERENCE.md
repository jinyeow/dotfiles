# Review-Fix Loop — Reference

## KANBAN.md structure

```markdown
# KANBAN — <repo> · <branch>

## To Do

### TICKET-NNN · <PRIORITY> · <title>

**File:** `path/to/file.ext`
**Lines:** NNN–NNN

**Problem:**
<what is wrong and why it matters>

**Root cause:**
<underlying mechanism>

**Fix:**
<exact code showing before/after, or step-by-step instructions>

**Tests to update:**
<test file(s) and what to add/change>

---

## In Progress

*(ticket moves here while being worked)*

---

## Done

- **TICKET-NNN** — <one-line summary> *(commit abc1234)*
```

### Priority levels

| Label | Meaning |
|---|---|
| CRITICAL | Silent data loss, unhandled termination, security |
| HIGH | Incorrect output, replication race, infinite loop |
| MEDIUM | Latent correctness bug, missing escape, wrong type |
| LOW | Wrong diagnostic message, observability gap |
| CLEANUP | Duplication, dead code, style — no correctness impact |

---

## Linter detection

Run the linter on each modified file immediately after editing it.

| Signal | Linter command |
|---|---|
| `.vscode/PSScriptAnalyzerSettings.psd1` present | `Invoke-ScriptAnalyzer -Path <file> -Settings <settings-file>` |
| `package.json` with eslint | `npx eslint <file>` |
| `pyproject.toml` / `.flake8` | `flake8 <file>` or `ruff check <file>` |
| `Cargo.toml` | `cargo clippy` |
| None found | Skip linter; note it in the commit message |

For PSScriptAnalyzer: pre-existing violations that exist in the HEAD version of the file are not your responsibility. Verify with `git show HEAD:<file> | Invoke-ScriptAnalyzer ...`. Only fix violations that your edit introduced or that are in lines you touched.

---

## Test runner detection

Run the full test suite after all tickets in a cycle are fixed.

| Signal | Test command |
|---|---|
| `Run-Tests.ps1` in module root | `Push-Location <module-root>; .\Run-Tests.ps1 -RunPath tests\Unit; Pop-Location` |
| `pytest.ini` / `pyproject.toml` | `pytest` |
| `package.json` with `"test"` script | `npm test` |
| `Cargo.toml` | `cargo test` |
| `go.mod` | `go test ./...` |

If multiple test suites exist (e.g. both `Hollard.Permissions` and `Hollard.EntraID`), run all of them.

---

## Ticket deduplication

Before adding a new ticket, check whether an identical issue already exists in KANBAN.md (any section). Match on:
1. Same file path, AND
2. Same line number ± 5, AND
3. Substantively the same summary

If a match exists — even in `## Done` — do not add a duplicate. If the Done ticket's fix was incomplete, reopen it by moving it back to `## To Do` with a note.

---

## Commit message template

```
fix(<Scope>): <imperative summary> [#<ticket>]

- <file>: <what changed and why>
- <file>: <what changed and why>
```

`<Scope>` = module or component name (e.g. `Permissions`, `EntraID`, `Api`).

Do not include AI/Claude attribution, `Co-Authored-By`, or references to the review tool.

---

## PowerShell-specific conventions (Hollard project)

- `$null = Command` not `| Out-Null` (1.5–2.2× faster)
- `foreach ($singular in $plural)` — e.g. `foreach ($role in $roles)`
- No aligned `=` signs except inside hashtables
- Comment-based help above the `function` keyword, not inside the body
- OData filter escaping: `$escaped = $name.Replace("'", "''")`
- `$script:LastAdoResponseHeaders` must be captured to a local variable immediately after `Invoke-AdoApi` returns
- `New-EntraSecurityGroup` returns the created group object — capture it; don't re-fetch via `Get-MgGroup`
- Max line length: 115 characters
- Settings file: `.vscode\PSScriptAnalyzerSettings.psd1`
