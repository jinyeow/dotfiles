# Zellij + Windows Terminal color workarounds

Running TUIs inside **Zellij on Windows Terminal** breaks color in two ways,
because Zellij sits between the app and the terminal and mishandles parts of the
color-negotiation protocol. Two fixes are in place; both are recorded here
because the second lives *outside* this repo and would otherwise be undocumented.

## 1. Dim diff context lines — `COLORTERM=truecolor`

**Symptom:** in tools like `delta` and Claude Code, the unchanged ("context")
lines of a diff are near-invisible — dark gray on a dark pane.

**Cause:** without `COLORTERM` advertised, these tools fall back to the indexed
256-color palette, where color 8 (dark gray) renders almost the same as the dark
Zellij pane background.

**Fix:** `powershell/Microsoft.PowerShell_profile.ps1` sets
`COLORTERM=truecolor` (if not already set) so tools emit 24-bit RGB instead.

```powershell
if (-not $env:COLORTERM) { $env:COLORTERM = 'truecolor' }
```

Landed in commit `5e268ed`.

## 2. Unreadable "Write"/diff blocks in Claude Code — `theme = dark-ansi`

**Symptom:** Claude Code's `Write` and diff blocks show light text whose
highlight background is indistinguishable from the terminal background — the
block collapses into the pane and is unreadable.

**Cause:** Claude Code's default `theme: "auto"` queries the terminal's
background color via an **OSC 11** escape sequence to decide dark vs. light and
to compute its diff-highlight backgrounds. Zellij does **not** reliably forward
that query, and it mangles the resulting 24-bit highlight backgrounds, so the
highlight blends into the real pane background.

**Fix:** pin an explicit ANSI theme. The `-ansi` themes draw highlight
backgrounds from the terminal's own 16-color palette — which Zellij passes
through reliably — instead of negotiated truecolor, so contrast is guaranteed by
the Catppuccin Mocha scheme rather than by a query Zellij breaks.

```json
{
  "theme": "dark-ansi"
}
```

This is set in the repo's tracked **`claude/settings.json`**, which
`setup.ps1 -Module claude` **copies** (not symlinks) to
`~/.claude/settings.json`. Because it's a copy:

- Edit the **repo** file (`claude/settings.json`) and re-run
  `setup.ps1 -Module claude` to apply — editing only `~/.claude/settings.json`
  works until the next installer run, which overwrites it.
- Claude Code also writes to the live `~/.claude/settings.json` itself, so the
  two can drift; the repo file is the source of truth.

Use `/theme` inside Claude Code for a live preview of alternatives (`dark`,
`dark-daltonized`, …).

## Why not fix Zellij instead?

Both issues stem from Zellij not forwarding/handling terminal color queries
(notably OSC 11) under Windows Terminal. That is an upstream Zellij limitation;
advertising truecolor and using palette-based themes are the reliable
client-side workarounds.
