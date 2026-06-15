# Handoff — next session

> **Prior session (2026-06-15):** three unrelated items.
> 1. **Diagnosed `<leader>ff` "fzf is not a valid executable"** in nvim — root
>    cause was a **stale environment**, not config/install. fzf moved choco →
>    winget (new PATH dir) during the choco decommission, so any terminal /
>    Zellij / nvim session started *before* the PATH refresh can't see it. fzf
>    is fine (winget `junegunn.fzf 0.73.1`, on the persistent User PATH; nvim's
>    `<leader>ff` → `FzfLua files` → shells out to `fzf`). **Fix: restart the
>    session** that owns nvim. Verify inside the broken nvim with
>    `:echo exepath('fzf')` (empty = stale PATH).
> 2. **Chocolatey leftover** `C:\ProgramData\chocolatey` — deleted everything
>    except `helpers\Chocolatey.PowerShell.dll`, which is **access-denied to a
>    non-elevated shell** (owner `BUILTIN\Administrators`; sibling files deleted
>    fine, so it's file-specific permission, not a broad lock). **PENDING:** run
>    `Remove-Item -Recurse -Force 'C:\ProgramData\chocolatey'` from an
>    **elevated** pwsh (or let the SYSTEM `CleanupChocoLeftover` task clear it on
>    next boot), then confirm `Test-Path` is `False`.
> 3. **New nvim feature — shipped:** `<leader>A` source↔test alternate toggle
>    for C#/PowerShell in `nvim/lua/config/autocmds.lua` (lazy-bound to
>    `cs`/`ps1` buffers). C# uses the Microsoft/xUnit layout
>    (`src/<Proj>/Foo.cs ↔ tests/<Proj>.Tests/FooTests.cs`), PowerShell the
>    Pester mirror (`Foo.ps1 ↔ Foo.Tests.ps1`); project root resolved via
>    `vim.fs.root(abs, { '.git', '.jj' })` (`.jj` for non-colocated jj repos);
>    open-or-create with lazy dir creation on first write. 3 Codex passes (final
>    clean) + `loadfile` parse check. Committed + pushed (`4531566`).
>
> The task below (Claude settings sync) is unchanged and remains the next priority.

## Task: scheduled task/workflow to sync Claude Code settings → dotfiles

**Goal:** automatically pull the live `~/.claude` config back into the repo's
`claude/` directory so the tracked copies stop drifting.

### Why it's needed
On **Windows** the Claude config files are **copied**, not linked (file symlinks
need Developer Mode/admin, and `settings.json`/`CLAUDE.md` are self-mutating — see
`claude/README.md`). So the live files drift from the repo:
- `settings.json` — Claude Code writes `model`, `theme`, `effortLevel`, etc.
- `CLAUDE.md` — `/memory` and `#`-shortcuts can append to it.
- `skills/` — new skills can appear as real dirs in `~/.claude/skills/` (this is
  how `review-fix-loop` showed up untracked).

(On **Linux** these are symlinked, so no sync is needed there — scope this to
Windows.)

### CRITICAL design constraint — this is a MERGE, not a blind copy
A dumb live→repo copy would clobber deliberate repo decisions. Concrete example
already hit this session: the repo **pins `model: sonnet`** but the live file has
**no `model` key** — the user chose to KEEP the pin. So the sync must:
- Preserve repo-only keys the user intentionally pins (e.g. `model`).
- Pull through genuine drift (e.g. `effortLevel` medium→high).
- Likely need a small per-key merge policy / allowlist, not `Copy-Item`.

Decide the policy with the user before writing the script.

### What to sync (tracked artifacts only)
- `~/.claude/settings.json` → `claude/settings.json` (with merge policy above)
- `~/.claude/CLAUDE.md` → `claude/CLAUDE.md`
- `~/.claude/statusline-command.sh` → `claude/statusline-command.sh`
- New/changed dirs under `~/.claude/skills/` that are **real dirs** (not
  junctions back to the repo) → copy into `claude/skills/<name>/`

### Exclusions (never sync — per claude/README.md)
`.credentials.json`, `history.jsonl`, `mcp-needs-auth-cache.json`,
`stats-cache.json`, `settings.local.json`, `projects/`, session data.

### Scheduler choice — must be LOCAL
- The harness `/schedule` skill creates **remote** cloud routines — they CANNOT
  read the local `~/.claude`, so they are NOT suitable here.
- `/loop` is interactive-session-only — also not a background sync.
- Use **Windows Task Scheduler** running a PowerShell sync script committed to
  the repo (e.g. `claude/sync-from-live.ps1`). Open question: should it
  auto-commit, or just stage changes + notify for review? (Lean: stage + notify,
  given the merge policy needs occasional human eyes.)

### Open questions for the user
1. Merge policy for `settings.json` — which keys are repo-pinned (never
   overwritten from live) vs. always-pulled? (At minimum `model` is pinned.)
2. Auto-commit, or stage-and-notify only?
3. Frequency (daily? on logon? on a timer?).
4. Should the script also reconcile real-dir skills into junctions (re-run
   `setup.ps1 -Module claude`), or just copy content into the repo?

### Relevant code pointers
- `setup.ps1` → `Install-Claude` (~line 373) — current copy/junction install.
- `setup.sh` → `install_claude` (~line 211) — Linux symlink install.
- `claude/README.md` — documents the copy-vs-symlink asymmetry and drift.
