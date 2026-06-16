# Handoff — next session

> **Last session (2026-06-16/17): subagents framework + `pwsh-implementer` shipped & pushed.
> 2026-06-17: `jj` skill + `powershell-module-architect` agent shipped (below). No pending task.**

## Done this session (2026-06-17) — jj skill + module-architect agent

Implemented the queued plan (`.claude/plans/agents-jj-skill-and-module-architect.md`). Both
files were **Codex-reviewed** (A before writing, B after) and findings applied.

- **Part A — `claude/skills/jj/SKILL.md`** (new): self-authored Jujutsu workflow skill,
  Windows/pwsh-native, conventional-commits aware. Codex caught that the draft was written
  against stale jj knowledge — **verified every command against the installed jj 0.42** and
  fixed: `jj rebase -o` (not `-d`, renamed to `--onto/-o`); `jj new` does *not* open an editor
  (only `describe`/`commit` do, and `squash` only when combining descriptions); `jj split` is
  interactive *by default* (prefer `jj restore --from/--into`); softened "nothing is ever lost"
  (pushes aren't un-pushed by `jj undo`) and "elevated permission" → auth/passphrase.
  Pinned a "written against jj 0.42" note. Attribution: structure/Description-Check-Protocol
  adapted from HotThoughts/jj-skills (MIT).
- **Part B — `claude/agents/powershell-module-architect.md`** (new): module *design/review*
  companion to `pwsh-implementer` (architect owns layout/manifest/structure; implementer owns
  TDD behaviour). Codex fixes applied: `ModuleVersion` is a `System.Version` (prerelease →
  `PSData.Prerelease`, not in the version string); test path is the **pure `src`↔`tests`
  mirror** with `.Tests.ps1` suffix (the C# `.Tests`-folder form was wrong for PowerShell);
  manifest `PowerShellVersion` is the import-time gate (not `#Requires`); conditional
  verification (no manifest to import on a pure design review).
- **Docs**: `claude/README.md` Agents "Seeded agents" + root `CLAUDE.md` Subagents "Seed" line.
- **Install/verify**: `setup.ps1 -Module claude -DryRun` → real run; `~/.claude/skills/jj`
  junction resolves to the repo, `~/.claude/skills/jj/SKILL.md` and
  `~/.claude/agents/powershell-module-architect.md` both live. No installer code changes.

## Done this session (2026-06-16) — Claude subagents framework

Added a user-scope subagents framework to the Claude module, seeded with one agent. Grilled the
design end-to-end (`/grill-me`) and reviewed each step with Codex (plan + finished agent body).

- **`claude/agents/pwsh-implementer.md`** (new) — TDD specialist/implementer for PowerShell 7+
  (Pester first, PSScriptAnalyzer `-Recurse` + settings file, strict typing, flag-before-mode
  rule, surgical changes, enterprise error handling; extends to Azure/Graph/CI-CD when the work is
  primarily PowerShell). `model: inherit`, `color: blue`, `skills: tdd` (preloads the tdd
  SKILL.md body only — verified, ~110 lines, bundled resources stay on-demand),
  tools `Read,Write,Edit,Bash,Glob,Grep`.
- **Install** — `setup.ps1 → Install-Claude` junctions the whole `claude/agents/` dir into
  `~/.claude/agents/` (deliberately *unlike* skills, which junction per-subdir): agents are flat
  `.md` files in a dir nothing else writes to, so a whole-dir link keeps live == repo and lets
  `/agents`-created agents land in the repo. `setup.sh` does the Linux symlink equivalent.
- **Fixed a pre-existing Linux bug** (found by Codex): `setup.sh`'s claude module never symlinked
  `AGENTS.md` despite the README claiming it did, so `@AGENTS.md` resolved to nothing on Linux.
  Added the symlink.
- **Docs** — `claude/README.md` Agents section + Files-table row; root `CLAUDE.md` Subagents
  section. Both capture the whole-dir-link rationale and the self-contained-body / no-`@import`
  gotcha (share conventions via `skills:` or restate with a maintenance note).
- **Design decisions** (so they're not re-litigated): user-scope only; role-based not
  domain-based; seeded with `pwsh-implementer` only — proposed `explorer`/`reviewer` were dropped
  as redundant with the built-in `Explore` agent and `code-review` skill + Codex.
- **Verified:** `setup.ps1 -Module claude -DryRun` clean → real install → junction resolves to the
  repo → `~/.claude/agents/pwsh-implementer.md` live. New agents need a one-time `setup.ps1` re-run
  only to create the junction (the first time); after that, dropping a `.md` in the repo is enough.

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
