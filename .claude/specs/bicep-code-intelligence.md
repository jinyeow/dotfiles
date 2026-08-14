# Bicep code intelligence: Neovim LSP plus agent tooling (Claude Code, Codex CLI, Pi)

Status: plan, not yet implemented. Researched 2026-08-14; reviewed by a Fable subagent and
a Codex cross-model pass the same day, findings incorporated.

## Problem Statement

Bicep support is half-wired everywhere and provisioned nowhere.

In Neovim, the Bicep language-server block is gated on `bicep_lsp_path` in `user.lua`,
which defaults to empty and has no installer behind it (`nvim/lua/config/lsp.lua:157-171`,
`nvim/lua/config/user.lua:43`). Worse, the `*.bicep` filetype autocmd sits *inside* that
gate, so on a machine without the path set — every machine today — a `.bicep` buffer gets
no filetype at all, even though the Treesitter `bicep` parser is installed unconditionally
(`nvim/lua/config/treesitter.lua:35,76`) and would highlight it if the filetype were set.
`.bicepparam` files are not detected at all. The `langservers` installer module scoped
Bicep out on the stated grounds that it was "correctly gated and provisioned by other
means" and that folding it in "would conflate config-linking with toolchain-provisioning"
(`.claude/specs/langservers-installer-module.md:142-144`). The second half of that
rationale holds; the first half was wrong — nothing provisions the Bicep language server,
on this machine or any rebuild. Once this plan lands, that spec's "provisioned by other
means" line becomes true again and should not be edited retroactively; this paragraph is
the correction of record.

For the coding agents, `claude/CLAUDE.md` records the current dead end: the built-in `LSP`
tool has no Bicep plugin and Serena has no Bicep backend, so no agent has symbol-level
navigation in `.bicep` files. Codex CLI declares no MCP servers (`codex/config.toml`) and
Pi's extension dir is empty — neither has any Bicep tooling. Meanwhile the repo ships a
`bicep-implementer` agent and a `bicep-tdd` skill that work on Bicep constantly.

What changed to make this fixable now: as of July 2026 Microsoft publishes the language
server as a .NET global tool — `dotnet tool install --global Azure.Bicep.LangServer` puts a
`bicep-ls` command on PATH, documented explicitly for "AI coding tools and other LSP
clients" (learn.microsoft.com/azure/azure-resource-manager/bicep/install; claim verified
against that page during review). There is also an official Bicep MCP server
(`Azure.Bicep.McpServer`, run via `dnx -y Azure.Bicep.McpServer`) exposing file
diagnostics, formatting, decompile, resource-type schemas, and best-practices lookup. Both
ride the .NET SDK already in the winget manifest (`winget/packages.json:54`).

## Solution

One shared provisioning step and four thin consumers, cut by certainty:

- **Must-have, no dependencies**: unconditional Neovim filetype detection and Treesitter
  aliasing for `*.bicep` / `*.bicepparam` — needs no server at all.
- **Must-have**: a new Windows installer module (working name `biceptools`) that installs
  the `Azure.Bicep.LangServer` dotnet global tool, and the Neovim LSP config consuming
  `bicep-ls` from PATH.
- **Gated follow-ups** (each behind its own verification gate, below): a self-authored
  Claude Code LSP plugin; an `[mcp_servers.bicep]` entry in `codex/config.toml` running
  the official Bicep MCP server.
- **Deferred spikes**: the Pi leg (time-boxed discovery, both candidates unverified) and
  POSIX installer support.

No standalone published Neovim plugin is authored. The research found the standard path is
filetype detection + the stock nvim-lspconfig `bicep` config; the only existing dedicated
plugin (carlsmedstad/vim-bicep) is regex syntax highlighting this config doesn't need
(Treesitter covers it). Publishing a `bicep.nvim` for one user's config is scope this repo
has rejected before — the config-module pattern is the plugin.

## Implementation Decisions

### Installer: `biceptools` module (Windows, binary-only)

- New module in `setup.ps1` only (POSIX deferred — see Out of Scope), joining the module
  registry, `-Module all` expansion (after the package-manager module, before the
  terminal-workspace module that must stay last), usage text, and README installation
  table.
