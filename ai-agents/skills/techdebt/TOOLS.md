# Stack detection and tool mapping

Reference for step 1 (gather evidence). Detect stack first, then use the named command for
each category — the category rules themselves (what counts as debt, what to verify) live in
`SKILL.md`; this file is command mappings only.

Each category is labeled by evidence source:

- **Tool-backed** — a real command/report exists; read its output.
- **Grep-native** — `git grep` is the actual evidence source for this category in every
  stack; there is no tool to defer to instead, so this is never skipped.
- **Skip when absent** — requires a specific tool (package audit, clone detector); with none
  configured, this category goes to "Not assessed."

## Detecting the stack

Check for these markers, and note every one that's present — a repo can be multi-stack:

| Marker | Stack |
|---|---|
| `package.json` | Node/npm (or `pnpm-lock.yaml` / `yarn.lock` for the package manager variant) |
| `*.csproj` / `*.sln` / `Directory.Packages.props` | .NET |
| `pyproject.toml` / `requirements.txt` | Python |
| `*.psd1` manifest + `PSScriptAnalyzerSettings.psd1` | PowerShell |
| `*.bicep` | Bicep |
| `.github/workflows/*.yml` / `azure-pipelines.yml` | CI config (toolchain obsolescence category, any stack) |
| `stylua.toml` / `.stylua.toml` | Lua |
| repo-specific lint config invoked from CI (e.g. an explicit `shellcheck` file list) | Shell |

When CI config exists, prefer the exact command it runs over guessing an equivalent — the CI
step is the authoritative "this is how we lint/test this repo" source. If a stack has a
linter, run it before anything else: a clean run rules out everything it already covers, so
only genuinely linter-invisible territory remains for category 2.

## Category → command, by stack

### 1. Dependency health — tool-backed, skip when absent

Outdated/unsupported and vulnerable are two different commands; run both.

| Stack | Outdated/unsupported | Vulnerable (count + pointer only) |
|---|---|---|
| Node/npm | `npm outdated` | `npm audit` |
| Node/pnpm | `pnpm outdated` | `pnpm audit` |
| .NET | `dotnet list package --outdated` | `dotnet list package --vulnerable` |
| Python (pip) | `pip list --outdated` (run against the project's own venv/lockfile-resolved environment, not whatever environment happens to be active) | `pip-audit` |
| Python (poetry) | `poetry show --outdated` | `poetry audit` (via the `poetry-audit-plugin`) or `pip-audit` |
| PowerShell module manifest | `Find-Module <name>` per `RequiredModules` entry, diffed against installed version | no standard audit tool — skip |

No package manager detected → skip, report "no package manager in this repo."

### 2. Dead code (linter-invisible tier) — tool-assisted, hand inspection for the remainder

Run the stack's linter first (no findings, and no rules disabled by the project's own
settings file). What's left after that is genuinely linter-invisible: obsolete feature-flag
branches, unreferenced exported functions with no call site in the repo, shims left after a
migration completed.

### 3. Stale debt markers — grep-native

`git grep -n -E "TODO|FIXME|HACK"`.

### 4. Test debt — tool-backed

| Stack | Command |
|---|---|
| PowerShell (Pester) | `Invoke-Pester -Configuration $config`, reading `Skipped`/`Pending` from the result object |
| Node (Jest/Vitest) | the project's `test` script with `--coverage`; the runner's own skip/todo summary |
| .NET (xUnit) | `dotnet test` output (skipped tests appear in the run summary) |
| Python (pytest) | `pytest --collect-only -m skip`, `pytest-cov` |

Read the *result*, not the source: a `-Skip`/`.skip()`/`Skip = ...` marker is only debt when
its own gating condition is stale or unconditional — see `SKILL.md` category 4.

### 5. Duplicated behavior — skip when absent

A clone detector if the repo already has one configured (e.g. `jscpd`, `PMD-CPD`); otherwise
skip.

### 6. Suppressed quality failures — grep-native

| Stack | Marker |
|---|---|
| PowerShell | `git grep -n "SuppressMessageAttribute"` |
| ESLint | `git grep -n "eslint-disable"` |
| TypeScript | `git grep -n "@ts-ignore\|@ts-expect-error"` |
| Python | `git grep -n "# noqa\|# type: ignore"` |
| C#/.NET | `git grep -n "#pragma warning disable"` |
| Any CI config | disabled/`continue-on-error: true` steps in the workflow file |

A linter's own output never lists its own suppressions, so grep is the only way to find
where they live; the linter run itself just confirms nothing *unsuppressed* is failing.

### 7. Toolchain/platform obsolescence — tool-assisted

Read CI config directly for pinned versions (action versions, tool versions, runtime
versions) and compare against current upstream releases; flag EOL runtimes explicitly
(e.g. a language version past its support window).

### 8. Documentation/config drift — hand inspection

No tool — compare README/doc-stated commands, flags, and file paths against what the repo's
config/scripts actually contain. Stack-agnostic by nature.
