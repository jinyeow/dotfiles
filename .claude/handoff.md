# Handoff — next session

> **Last session (2026-06-16): coding-font work + Claude config-sync both COMPLETE.**
> No pending tasks. (Chocolatey leftover is gone — cleared.)

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

## Done this session (2026-06-16) — Claude config drift, solved by symlinking

The planned live→repo *sync task* was dropped in favour of eliminating drift at the source:
`setup.ps1 → Install-Claude` now **symlinks** `settings.json`, `CLAUDE.md`, `AGENTS.md` and
`statusline-command.sh` into `~/.claude` (was copy), so live == repo and there is nothing to sync.
Skills stay junctioned. Needs **Developer Mode** for the file symlinks (confirmed on; non-elevated
symlink creation works). Per user choice, the `model` pin was removed from `claude/settings.json`
(picked per session via `/model`) — with a symlink the repo file can't diverge from live, so a pin
made no sense.

- New `New-FileSymlink` helper in `setup.ps1` (mirrors `New-Junction`: idempotent, `-Backup` skips).
- `claude/README.md` + root `CLAUDE.md` updated (symlink, no drift).
- Old live copies were backed up to `~/.claude/*.bak.<timestamp>` by the relink — safe to delete
  once happy (or `setup.ps1 -CleanBackups`).
- **Watch item:** verify Claude Code writes `settings.json` *in place* (not write-temp-rename, which
  would replace the symlink with a plain file and silently reintroduce drift). Linux has symlinked
  these for ages without issue, so in-place write is likely — but confirm on Windows by changing a
  setting via `/config` and checking the repo file updated and the link survived.
