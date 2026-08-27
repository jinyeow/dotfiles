# Changelog

This is a personal dotfiles repository with continuous history and no version tags —
entries are grouped by month instead of by release. Each entry cites the short commit
hash it came from. This file was generated once, by hand, from the full `main` commit
history; there is no established process that keeps it updated automatically, so treat
it as a snapshot rather than a live record.

## 2026-08

Portable multi-runtime agent tooling (Claude Code, Codex CLI, Pi) matures: skills and
agents get rehomed under a shared `ai-agents/` source tree, project-brain and the
review skill set become portable, and CI/testing hardens across the migration.

Added
- Pi setup module and portable project instructions (`c1b42e8`, `5b286ef`)
- composite `ai-agents` setup module provisioning Claude, Codex, and Pi together (`c1603f0`)
- `review-me`, `prove-it`, `teach-back`, `redraft` skills (`22dd585`)
- split `deep-review` into a default `quick-review` plus opt-in `deep-review` (`b578d02`)
- `to-pullrequest` skill for PR creation (`5cee1ef`)
- `techdebt` skill wired to real per-stack tool output (`5df6d68`)
- `rfc-bau-nsg-fw` single-scope RFC skill, later renamed `rfc` with clone-derived
  both-scope/multi-PR/fallback handling (`d1ab4cb`, `11c7914`)
- `worktree-janitor` skill for post-merge cleanup (`cc6566d`)
- `biceptools` setup module and gated official Bicep MCP server registration in Codex
  (`a6ce3dc`, `aa68b26`)
- `refactor-agents-md` skill; AGENTS.md split via progressive disclosure (`a3f7d13`)
- Codex dispatches review skills' per-dimension agents via `multi_agent` (`57d4293`)
- project-brain wired into Codex's SessionStart hook and into Pi via a
  `before_agent_start` extension (`64ed354`, `d87d568`)
- OKF schema for project-brain, plus a shared conversion script (`7e69be2`)
- `dispatch-implement` wrapper skill for Claude Code (`2d52bb7`)
- git-guardrails ported to Codex as a PreToolUse hook and to Pi as a tool_call extension
  (`96bde58`, `59b99d0`)
- storm-research migrated to Pi via pi-subagents parallel tasks (`b898a9f`)
- herdr: fzf-backed agent picker and previous/next agent-jump keybindings (`f0856ea`, `a66de7f`)
- nvim: unconditional bicep/bicepparam filetype detection and treesitter alias (`a1d153d`);
  diff1_inline layout added to the diffview cycle (`3c381f5`)
- CODEOWNERS now requires owner review on GitHub (`dad4b71`)

Fixed
- `az repos pr create`'s broken draft/work-items/description flags documented as a known
  limitation rather than relied on (`fd565e3`)
- nvim: bicep-ls capability advertisement gap patched, C# indentation and bracket
  auto-pairing restored, fzf-lua preview debounced to stop typing lag (`1a39996`, `6dfaa88`, `c12cbc8`)
- Serena project config: restored the `languages` key alongside the migrated
  `language_servers` key (`4ec686a`)