- **Binary-only**: it installs `dotnet tool install --global Azure.Bicep.LangServer` and
  nothing else. Agent registration does not live here — bundling imperative Claude
  registration into a toolchain module would repeat exactly the config-linking vs
  toolchain-provisioning conflation the langservers spec rejected, and the plugin it would
  register doesn't exist until a later step. Claude registration belongs to the Claude
  Code slice (below); Codex and Pi are declarative tracked-config changes that go live
  through their existing modules.
- **Idempotency check via `dotnet tool list --global`** (parse for `azure.bicep.langserver`),
  not `Get-Command bicep-ls` — a PATH probe conflates "installed" with "discoverable in
  this shell", so a rerun in a shell with a stale PATH would attempt a reinstall of an
  already-installed tool. PATH discoverability is verified separately (Testing).
- Guard shape mirrors the `langservers` module: backup mode skips; dry run names the
  package without executing; missing `dotnet` warns and skips, never fails; the install
  command's exit code is checked and reported through the existing success/warn/fail
  helpers.
- **Bare-machine caveat, stated not engineered around**: the winget package-manager module
  only *prints* the bootstrap command (`setup.ps1:756-763` area) — it does not install the
  .NET SDK in the same run. On a bare machine, `-Module all` leaves this module on its
  warn-and-skip path until `winget/packages.ps1` has actually been run; a re-run picks it
  up. This is the same documented two-run caveat the langservers spec carries for Volta.
- The module name is tool-agnostic (`biceptools`, not `bicep-nvim`) because Neovim and the
  Claude Code plugin both consume the same binary.
- The Bicep **CLI** stays where it is (winget `Microsoft.Bicep`); this module provisions
  only the language server, which no CLI install path includes (verified: `az bicep
  install` and the standalone CLI ship the compiler only).

### Neovim

- **Filetype detection moves out of the LSP gate** into `vim.filetype.add` (or the existing
  autocmds.lua pattern) unconditionally: `*.bicep` → `bicep`, `*.bicepparam` →
  `bicep-params`. Rationale: the Treesitter parser is already installed unconditionally, so
  ungated detection buys highlighting and indentation even on a machine without the server —
  the current gating throws that away. This mirrors how `azure-pipelines` detection is
  unconditional while its server can still fail loudly. This change has no dependency on
  the installer module and ships first.
- **Treesitter for `.bicepparam`**: register the `bicep` parser for the `bicep-params`
  filetype (`vim.treesitter.language.register('bicep', 'bicep-params')`), the same aliasing
  already used for `azure-pipelines` → `yaml`, and add `bicep-params` to the Treesitter
  `filetypes` start list (`nvim/lua/config/treesitter.lua:76` area).
- **LSP config**: gate on `vim.fn.executable('bicep-ls') == 1` (the same shape as the
  `marksman` gate), with `cmd = { 'bicep-ls' }` and
  `filetypes = { 'bicep', 'bicep-params' }`, matching what stock nvim-lspconfig's
  `lsp/bicep.lua` declares (it ships no `cmd`, `filetypes = { 'bicep', 'bicep-params' }`,
  `root_markers = { '.git' }`).
- **`bicep_lsp_path` is removed from `user.lua`**, not kept as a fallback. It was never
  provisioned, so no machine can be relying on it; keeping a dead knob plus a PATH probe is
  two code paths where one suffices. The gate stays (server presence is machine-dependent,
  like marksman/roslyn), and a missing `bicep-ls` degrades to Treesitter-only silently —
  consistent with the other gated servers, and the deliberate opposite of the ungated
  JSON/YAML trio whose rationale (baseline, evidenced by a committed schema plugin) doesn't
  apply here.
- **languageId note**: nvim-lspconfig sends `bicep-params` as the languageId for
  `.bicepparam`; Microsoft's own Claude Code example maps `.bicepparam` to plain `bicep`.
  Whether the server treats both identically is unverified — Neovim follows lspconfig
  (`bicep-params`), and this must be smoke-tested against a real `.bicepparam` file at
  implementation.
- **README updates**: LSP server table row for bicep changes from "Elsewhere" to the new
  module; the filetype table gains `*.bicepparam`; the user.lua sample drops
  `bicep_lsp_path`.

### Claude Code (gated follow-up)

- **Gate**: verify the local-plugin registration flow (marketplace-from-path vs. direct
  install) against the installed `claude` CLI *before* implementing this slice; the
  mechanism is currently undecided and the community marketplaces
  (Piebald-AI/claude-code-lsps, boostvolt/claude-code-lsps) ship no Bicep plugin, so
  self-authoring is the path either way.
