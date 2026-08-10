# Stack detection and tool mapping

Reference for step 1 (gather evidence). Detect stack first, then use the named command for
each category. If a cell has no command for the detected stack, or the stack itself isn't
covered below, that category is **skipped** — report it, don't fall back to `grep`.

Every category below is labeled with its evidence source:

- **Tool-backed** — a real command/report exists; read its output.
- **Grep-because-no-tool-exists** — no dedicated tool detects this class of thing in any
  stack (nobody ships a "TODO scanner"), so `git grep` *is* the correct evidence source, not
  a stand-in for one.
- **Skip when absent** — genuinely requires a specific tool (package audit, clone detector);
  with none configured, report the category as not assessed rather than approximating it.

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
only genuinely linter-invisible territory remains for the categories below.

## Category → command, by stack

### Dependency health — tool-backed, skip when absent

| Stack | Command |
|---|---|
| Node/npm | `npm outdated` |
| Node/pnpm | `pnpm outdated` |
| .NET | `dotnet list package --outdated` |
| Python (pip) | `pip list --outdated` |
| Python (poetry) | `poetry show --outdated` |
| PowerShell module manifest | `Find-Module <name>` per `RequiredModules` entry, diffed against installed version |

No package manager detected → skip, report "no package manager in this repo."

### Dead code (linter-invisible tier) — tool-assisted, hand inspection for the remainder

Run the stack's linter first — a clean run (no findings, and no rules disabled by the
project's own settings file) already rules out everything it covers. What's left after that
is genuinely linter-invisible: obsolete feature-flag branches, unreferenced exported
functions with no call site in the repo, shims left after a migration completed. Cross-check
the "unreferenced" claim before listing (see step 2 of `SKILL.md`) — a clean linter run does
not by itself prove code is unreachable via reflection/dynamic dispatch/DI.

### Stale debt markers — grep-because-no-tool-exists

`git grep -n -E "TODO|FIXME|HACK"`. There is no dedicated "TODO scanner" to defer to instead
— this is the correct evidence source, not an approximation of one.

### Test debt — tool-backed

| Stack | Command |
|---|---|
| PowerShell (Pester) | `Invoke-Pester -Configuration $config`, reading `Skipped`/`Pending` from the result object |
| Node (Jest/Vitest) | the project's `test` script with `--coverage`; the runner's own skip/todo summary |
| .NET (xUnit) | `dotnet test` output (skipped tests appear in the run summary) |
| Python (pytest) | `pytest --collect-only -m skip`, `pytest-cov` |

Read the *result*, not the source: a `-Skip`/`.skip()`/`Skip = ...` marker gated on a real
condition (platform, missing optional dependency) is not debt — only unconditional or
stale-reason skips are. A raw coverage percentage is not a finding on its own.

### Duplicated behavior — skip when absent

A clone detector if the repo already has one configured (e.g. `jscpd`, `PMD-CPD`); otherwise
skip rather than approximating with grep, per the skill's "not a scanner" boundary.

### Suppressed quality failures — grep-because-no-tool-exists (by design)

| Stack | Marker |
|---|---|
| PowerShell | `git grep -n "SuppressMessageAttribute"` |
| ESLint | `git grep -n "eslint-disable"` |
| TypeScript | `git grep -n "@ts-ignore\|@ts-expect-error"` |
| Python | `git grep -n "# noqa\|# type: ignore"` |
| C#/.NET | `git grep -n "#pragma warning disable"` |
| Any CI config | disabled/`continue-on-error: true` steps in the workflow file |

A linter's own output never lists its own suppressions — that's the point of a suppression —
so grep is the only way to find where they live; the linter run itself just confirms nothing
*unsuppressed* is failing. Cross-check each hit against `docs/adr/` and any inline
justification before listing — a suppression with a real, current reason isn't debt.

### Toolchain/platform obsolescence — tool-assisted

Read CI config directly for pinned versions (action versions, tool versions, runtime
versions) and compare against current upstream releases; flag EOL runtimes explicitly
(e.g. a language version past its support window).

### Documentation/config drift — hand inspection

No tool — compare README/doc-stated commands, flags, and file paths against what the repo's
config/scripts actually contain. Stack-agnostic by nature.
