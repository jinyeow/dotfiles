# Zellij + Windows Terminal workarounds

Running TUIs inside **Zellij on Windows Terminal** breaks several terminal
protocol features, because Zellij sits between the app and the terminal and
mishandles parts of the negotiation: **color** (OSC 11 / truecolor backgrounds)
and **keyboard/paste** (key disambiguation, bracketed paste). The color fixes
are applied in this repo; the input items below are mostly behavioural notes and
deliberately-unconfigured workarounds, recorded so the next person doesn't
re-debug them.

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

## 3. Multiline input in Claude Code (Shift+Enter / Ctrl+Enter)

**Symptom:** `Shift+Enter` and `Ctrl+Enter` don't insert a newline in the Claude
Code prompt — they either submit the message or do nothing.

**Cause:** older Windows Terminal sends a plain carriage return (`\r`) for
`Enter`, `Shift+Enter`, and `Ctrl+Enter` alike — they are indistinguishable.
Disambiguating them requires the Kitty keyboard protocol (CSI-u encoding), which
Windows Terminal only gained very recently and does not bind by default. Claude
Code's `/terminal-setup` does **not** support Windows Terminal (only
VS Code / Cursor / Alacritty / Zed), so it can't configure this either.

**Workaround (no config needed):** use the universal newline keys that work in
any terminal —

- **`Ctrl+J`** — inserts a newline.
- **`\` then `Enter`** — the backslash is consumed and a newline is inserted.

**Not configured here:** a persistent fix exists — `sendInput` keybindings in
Windows Terminal's `settings.json` that emit the CSI-u sequences
(`[13;2u` for Shift+Enter, `[13;5u` for Ctrl+Enter). It was
deliberately **not** added because it depends on a Windows-Terminal version new
enough to negotiate the Kitty protocol (otherwise the literal `[13;2u` text gets
inserted), and `Ctrl+J` is good enough. Zellij in `locked` mode passes input
straight through, so no Zellij-side change is involved either way.

## 4. Pasting a multi-line block creates multiple messages in Claude Code — `TERM`

**Symptom:** pasting multi-line text into the Claude Code prompt submits it as
several separate messages — one per line — instead of one.

**Cause:** Zellij's **native Windows build** has two input paths. With no `TERM`
set, it uses the native-console reader (`ReadConsoleInput`), which decomposes a
bracketed-paste sequence into individual key events — so every newline arrives as
a separate `Enter` and submits. The inner app never sees the `ESC[200~ … ESC[201~`
markers, so it can't tell the paste from typing. (Pasting into a plain Windows
Terminal tab *without* Zellij works fine — the bracketed paste reaches the app
intact and you get the `[Pasted text +N lines]` placeholder.) Locked mode,
`support_kitty_keyboard_protocol false`, and `Ctrl+Shift+V` do **not** help.

**Fix:** set `TERM` before launching Zellij, which switches it to the VT reader
path (termwiz's byte parser) that handles bracketed paste correctly.
`powershell/Microsoft.PowerShell_profile.ps1` sets it next to `COLORTERM`:

```powershell
if (-not $env:TERM) { $env:TERM = 'xterm-256color' }
```

The `if (-not $env:TERM)` guard is deliberate: the outer pwsh that launches
Zellij has no `TERM` (Windows doesn't set one), so this applies there; inside a
Zellij pane `TERM` is already set, so it's left untouched.

Confirmed against this exact stack (Windows 11, Windows Terminal, native Zellij,
PowerShell 7) in [zellij#3865](https://github.com/zellij-org/zellij/issues/3865).

**Fallback** for genuinely large input regardless of paste behaviour: write it to
a file and ask Claude to read it (`read E:\tmp\log.txt`) — the official
recommendation for big inputs, and it sidesteps paste entirely.

## Why not fix Zellij instead?

All of these stem from Zellij not forwarding/handling terminal protocol features
(OSC 11 color queries, Kitty-protocol key encoding, bracketed paste) under
Windows Terminal — an upstream Zellij limitation. Advertising truecolor, using
palette-based themes, and the universal-key / file-based input workarounds are
the reliable client-side answers.