- Author a minimal plugin in-repo (proposed home: `claude/plugins/bicep-lsp/` with
  `plugin.json` + `.lsp.json`), containing essentially Microsoft's documented config:
  `{"bicep": {"command": "bicep-ls", "extensionToLanguage": {".bicep": "bicep",
  ".bicepparam": "bicep"}}}`. The binary comes from the `biceptools` module; the plugin
  declares, it does not install. Registration (an imperative `claude` CLI step) lives in
  this slice — modeled on the existing agent-registration modules
  (`Install-Serena`/`Install-Context7`, `setup.ps1:1351-1447`), either as part of the
  existing Claude-owning module or as its own small registration step, decided when the
  gate above resolves the mechanism. It must be idempotent (remove-then-add, exit code
  checked), like the MCP registrations it copies.
- Update `claude/CLAUDE.md`'s code-intelligence routing: `.bicep` moves into the "prefer
  the built-in LSP tool for reads" bucket; the "Bicep has no Serena backend at all" note
  stays true (verified against Serena's current supported-language list — no Bicep) but
  stops being a dead end. Symbol-scoped *edits* remain unavailable for Bicep (Serena is the
  only edit path and has no backend); text edits stay the tool there.
- The Azure MCP plugin's `bicepschema` tool already covers schema lookup in Claude Code;
  the official Bicep MCP server is therefore *not* registered for Claude Code — the LSP
  plugin covers navigation/diagnostics and `bicep-tdd` covers build/lint. Fewer overlapping
  tools beats completeness here.

### Codex CLI (gated follow-up)

- Codex has no native LSP support (verified against openai/codex issue tracker as of
  ~v0.125), so MCP is the path — and note this track does not depend on `biceptools` at
  all: the MCP server runs via `dnx`, not `bicep-ls`.
- **Gate, before touching config**: on this machine, prove (a) `dnx` is on PATH from the
  .NET 10 SDK install (or determine what provisions it), (b) `dnx -y Azure.Bicep.McpServer`
  actually starts on Windows, and (c) the installed Codex version accepts an
  `[mcp_servers.bicep]` table with whatever command/args key shape its config reference
  (already cited at `codex/config.toml:2`) specifies. `codex/config.toml` has no existing
  MCP entry to crib from, so all three are genuinely unverified prerequisites for this
  leg — the leg is blocked until they pass, though the rest of the plan is not.
- On a green gate: declare `[mcp_servers.bicep]` in the tracked `codex/config.toml`
  running the official server. This buys diagnostics, formatting, decompile, resource-type
  schemas, AVM metadata, and best-practices lookup — but **not** symbol-level
  go-to-definition/references. That gap is acknowledged, not papered over: the generic
  LSP→MCP bridges that could expose `bicep-ls` symbol navigation (best candidate:
  isaacphi/mcp-language-server) are beta with unverified Windows support, and are deferred
  (Out of Scope) rather than adopted on faith.

### Pi (deferred spike)

- Time-boxed discovery, not an implementation slice: neither candidate mechanism is
  verified for Bicep — (a) the `pi-lsp` package from pi.dev pinned in `pi/settings.json`'s
  `packages` array, configured to launch `bicep-ls`; (b) the Bicep MCP server, if Pi's MCP
  support is confirmed. Try (a) then (b) in a scratch Pi setup, **not** by pinning into the
  tracked `settings.json` — `Install-Pi`'s loop treats a failing package install as a
  module failure (`setup.ps1:1061-1075`), so an unverified pin would break Pi projection
  for everything, the opposite of fail-soft.
- Only after one candidate passes an end-to-end check (server attaches, diagnostics or
  definition works in a `.bicep` file) does it graduate to a tracked-config change. If both
  fall through, Pi keeps its current (no) Bicep tooling and that outcome is recorded here.

## Testing Decisions

- **Installer**: mirror the full shape of the `langservers` module suite, not just its
  shallow half — (a) dry run names the dotnet tool package and the module is recognised
  (`tests/setup.Tests.ps1:854-864` shape); (b) missing-`dotnet` takes the warn-and-skip
  path using the **empty-PATH technique** the suite uses for absence
  (`tests/setup.Tests.ps1:868-878` — "you cannot shim absence"); (c) a **shimmed-`dotnet`
  install-loop context** (`tests/setup.Tests.ps1:887+` shape) exercising the
  already-installed idempotent skip and the exit-code failure report; (d) full-setup
  ordering assertion. PSScriptAnalyzer over the whole tree with the repo settings file, as
  CI runs it.
- **PATH discoverability, separate from installed-state**: after a real install, confirm
  `bicep-ls` resolves in a *fresh* pwsh, in Neovim's spawn, and in a Claude Code session —
  the dotnet global-tool shim directory joining PATH on Windows is an assumption of this
  plan (same class as the langservers spec's Volta-shim assumption). If it doesn't join
  PATH, the fallback is wiring the absolute shim path, recorded with a note.
- **Neovim**: no Lua test harness exists in this repo; verification is a manual checklist
  recorded in the PR — open a `.bicep` and a `.bicepparam` file, confirm filetype,
  Treesitter highlighting, LSP attach, hover, go-to-definition, diagnostics, and formatting.
- **Claude Code plugin**: `claude plugin list` shows the plugin; the `LSP` tool resolves a
  definition in a real `.bicep` module from the bicep-tdd fixture set.
- **Codex**: session-level smoke test — list tools, run a diagnostics call against a file
  with a known lint violation (this doubles as the gate's step (c) evidence).

## Out of Scope

- Publishing a standalone `bicep.nvim` plugin (rejected above).
- **POSIX installer support.** The Linux side is legacy per AGENTS.md, `setup.sh` has no
  package-manager module providing a .NET SDK (its langservers analogue assumes Volta was
  installed manually), and the repo has no shell test harness — adding an unverifiable
  module to a legacy installer with no .NET provider is scope without a requirement.
  Revisit if Linux-side Bicep editing becomes real.
- LSP→MCP bridge servers for symbol navigation in Codex/Pi (beta, Windows-unverified;
  revisit if/when isaacphi/mcp-language-server stabilises or Codex ships native LSP).
- Symbol-scoped Bicep *edits* for agents (Serena has no backend; nothing to wire).
- Wiring the VS Code extension's custom LSP methods (build/decompile commands, deployment
  graph) into Neovim — `bicep build`/`bicep decompile` CLI calls are the simpler answer and
  already exist via the winget-installed CLI.
- Registering the Bicep MCP server for Claude Code (overlap with the Azure plugin +
  bicep-tdd, per the Claude Code section).
- Any change to the existing `langservers` (npm) module, including retro-editing its spec.

## Open Questions

None block the must-have tracks (A/B below); each gated leg names its own blockers above.

1. Does the dotnet global-tool shim directory join PATH such that `bicep-ls` resolves in
   fresh pwsh, Neovim, and Claude Code processes? (Blocks nothing at design time; the
   Testing section defines the check and the fallback.)
2. Does the server accept both `bicep-params` and `bicep` languageIds for `.bicepparam`?
   Neovim uses `bicep-params` per lspconfig; the Claude plugin uses `bicep` per Microsoft's
   example — if the server rejects one, align both on the accepted id.
3. Claude Code local-plugin registration flow — the Claude slice's gate.
4. `dnx` availability, Windows launch, and the Codex `[mcp_servers.*]` schema — the Codex
   slice's gate (three named prerequisites, all currently unverified).
5. Pi mechanism viability — the Pi spike's whole purpose.
6. Support/stability status of `Azure.Bicep.McpServer` — the docs family around it
   explicitly disclaims some sibling packages (e.g. `Azure.Bicep.Core`) as unsupported;
   confirm the MCP server's own support posture before depending on it.

## Sequencing

Independent tracks, not a serial chain — only Track B blocks Tracks C-partially and the
`bicep-ls` half of testing:

- **Track A (ship first, zero dependencies)**: Neovim filetype detection + Treesitter
  aliasing for `bicep`/`bicep-params`.
- **Track B (must-have)**: `biceptools` module + tests, then the Neovim LSP gate +
  README updates.
- **Track C (gated)**: Claude Code plugin + registration + CLAUDE.md routing. Needs
  Track B's binary and its own registration-flow gate.
- **Track D (gated, independent of B)**: Codex `[mcp_servers.bicep]` after its
  three-part gate passes.
- **Track E (deferred spike)**: Pi discovery, time-boxed; graduates to config only on a
  passing end-to-end check.

A PR per track, or A+B together, both work; C–E land whenever their gates clear.
