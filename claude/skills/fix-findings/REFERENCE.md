# Fix Findings — Reference

## Linter detection

Run the linter on touched files immediately after editing inside each fixer, and a full-tree pass at
the Step 4 gate. Detect by the **file type changed**, not only by a settings file — a linter that
applies by default to a language must still run when no project settings file exists (else lint is
silently skipped and the gate misses real violations).

| Signal | Linter command |
|---|---|
| any `*.ps1`/`*.psm1`/`*.psd1` changed, `.vscode/PSScriptAnalyzerSettings.psd1` present | `Invoke-ScriptAnalyzer -Path <src-tree> -Recurse -Settings .vscode/PSScriptAnalyzerSettings.psd1` |
| any `*.ps1`/`*.psm1`/`*.psd1` changed, **no** settings file | `Invoke-ScriptAnalyzer -Path <src-tree> -Recurse` (default rules — still runs) |
| `package.json` with eslint | `npx eslint <file>` |
| `pyproject.toml` / `.flake8` | `ruff check <file>` or `flake8 <file>` |
| `Cargo.toml` | `cargo clippy` |
| no linter for the changed languages | Skip; note it in the commit message |

For PSScriptAnalyzer, run `-Recurse` over the whole source tree with the project settings file — CI
does, so a per-file run can pass while CI fails on a pre-existing violation in an untouched file. The
fix is responsible for violations its edits introduced; pre-existing violations in untouched files
(confirm with `git show HEAD:<file> | Invoke-ScriptAnalyzer ...`) are noted, not necessarily fixed.

### `lint_clean` threshold

Severity that blocks the gate is **deferred to the project's linter config** (e.g. a PSSA settings
file's configured severities, an eslint `error` vs `warn`). When a project has no config, **fall back
to error-only**: `lint_clean = no Error-severity diagnostics`. Warning/Info diagnostics are surfaced
as LOW/CLEANUP findings (reported, not gated) so the loop doesn't churn on advisory rules.

---

## Test runner detection

Run the full suite once after all fixers return (Step 4).

| Signal | Test command |
|---|---|
| `Run-Tests.ps1` in module root | `Push-Location <module-root>; .\Run-Tests.ps1 -RunPath tests\Unit; Pop-Location` |
| `pytest.ini` / `pyproject.toml` | `pytest` |
| `package.json` with `"test"` script | `npm test` |
| `Cargo.toml` | `cargo test` |
| `go.mod` | `go test ./...` |

If multiple test suites exist (e.g. both `Hollard.Permissions` and `Hollard.EntraID`), run all of them.

---

## Commit message

```
fix(<Scope>): <imperative summary> [#<finding-id>]

- <file>: <what changed and why>
- <file>: <what changed and why>
```

`<Scope>` = module / component (e.g. `Permissions`, `EntraID`, `Api`). Conventional commits. No
AI/Claude attribution, no `Co-Authored-By`, no `--no-verify`.

---

## PowerShell-specific conventions (Hollard project)

- `$null = Command` not `| Out-Null`
- `foreach ($singular in $plural)` — e.g. `foreach ($role in $roles)`
- No aligned `=` signs except inside hashtables
- Comment-based help above the `function` keyword, not inside the body
- OData filter escaping: `$escaped = $name.Replace("'", "''")`
- Splatting over backticks for multi-parameter calls
- Max line length: 115 characters
- Settings file: `.vscode\PSScriptAnalyzerSettings.psd1`
