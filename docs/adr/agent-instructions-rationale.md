# Agent-instruction pruning: durable rationale

This ADR records how the former large project guide was classified during issue #52.
It is not loaded project guidance and must not become a second operational source of
truth. For current behavior, follow the exact authority index in the root `AGENTS.md`.

## Classification of removed material

| Former guide material | Classification | Canonical destination |
| --- | --- | --- |
| Repository scope and active/legacy boundary | Always-loaded invariant | `AGENTS.md` → Scope and safety |
| Startup/deferred profile phases and prompt invariants | Always-loaded invariant plus current behavior | `AGENTS.md` → Scope and safety; `powershell/README.md`; `powershell/Microsoft.PowerShell_profile.ps1`; `powershell/Profile/Set-Prompt.ps1` |
| Azure CLI profile isolation and prompt rendering | Current subsystem documentation plus historical rationale | `powershell/README.md`; `powershell/Profile/AzCliAccount.ps1`; `docs/adr/az-cli-profile-isolation.md`; `tests/AzCliAccount.Tests.ps1`; `tests/Set-Prompt.Tests.ps1` |
| Git work-hook dispatch and fail-open boundary | Always-loaded invariant plus current behavior | `AGENTS.md` → Scope and safety; `git/README.md`; `git/work-hooks/`; `tests/git-work-hooks.Tests.ps1` |
| Native Neovim API and lockfile discipline | Always-loaded invariant plus current behavior | `AGENTS.md` → Scope and safety; `nvim/README.md`; `nvim/nvim-pack-lock.json` |
| psmux/Zellij roles and keymaps | Current subsystem documentation | `psmux/README.md`; `psmux/psmux.conf`; `zellij/README.md`; `zellij/config.kdl` |
| Herdr, Yazi, and installer mechanics | Current subsystem documentation | `herdr/README.md`; `herdr/config.toml`; `yazi/yazi.toml`; `setup.ps1`; `setup.sh` |
| Claude hooks, Codex posture, Pi installation | Current subsystem documentation | `claude/README.md`; `claude/settings.json`; `codex/README.md`; `codex/config.toml`; `pi/README.md`; `pi/settings.json` |
| Detailed experiments, “do not reverse” explanations, and rejected designs | Historical ADR material | This ADR only when it explains the pruning decision; subsystem ADRs/source comments own tool-specific rationale |
| Duplicate inventories, stale package notes, and machine-local preferences | Obsolete content | Deleted from the loaded guide; machine-local values remain in user configuration |

## Why the loaded guide is small

The loaded core retains only boundaries that affect a safe first step: active versus
legacy scope, deferred-startup and prompt invariants, safety-hook posture, native API
and lockfile rules, lane boundaries, validation expectations, and direct routing. It
intentionally does not restate keymaps, installer command details, hook regexes, plugin
rosters, or historical investigations.

The routing table uses repository-relative paths rather than implicit imports. Claude
Code, Codex CLI, and Pi can therefore discover the same current detail by reading files
on demand. The root `CLAUDE.md` remains a thin Claude adapter; it does not carry a copy
of project guidance.

## Rejected alternatives

- Keeping the former guide as an omnibus archive would preserve duplication and make it
  ambiguous whether stale operational statements still applied.
- Depending on Claude `@` imports would make Codex and Pi miss the same context and would
  violate the on-demand model.
- Replacing exact subsystem destinations with a generic `docs/adr/` pointer would force
  agents to search before they can safely begin and would leave critical invariants
  effectively unreferenced.
