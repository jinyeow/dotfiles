# AGENTS.md

## Scope and safety

This repository contains Windows/PowerShell and Linux/WSL dotfiles. Active development
is on the Windows-side configuration (`powershell/`, `nvim/`, `zellij/`, `psmux/`,
`yazi/`, `git/`, and related AI-agent modules). The Linux snapshot (`config/`, `i3/`,
legacy `tmux/`, `vim/`, etc.) is legacy; touch it only when explicitly requested.

Do not widen a task into installer projection, skill rehoming, or agent-directory
reclassification. Keep deferred PowerShell/profile work and asynchronous prompt work
off startup. Preserve safety hooks and fail-open behavior where their source specifies
it. Keep jj prompt detection ahead of git, preserve prompt exit-code/CWD handling, and
keep Neovim on native APIs with its lockfile updated alongside plugin edits.

Use non-interactive git commands. Do not add secrets or stage files unless delivery
explicitly requires it. Before finishing, run `git diff --check`, focused tests, and the
relevant full suite; use `PSScriptAnalyzerSettings.psd1` for PowerShell analysis.

## Authority index

Read the listed source before changing a subsystem; tests are part of its contract.
These are repository paths, so this routing works without runtime-specific imports.

| Task or subsystem | Authoritative detail |
| --- | --- |
| PowerShell profile and deferred phases | `powershell/README.md`; `powershell/Microsoft.PowerShell_profile.ps1`; `tests/setup.Tests.ps1` |
| Prompt, jj/git status, exit code, and CWD | `powershell/Profile/Set-Prompt.ps1`; `tests/Set-Prompt.Tests.ps1` |
| Git config and work hooks | `git/README.md`; `git/gitconfig`; `git/work-hooks/`; `tests/git-work-hooks.Tests.ps1` |
| Neovim APIs and plugins | `nvim/README.md`; `nvim/init.lua`; `nvim/lua/`; `nvim/nvim-pack-lock.json` |
| psmux | `psmux/README.md`; `psmux/psmux.conf` |
| Zellij | `zellij/README.md`; `zellij/config.kdl` |
| Herdr | `herdr/README.md`; `herdr/config.toml`; `tests/setup.Tests.ps1` |
| Yazi | `yazi/yazi.toml`; `yazi/keymap.toml`; `yazi/theme.toml`; `yazi/package.toml` |
| Setup and installers | `setup.ps1`; `setup.sh`; `tests/setup.Tests.ps1`; `tests/setup-sh.Tests.ps1` |
| Claude Code hooks and agents | `claude/README.md`; `claude/AGENTS.md`; `claude/settings.json`; `claude/agents/` |
| Codex CLI | `codex/README.md`; `codex/config.toml`; `codex/templates/` |
| Pi | `pi/README.md`; `pi/settings.json`; `pi/extensions/`; `pi/skills/` |

## Shared agent configuration boundaries

`claude/AGENTS.md` is the global coding-conventions source installed for Claude Code
and Codex CLI. `claude/CLAUDE.md` is its Claude-specific adapter. This root guide is
project guidance, not a replacement for either. Pi reads this project guide directly;
its tracked configuration is under `pi/`. Do not rely on Claude imports or automatic
runtime loading to discover the authority index above.

Keep hooks deterministic and fail-open where their source says so. User-scope Claude
agents remain under `claude/agents/`; shared skills remain under `claude/skills/` and
are projected to Codex by the installer. Lane-specific rehoming/projection work is out
of scope here.

## Editing conventions

Use LF, UTF-8, trimmed trailing whitespace, and the repository EditorConfig (four-space
indentation for PowerShell and shell files). Match surrounding style and make the
smallest correct change. The relevant README, source, and tests are the operational
source of truth; `docs/adr/` is for historical rationale, rejected alternatives, and
architectural decisions—not a second copy of current instructions.
