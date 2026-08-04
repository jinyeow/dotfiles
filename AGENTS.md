# AGENTS.md

## Scope and safety

This repository contains Windows/PowerShell and Linux/WSL dotfiles. Active development
is on the Windows-side configuration ([`powershell/`](powershell/), [`nvim/`](nvim/),
[`zellij/`](zellij/), [`psmux/`](psmux/), [`yazi/`](yazi/), [`git/`](git/), and related
AI-agent modules). The Linux snapshot ([`config/`](config/), [`i3/`](i3/), legacy
[`tmux/`](tmux/), [`vim/`](vim/), etc.) is legacy; touch it only when explicitly
requested.

Do not widen a task into installer projection, skill rehoming, or agent-directory
reclassification. Keep deferred PowerShell/profile work and asynchronous prompt work
off startup. Preserve safety hooks and fail-open behavior where their source specifies
it. Keep jj prompt detection ahead of git, preserve prompt exit-code/CWD handling, and
keep Neovim on native APIs with its lockfile updated alongside plugin edits.

Use non-interactive git commands. Do not add secrets or stage files unless delivery
explicitly requires it. Before finishing, run `git diff --check`, focused tests, and the
relevant full suite; use
[`PSScriptAnalyzerSettings.psd1`](PSScriptAnalyzerSettings.psd1) for PowerShell analysis.

## Authority index

Read the listed source before changing a subsystem; tests are part of its contract.
These are repository paths, so this routing works without runtime-specific imports.

| Task or subsystem | Authoritative detail |
| --- | --- |
| PowerShell profile and deferred phases | [`powershell/README.md`](powershell/README.md); [`powershell/Microsoft.PowerShell_profile.ps1`](powershell/Microsoft.PowerShell_profile.ps1); [`tests/setup.Tests.ps1`](tests/setup.Tests.ps1) |
| Prompt, jj/git status, exit code, and CWD | [`powershell/Profile/Set-Prompt.ps1`](powershell/Profile/Set-Prompt.ps1); [`tests/Set-Prompt.Tests.ps1`](tests/Set-Prompt.Tests.ps1) |
| Git config and work hooks | [`git/README.md`](git/README.md); [`git/gitconfig`](git/gitconfig); [`git/work-hooks/`](git/work-hooks/); [`tests/git-work-hooks.Tests.ps1`](tests/git-work-hooks.Tests.ps1) |
| Neovim APIs and plugins | [`nvim/README.md`](nvim/README.md); [`nvim/init.lua`](nvim/init.lua); [`nvim/lua/`](nvim/lua/); [`nvim/nvim-pack-lock.json`](nvim/nvim-pack-lock.json) |
| psmux | [`psmux/README.md`](psmux/README.md); [`psmux/psmux.conf`](psmux/psmux.conf) |
| Zellij | [`zellij/README.md`](zellij/README.md); [`zellij/config.kdl`](zellij/config.kdl) |
| Herdr | [`herdr/README.md`](herdr/README.md); [`herdr/config.toml`](herdr/config.toml); [`tests/setup.Tests.ps1`](tests/setup.Tests.ps1) |
| Yazi | [`yazi/yazi.toml`](yazi/yazi.toml); [`yazi/keymap.toml`](yazi/keymap.toml); [`yazi/theme.toml`](yazi/theme.toml); [`yazi/package.toml`](yazi/package.toml) |
| Setup and installers | [`setup.ps1`](setup.ps1); [`setup.sh`](setup.sh); [`tests/setup.Tests.ps1`](tests/setup.Tests.ps1); [`tests/setup-sh.Tests.ps1`](tests/setup-sh.Tests.ps1) |
| Agent workflow configuration | [`.agents/workflow.md`](.agents/workflow.md); [`ai-agents/skills/setup-agent-skills/SKILL.md`](ai-agents/skills/setup-agent-skills/SKILL.md) |
| Claude Code hooks and agents | [`claude/README.md`](claude/README.md); [`claude/AGENTS.md`](claude/AGENTS.md); [`claude/settings.json`](claude/settings.json); [`ai-agents/agents/`](ai-agents/agents/) |
| Codex CLI | [`codex/README.md`](codex/README.md); [`codex/config.toml`](codex/config.toml); [`codex/templates/`](codex/templates/) |
| Pi | [`pi/README.md`](pi/README.md); [`pi/settings.json`](pi/settings.json); [`pi/extensions/`](pi/extensions/); [`pi/skills/`](pi/skills/) |

## Shared agent configuration boundaries

[`claude/AGENTS.md`](claude/AGENTS.md) is the global coding-conventions source installed
for Claude Code and Codex CLI. [`claude/CLAUDE.md`](claude/CLAUDE.md) is its
Claude-specific adapter. This root guide is project guidance, not a replacement for
either. Pi reads this project guide directly; its tracked configuration is under
[`pi/`](pi/). Do not rely on Claude imports or automatic runtime loading to discover the
authority index above.

Keep hooks deterministic and fail-open where their source says so. User-scope agent definitions live under [`ai-agents/agents/`](ai-agents/agents/)
and are currently projected to Claude Code. Portable skills live under [`ai-agents/skills/`](ai-agents/skills/) by default; Claude-native
skills and projected support content live under [`claude/skills/`](claude/skills/), Codex-native
variants under [`codex/skills/`](codex/skills/), and Pi-native variants under [`pi/skills/`](pi/skills/).
Claude projects portable plus Claude-native skills; Codex (Windows in this PR) projects portable
plus Codex-native skills; Pi projects portable plus Pi-native skills. `ai-agents/_shared/` is
source-only portable support content, while `claude/skills/_shared/` is projected with Claude
skills. Historical source roots remain compatibility identifiers for ownership migration only.
Keep runtime projections derived from the canonical `ai-agents/skills/` portable source and runtime-native module sources; do not create a second source tree under a runtime module.

## Editing conventions

Use LF, UTF-8, trimmed trailing whitespace, and the repository EditorConfig (four-space
indentation for PowerShell and shell files). Match surrounding style and make the
smallest correct change. The relevant README, source, and tests are the operational
source of truth; [`docs/adr/`](docs/adr/) is for historical rationale, rejected
alternatives, and architectural decisions—not a second copy of current instructions.
