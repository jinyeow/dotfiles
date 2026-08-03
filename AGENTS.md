# AGENTS.md

This is the repository project guide shared by Claude Code, Codex CLI, and Pi. Keep it
short: durable rationale belongs in subsystem documentation and `docs/adr/`, while
machine-specific preferences belong in the relevant user-level configuration.

## Scope and wayfinding

This repository contains Windows/PowerShell and Linux/WSL dotfiles. Active development is
on the Windows-side configuration (`powershell/`, `nvim/`, `zellij/`, `yazi/`, `git/`, and
related AI-agent modules). The Linux snapshot (`config/`, `i3/`, legacy `tmux/`, `vim/`,
etc.) is legacy; touch it only when explicitly requested.

Use the tool directory's README and source as the authority for tool behaviour. The main
entry points are `setup.ps1` (Windows) and `setup.sh` (Linux/WSL), both module-based and
supporting dry-run modes. Pester coverage for installer arguments is in
`tests/setup.Tests.ps1`.

Important source locations:

- PowerShell profile: `powershell/Microsoft.PowerShell_profile.ps1` and `powershell/Profile/`.
- Prompt: `powershell/Profile/Set-Prompt.ps1`.
- Neovim: `nvim/` (the older `vim/` tree is the Linux fallback).
- Git: `git/`; terminal tools: `zellij/`, `psmux/`, `yazi/`.
- Claude/Codex/Pi configuration: `claude/`, `codex/`, `pi/`.
- Historical rationale and rejected alternatives: `docs/adr/`.

## Current project rules

- Keep the PowerShell profile's deferred phases and asynchronous prompt work intact; do
  not move expensive module loads or filesystem/process scans onto startup.
- Keep the active Azure CLI profile visible and isolated as implemented by
  `powershell/Profile/AzCliAccount.ps1`; do not reintroduce directory swapping or a
  manifest registry. See its tests before changing it.
- Keep jj prompt detection ahead of git, and preserve the prompt's exit-code and CWD
  handling. Prompt changes require the focused prompt tests.
- Keep Git work hooks config-scoped and fail-open only when the dispatcher is absent;
  preserve the pinned command and run `tests/git-work-hooks.Tests.ps1` after changes.
- Keep Neovim on its native APIs and update `nvim/nvim-pack-lock.json` with plugin edits.
  Do not replace the configured plugin manager or reintroduce the old LSP framework.
- Keep psmux and Zellij as the intentional daily/fallback pair. Their detailed keymaps
  and installation mechanics live in `psmux/README.md` and `zellij/README.md`.
- Do not move or reclassify skill directories, or redesign installer projection, as part
  of instruction/documentation work; those concerns are owned by the related AI-agent
  workstreams.

## Agent configuration boundaries

`claude/AGENTS.md` is the single source for global coding conventions shared by Claude
Code and Codex CLI. `claude/CLAUDE.md` is Claude-specific global behaviour and imports
that file. The repository-root `CLAUDE.md` is only a Claude adapter and imports this
file. Pi reads this project guide directly; its tracked configuration is under `pi/`.

Keep Claude hooks deterministic and fail-open where their source says so; hook behaviour
and wiring are documented in `claude/README.md`. Keep Codex reviewer/standalone posture
and Pi installation details in `codex/README.md` and `pi/README.md`, respectively. Do not
duplicate those documents in this file.

User-scope agents are maintained under `claude/agents/`; their roster and skills are
Claude-module concerns. Shared skills are under `claude/skills/` and are also projected
to Codex as configured by the installer. Do not add project-level copies of global
conventions.

## Editing and validation

Use LF, UTF-8, trimmed trailing whitespace, and the repository's EditorConfig (PowerShell
and shell files use four-space indentation). Match surrounding style and make the
smallest change that solves the request. Do not add secrets or AI attribution to commits.

Before finishing, inspect `git diff --check`, run focused tests, and run the relevant full
suite. For PowerShell linting, use the repository settings file
`PSScriptAnalyzerSettings.psd1`; CI is authoritative for the complete source-tree pass.
Use non-interactive git commands and leave no staged files unless the delivery explicitly
requires a commit.
