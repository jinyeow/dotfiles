# Handoff — next session

> **Last session (2026-06-16): coding-font work COMPLETE and pushed to `origin/main`.**
> Remaining items: the Chocolatey leftover check, and the Claude settings-sync task (both below).

## Done this session (2026-06-16) — coding font → Commit Mono

- Chose **Commit Mono** after a side-by-side comparison (also weighed JetBrains, 0xProto, Geist,
  Maple). Applied across Windows Terminal, VS Code (live Settings Sync + repo snapshot) and the
  Vim GUI guifont, with a `Fira Code → monospace` fallback where supported.
- **Root cause of the earlier "all fonts render identical" bug:** `file:///` `@font-face` URLs are
  blocked cross-origin when the comparison HTML is opened directly in a browser, so every font fell
  back to default monospace. Fixed by **subsetting each font to the sample glyphs and embedding it
  as base64 woff2** → fully self-contained HTML that renders the real fonts anywhere. Windows
  Terminal was fixed live via the switch script (WT caches its font list at startup).
- **Promoted the scratch `.font-*.ps1` files into tracked tools** under `powershell/Scripts/`
  (each with comment-based help; reviewed by Codex and fixes applied):
  - `Set-CodingFont <name>` — switch the font across WT + VS Code + Vim at once
  - `Install-CodingFont <NerdFontName>` — download + per-user install + session-activate faces
  - `New-FontComparison` / `New-FontGlyphTest` / `New-FontLigatureTest` — self-contained HTML/PNG renderers
  - Generated `.font-*.html`/`.png` artifacts are now git-ignored.
- **yazi fixes:** added the `catppuccin-latte` flavor (startup error), `YAZI_FILE_ONE` → Git for
  Windows' `file.exe` for MIME detection, and a `text/html` rule so Enter opens HTML in the browser.
- Committed in 3 logical commits and pushed: `d7e1467` (yazi), `98dfbed` (font tools), `ea71c45`
  (switch to Commit Mono).
- All 9 candidate fonts remain installed per-user (`%LOCALAPPDATA%\Microsoft\Windows\Fonts` + HKCU)
  for future switching via `Set-CodingFont`.

## Pending: Chocolatey leftover

`C:\ProgramData\chocolatey\helpers\Chocolatey.PowerShell.dll` — access-denied to a non-elevated
shell (owner `BUILTIN\Administrators`). Run `Remove-Item -Recurse -Force 'C:\ProgramData\chocolatey'`
from **elevated** pwsh (or let the SYSTEM `CleanupChocoLeftover` task clear it on next boot), then
confirm `Test-Path 'C:\ProgramData\chocolatey'` is False. (Check each session until gone.)

## Pending: scheduled task/workflow to sync Claude Code settings → dotfiles

**Goal:** automatically pull the live `~/.claude` config back into the repo's `claude/` directory so
the tracked copies stop drifting.

### Why it's needed
On **Windows** the Claude config files are **copied**, not linked (file symlinks need Developer
Mode/admin, and `settings.json`/`CLAUDE.md` are self-mutating — see `claude/README.md`). So the live
files drift from the repo:
- `settings.json` — Claude Code writes `model`, `theme`, `effortLevel`, etc.
- `CLAUDE.md` — `/memory` and `#`-shortcuts can append to it.
- `skills/` — new skills can appear as real dirs in `~/.claude/skills/` (this is how
  `review-fix-loop` showed up untracked).

(On **Linux** these are symlinked, so no sync is needed there — scope this to Windows.)

### CRITICAL design constraint — this is a MERGE, not a blind copy
A dumb live→repo copy would clobber deliberate repo decisions. Concrete example: the repo **pins
`model: sonnet`** but the live file has **no `model` key** — the user chose to KEEP the pin. So the
sync must:
- Preserve repo-only keys the user intentionally pins (e.g. `model`).
- Pull through genuine drift (e.g. `effortLevel` medium→high).
- Likely need a small per-key merge policy / allowlist, not `Copy-Item`.

Decide the policy with the user before writing the script.

### What to sync (tracked artifacts only)
- `~/.claude/settings.json` → `claude/settings.json` (with merge policy above)
- `~/.claude/CLAUDE.md` → `claude/CLAUDE.md`
- `~/.claude/statusline-command.sh` → `claude/statusline-command.sh`
- New/changed dirs under `~/.claude/skills/` that are **real dirs** (not junctions back to the repo)
  → copy into `claude/skills/<name>/`

### Exclusions (never sync — per claude/README.md)
`.credentials.json`, `history.jsonl`, `mcp-needs-auth-cache.json`, `stats-cache.json`,
`settings.local.json`, `projects/`, session data.

### Scheduler choice — must be LOCAL
- The harness `/schedule` skill creates **remote** cloud routines — they CANNOT read the local
  `~/.claude`, so they are NOT suitable here.
- `/loop` is interactive-session-only — also not a background sync.
- Use **Windows Task Scheduler** running a PowerShell sync script committed to the repo (e.g.
  `claude/sync-from-live.ps1`). Open question: auto-commit, or stage changes + notify for review?
  (Lean: stage + notify, given the merge policy needs occasional human eyes.)

### Open questions for the user
1. Merge policy for `settings.json` — which keys are repo-pinned (never overwritten from live) vs.
   always-pulled? (At minimum `model` is pinned.)
2. Auto-commit, or stage-and-notify only?
3. Frequency (daily? on logon? on a timer?).
4. Should the script also reconcile real-dir skills into junctions (re-run `setup.ps1 -Module
   claude`), or just copy content into the repo?

### Relevant code pointers
- `setup.ps1` → `Install-Claude` (~line 373) — current copy/junction install.
- `setup.sh` → `install_claude` (~line 211) — Linux symlink install.
- `claude/README.md` — documents the copy-vs-symlink asymmetry and drift.