- Pi's git-guardrails hook quote-scrubbed to stop false-blocking safe commands (`8774eaa`)
- review-skills iterated through several review-fix-loop cycles tightening
  `--reviewers` test coverage, junction-safe ADR links, and actionable-error refusal
  checks (`b787416` through `2248259`, tracked as PR #147); a parallel set of cycles
  hardened Codex's `agents.*` config-table tests and corrected dispatch-label/sandbox docs
  (`a4e2f77` through `327bc5b`, tracked as PR "QR1–QR4")

Changed / Removed
- shared agents moved to a canonical `ai-agents/agents/` layout; skill source layout
  simplified; Claude CLI now bootstraps before setup runs (`ffa2f82`, `43047f5`, `ef4fa8f`)
- shared `AGENTS.md` relocated from `claude/` to `ai-agents/`; portable skill output
  defaults moved from `.claude/` to `.agents/` (`2f5d98f`, `06687ae`)
- the `caveman` skill removed entirely; stop-slop's AI-tell checklist folded into the
  `write` skill instead (`42e6dcf`, `8b3815e`)
- fixed-header wrap-up structure reverted in favor of the earlier tight-bullets format (`95f8e2b`)
- `concise` output style renamed `concise-plus` and deduplicated against AGENTS.md (`55463f1`)
- Claude's Stop-hook self-review reminder was scoped down to SessionEnd/PreCompact, then
  replaced outright by a `/wrapup` skill once the hook proved unreliable (`add9ee2`, `d8445df`, `7d7943d`)

Docs
- code intelligence routed to the built-in LSP tool for reads, Serena for symbol edits (`2e4414b`)
- five memory-only conventions migrated into shared AGENTS.md; memory-system boundaries
  documented (`9b399e8`, `0897dbe`)
- write/stop-slop rules folded into the output contract; report-first and rule-dedup
  guidance added to AGENTS.md (`705714a`, `e9ec1ba`)
- azure-boards-organiser: `--organization` and WIQL fixes, write-pass gate, and
  `Custom.TimeSpent` documented as distinct from `CompletedWork` (`4fed5fb`, `f287a22`, `132a66b`, `07502a0`)
- test harness bash resolution hardened across ctags-hook and setup-sh suites, and a
  new-device setup/migration-safety test suite added (`7a68fd9`, `699506b`, `27d7b49`,
  `3d25f0e`, `9e3761f`)

## 2026-07

An agent roster, council review system, CI pipeline, and secret scanning land
(`b802f03`), alongside psmux (a native-Windows tmux-style multiplexer), diffview.nvim,
and a run of Claude/Codex configuration policy work.

Added
- agent roster, council review system, CI pipeline, and secret scanning (`b802f03`)
- psmux native-Windows tmux multiplexer module, then fzf window/paste popups, lazygit
  integration, and native session choosing (`e3f47ab`, `ba1e6fd`, `2f31a73`)
- `storm-research` skill; `/walkthrough` mentored diff-tour skill; `/board-triage` (`f0c1524`, `2179cb2`, `5a88b18`)
- nvim: PowerShell debugger via nvim-dap + PSES; MRU file search via fzf-lua oldfiles;
  diffview.nvim (later swapped for the maintained diffview-plus fork) plus the
  `review-ado-pr` skill for local ADO PR reviews (`695ae0d`, `a8e2f05`, `2a0ebe6`, `9870327`)
- `herdr` module with agent-state integration; `langservers` module provisioning
  Neovim's JSON/YAML/ADO servers (`55912b4`, `3b05a50`)
- PowerShell: EDITOR/VISUAL platform-aware fallback, az CLI work/personal account
  switching (`azw`/`azp`, later replaced by a named profile switcher `azs`) (`586d499`, `9307f82`, `287c17f`)
- git: policy hook scoped to work repos via config-based hooks, with fail-open when the
  dispatcher isn't installed (`19112fc`, `e1ece9c`)
- Codex custom skills installed via a `~/.codex/skills/` junction; MCP reviewer
  reasoning effort pinned to medium; model bumped to gpt-5.6-sol at low effort (`67beec4`, `d7317da`, `0579203`)

Fixed
- nvim LSP and theme performance, plus pwsh Az-runspace review follow-ups (`a04cdc9`)
- nvim-treesitter migrated from the retired `master` branch to `main` for Neovim 0.12 (`7d8cf83`)
- psmux: repaired drive-move breakage and sidebar toggle bind; stopped auto-save from
  clobbering the last good snapshot (`b371800`, `aff7a27`)
- statusline: simplified the context segment to always show the 5h window, then
  stripped a stray "(1M context)" suffix from the model name (`92dc626`, `09baf0a`)

Changed
- local lint loop brought in line with CI, gating shellcheck on the active shell (`1ce75d0`)
- repo-wide review pass: bug fixes, guardrail hardening, prompt performance, Linux CI (`682967b`)
- Claude's initial `/context` bloat reduced from the system prompt; a concise output
  style added and shared with Codex (`f8b95d0`, `6f21b85`)
- teammate mode pinned to in-process, disabling psmux teammate panes (`d04bfc8`)
- output contract split into a terse mid-turn form and a self-contained wrap-up (`983ec88`)
- dependency bumps: gitleaks-action 2→3, actions/checkout 4→7, stylua-action 4→5
  (`c5cc7fd`, `e4b4b54`, `49cd9c0`)

Docs
- output contract for action turns; verify-against-primary-artifact rule; bare-worktree
  branch workflow; downstream-prompting levers baked into Claude config (`b3a7ba6`, `91e7afe`, `b5501fd`, `a639711`, `42fd253`)
- nvim-orgmode with offline org-grammar staging, its offline installer, and a cheatsheet (`98d5aab`, `a006090`, `6d01793`)
- plan-implement-review loop model policy baked into rules and skills (`e45adff`)

## 2026-06

Claude Code tooling becomes a first-class part of the repo: subagents, a review-fix
loop, Codex integrated as a second-opinion MCP reviewer, and a first pass at guardrail
hooks. Alongside that, psmux-adjacent shell ergonomics (fzf pickers, eza, zoxide,
theme-aware bat/tig) and a Neovim provisioning pass for offline machines.

Added
- Codex CLI integrated as a read-only MCP reviewer (`6367768`)
- user-scope Claude subagents framework, starting with `pwsh-implementer`, then
  `powershell-module-architect` and `azure-boards-organiser` (`ad50fb6`, `e3c2b8f`, `e0a5dd0`)
- `jj` (Jujutsu) workflow skill; `jj` VCS segment in the prompt with git precedence (`154be6d`, `9886211`)
- `deep-review` + `fix-findings` composable review loop, merged as PR #4 (`7eec4dc`, `ddeef59`, `2360706`, `ce8019e`)
- local `bicep-tdd` skill plus its snapshot-compare gate (`43260b7`, `ad8ebd9`)
- pwsh guardrail and lint hooks, symlinked on install and documented (`7a33310`, `a16bed2`, `c3dfc75`, `134c453`)
- commits carrying an AI session-URL trailer are now blocked (`862c3f3`)
- context7 MCP module for Claude Code; serena module and ast-grep package (`98b8286`, `e27e7dd`)
- PowerShell: fd-backed fzf pickers, eza listing helpers, coding-font tooling, then a
  switch to Commit Mono as the coding font (`0d418dc`, `98dfbed`, `ea71c45`)
- eza Catppuccin mauve theme and bat OS-theme re-check, both switched by OS dark/light (`ae13f7b`, `32b27db`)
- local done/needs-input notification hooks; `-Backup` reverse-sync for copied configs (`083bede`, `b8b3dc7`)
- statusline: rate-reset countdown and PR segment (`a5da0af`)
- nvim: C#/.NET support, `<leader>A` source/test alternate toggle, autotrigger LSP
  completion and symbol-reference highlighting, offline plugin/parser provisioning for
  GitHub-blocked machines (`3c50e4f`, `4531566`, `9c554a8`, `b2ad5c9`)
- yazi: git.yazi and lazygit plugins (`2275fc9`)

Fixed
- prompt: responsive path shortening (truncate-to-repo); zoxide recording driven from
  the prompt so it survives reloads (`56de6aa`, `3eace36`)
- PowerShell: sync process CWD so Zellij opens new panes in the current directory; set
  TERM so Zellij forwards bracketed paste on Windows (`44aef5f`, `4607e01`)
- git: copy gitignore files instead of git-include stubs (`25a6381`)
- yazi: latte flavor and MIME detection fixed, HTML now opens in the browser; spaces in
  Windows open/reveal openers handled (`d7e1467`, `d922798`)
- Claude's dark-ansi theme pinned for readable Zellij diffs; the trailer-blocking hook
  tightened to avoid prose false positives (`cb39604`, `9e505ab`)

Changed / Removed
- Chocolatey integration removed from PowerShell; Az timer, completers, and tool
  helpers deferred to profile Phase 2 (`1f2c058`, `0931813`)
- Claude config symlinked into `~/.claude` instead of copied; Claude session
  working-state and `.claude/handoff.md` stopped being tracked (`e3e5be9`, `eb40ed6`, `4b14f85`)
- vendored skills refreshed from upstream; `diagnosing-bugs` and `writing-great-skills`
  adopted under their upstream names (`1b5778c`, `98d3885`)
- stale profile and vim backups removed (`97e53ab`)

Docs
- AGENTS.md consolidated, subagent orchestration moved into CLAUDE.md; thermo-nuclear
  rubric merged into the code review skills (`aa8232d`, `9de48ad`)
- "verify state before asserting it" rule added; positive-truthiness and
  comment-based-help-placement conventions documented (`440e1e3`, `45948aa`)
- result-driven assertions over invocation spying, for both the `tdd` skill and the
  `pwsh-implementer` agent (`7b12e36`, `6d77bc8`)

## 2026-05

The dotfiles repository is reorganized into per-tool directories, Neovim moves to a
config built on the native package system and LSP API, the PowerShell profile is
rewritten for fast startup, and Claude Code tooling begins (CLAUDE.md, statusline,
skills scaffolding). Zellij, yazi, tig, and lazygit configs are added with
Catppuccin theming wired to OS light/dark mode.

Added
- unified dotfiles installer for Windows and Linux (`b5007d9`); dotfiles reorganized
  into per-tool directories (`93ec281`); legacy installer scripts removed (`c331d32`)
- Neovim rebuilt on the native package system and LSP API: options/keymaps/autocmds
  ported from the old config, a minimal profile with OS-aware theme detection, and a
  README covering install/profiles/keymaps (`f44fa7c`, `1350ada`, `b69c46e`, `01a3b89`, `4872da4`, `9da9989`)
- PowerShell profile rewritten for fast startup, with async Azure/Git status in the
  prompt (`3d1d130`, `cf38f55`); later consolidated to a single hostname-agnostic
  profile, merging work-specific functions and dropping the separate WORK-PC profile (`de829a8`, `cf51486`)
- `git`: `[includeIf]` work identity plus a git installer module; unified
  prepare-commit-msg hooks via a footer trailer approach; column/fsck/maintenance/safety
  settings (`5d0d004`, `ad30985`, `f753861`)
- Claude Code: CLAUDE.md and project settings, `/handoff` slash command, global skills
  scaffolding, statusline with model/rate-limit/task-status (`14b85c3`, `fc925ad`, `6ebf17e`, `df8fd21`, `6640ec5`)
- `zellij` base config with Catppuccin themes and locked-first keybindings, followed by
  several iterations converging on vim-tmux-navigator-equivalent pane navigation (`73a2241`, `30d3155`, `585dc0e`, `6b3caf6`, `cb31671`)
- `yazi` config with Catppuccin theme and installer (`61e485a`); `lazygit` config with
  delta pager, nvim editor, Catppuccin theme switching (`a2164ba`)
- `tig` Catppuccin Mocha/Latte themes with OS-driven auto-switching (`9f64e02`)
- fzf: `fzfrc` plus wiring into the PowerShell profile and ripgrep; keybindings table
  and a light-mode bat theme (`8f6b809`, `f336a62`); `rfv` live ripgrep+fzf+bat search (`d635cce`)
- PowerShell: `keys` fuzzy hotkey cheatsheet, `Invoke-Fzf`-backed branch/worktree
  pickers, git-completion replacing posh-git (`c5c0f46`, `fda9bb3`, `c6ea9d2`)
- Windows Terminal settings tracked and backed up, then aligned to Catppuccin Mocha (`2e355b1`, `ab3c138`)
- `bat` config wired via `BAT_CONFIG_PATH` (`036732f`); winget curated bootstrap script
  and package list (`0abebb0`)

Fixed
- powershell: git-completion alias registration corrected; alt+c actually cd's into the
  selected directory; branch/worktree pickers always redraw the prompt (`b40c5e4`, `0740000`, `fda9bb3`)
- zellij: correct Windows config path (`%APPDATA%\Zellij\config`), ignoring
  `XDG_CONFIG_HOME` on Windows; theme fallback for terminals without CSI 2031 support (`1d46b13`, `fa55c44`, `15a4526`)
- nvim: maplocalleader set to backslash, keymap conflicts resolved, lazyredraw removed,
  `client:request` deprecation fixed (`ef34c5d`, `5f962dd`, `7afc0ca`, `07b0ede`)
- curl: insecure and noisy global defaults removed from curlrc (`01b3c7b`)
- tig: `Join-Path` argument wrapped in `$()`, deprecated color names updated (`f401646`, `fed157a`)
- setup: trailing comma removed from the `Remove-OldBackups` array literal (`58c2f9c`)

Changed
- nix `config.nix`/`home.nix` moved into `nix/`; setup scripts switched from backtick
  line continuations to splatting (`da501a2`, `785f5da`)
- 56 stale Linux-era scripts and other unused files removed (`94c2395`, `2abaf19`)
- READMEs added to all tool directories, `fzfrc` renamed `fzf_functions.sh`, root README
  rewritten (`f2fc243`, `89787e9`)

## 2025-12

Windows-side development resumes after a long quiet stretch: separate HOME/WORK
PowerShell profiles and a first Neovim config for lazy.nvim, plus prepare-commit-msg
hooks and git configuration for the WORK-PC setup.

- `45c95ef` Add HOME PowerShell profile with custom configurations
- `98c9eda` Add WORK PowerShell profile with custom configurations
- `3d7e3c5` Add WORK-PC Neovim configuration for lazy.nvim setup
- `db5f2ad` Update JYJP-PC PowerShell PROFILE
- `02af364` Add new PS prompt and update PS profile files
- `1692c03` Adjust prompt configuration and git status indicators
- `a6d2a8d` Fix PowerShell prompt Windows Terminal directory tracking
- `46dbe6e` Optimize PowerShell profile by removing comments and imports
- `505ee8d` Refactor prompt configuration and async checks
- `fb378ce` Refactor PowerShell WORK profile by removing unused code
- `cfab3f9` Add Git configuration for WORK-PC setup
- `9b3e637`, `cd9d644` Add prepare-commit-msg hook for PowerShell
- `3af2a85` Update .editorconfig for file-specific indent sizes
- `aa05b16` Update .gitignore to ignore Git worktrees
- `e8d4c82`, `4b50fb5` Update gitconfig(s)

## Early history (2022-07 – 2023-07)

The repository started as a Linux/bash dotfiles collection, migrated from a self-hosted
Gitea server to GitHub (`e02881f`, `c47ee79`). Development in this period wasn't
conventional-commit tagged; themes below are summarized rather than listed commit by
commit.

- **bash**: bashrc/bash_aliases/inputrc built up incrementally — vi-mode keybinding
  fixes, git-aware prompt with ahead/behind and dirty-state parsing, HIST* tuning via
  mrzool/bash-sensible (`6cb7fb7`, `a4f9779`, `0f9eb88`, `f3933cd`, `5f109e2`)
- **fzf**: `fzfrc` added with fzf scripts (`3b3c46c`)
- **git**: aliases and config built up across many small commits, including `undo`,
  `groot`, and a `delete-merged-branches` alias that skips `deploy/*` (`23075d4`,
  `185942c`, `dd5c21c`, `936ff45`, `c2532a5`, `513402e`)
- **Nix home-manager**: adopted for package/config management, with a shared
  `home.nix` plus host-specific imports resolved from `/etc/hostname` or `$USER`
  (`dff5c42`, `a508063`, `09f3e02`, `ddfbbc7`)
- **vim**: configs collated into a single vimrc, then experiments with vim-plug,
  palenight, and Catppuccin colorschemes (`2cf6aa9`, `82ebfa8`, `6243b65`)
- **PowerShell**: a first pwsh profile added for use under WSL bash, including a
  dirtrim function using `[IO.Path]::DirectorySeparatorChar` (`0bc26b3`, `d22ba2e`, `9d5b56b`)
- **Neovim**: `init.lua` started alongside the vimrc, with plugins added via a
  vim-plug bootstrap (`95b9bda`, `ff7f419`)
- devcontainer install script for VS Code dotfiles (`48d38fe`)
- repo cleanup: unused themes, logs, and legacy dotfiles removed (`ffab506`)

Two isolated gitconfig updates mark an otherwise quiet stretch before Windows-side
development resumed: `140ef27` (2024-11-13) and `a0afd17` (2025-04-03).
