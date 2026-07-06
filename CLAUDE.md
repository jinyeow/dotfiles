# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository scope

Personal dotfiles spanning Windows (PowerShell 7) and Linux/WSL (bash, Neovim, tmux, i3/bspwm). Active development is on the **Windows side**: the PowerShell profile under `powershell/`, the prompt in `powershell/Profile/Set-Prompt.ps1`, the Neovim Lua config under `nvim/`, the Zellij config under `zellij/`, the Yazi config under `yazi/`, and the git config under `git/`. Configs are organized into per-tool directories: `git/`, `nvim/`, `vim/`, `bash/`, `powershell/`, `tig/`, `tmux/`, `zellij/`, `yazi/`, `fzf/`, `curl/`, `claude/`, `codex/`, `windowsterminal/`. The Linux setup (`bootstrap.sh`, `Makefile`, `pwsh_profile.ps1`, the Arch package lists in the `install:` target, `config/bspwm`, `config/sxhkd`, etc.) is a legacy snapshot — touch only when explicitly asked.

`pwsh_profile.ps1` at the repo root is the **old** profile and is superseded by `powershell/Microsoft.PowerShell_profile.*.ps1`. Edit the per-machine file under `powershell/`, not the root one.

Note the two `CLAUDE.md` files: this root one is **project instructions for the dotfiles repo**; `claude/CLAUDE.md` is the **global user instructions** that `setup.ps1 -Module claude` installs to `~/.claude/CLAUDE.md`. They are unrelated — don't merge them. See `claude/README.md` for the Claude Code module (settings, statusline, skills, agents); its files are **symlinked** into `~/.claude` on both Windows and Linux (Windows file symlinks need Developer Mode; skill dirs are junctioned on Windows), so the live files and the repo never drift.

**Shared agent conventions live in `claude/AGENTS.md`** (single source). `claude/CLAUDE.md` imports it via `@AGENTS.md`, and the `codex` module installs the same file to `~/.codex/AGENTS.md`, so Claude Code and Codex CLI follow identical coding conventions. Edit conventions in `claude/AGENTS.md` only; keep `CLAUDE.md` to Claude-specific behaviour. See the Claude + Codex integration section below.

## Per-machine convention

Machine-specific variants use the suffix `.<HOSTNAME>` before the extension and live alongside the base file:
- `nvim/` — no per-machine variant yet; use `.<HOSTNAME>` suffix on `init.lua` when needed

The PowerShell profile (`powershell/Microsoft.PowerShell_profile.ps1`) is a single shared file — no per-machine variant. Git identity is handled per-repo via `[includeIf]` — see the Git configuration section.

## Installation entry points

| Script | Target | Notes |
|---|---|---|
| `setup.ps1` | Windows | Module-based installer. `-Module neovim,vim,powershell,git,bash,tig,tmux,zellij,yazi,curl,claude,codex,serena,context7,fastmail,lazygit,windowsterminal,bat,vscode,winget` or `-Module all`. Supports `-DryRun`. |
| `setup.sh` | Linux / WSL | Module-based installer. `-m neovim,vim,powershell,git,bash,tig,tmux,zellij,curl,claude,lazygit,windowsterminal` or `-m all`. Supports `--dry-run`. (No `codex` module yet — Windows only.) |

`setup.ps1` argument handling has Pester tests in `tests/setup.Tests.ps1` (run `Invoke-Pester -Path tests`); they invoke the installer in `-DryRun` so nothing is mutated.

## PowerShell profile architecture

`Microsoft.PowerShell_profile.ps1` is structured as **three phases** to keep startup fast:

1. **Phase 1 (blocking, must stay cheap)**: module-availability cache (single `PSModulePath` scan into `$global:ProfileModules`), PSReadLine with `PredictionSource History` only, keybindings, dot-source `Profile/Set-Prompt.ps1` (which defines but no longer *calls* `Initialize-AzTimer`), aliases, tool wrapper functions (`y` for yazi).
2. **Phase 2a (first idle)**: `Initialize-DeferredProfile` loads PSFzf and zoxide, upgrades PSReadLine to `HistoryAndPlugin`, sets the fd-backed `FZF_*_COMMAND` vars, defines the eza `ll`/`la`/`lt` helpers, and calls `Initialize-AzTimer` (Az context timer — `runspace.Open()` + first eventing call ~200ms, moved off the load path). Guarded by `$global:ProfileDeferredDone`. These are the interactive tools needed immediately after the prompt appears.
3. **Phase 2b (next idle)**: `Initialize-DeferredProfileSecondary` registers the az + zellij native tab-completers and loads git-completion (+ `g` alias completer) and WinGet CommandNotFound. Guarded by `$global:ProfileDeferredSecondaryDone`. Split from 2a so the first keypress isn't blocked by their import cost.
4. **Phase 3 (async runspace)**: Az context refresh on a 60s timer. The timer is created in Phase 2a (`Initialize-AzTimer`); the refresh itself runs in a background runspace wired up in `Set-Prompt.ps1`.

When adding to the profile, classify by cost first — anything that loads .NET assemblies or scans the filesystem belongs in Phase 2, not Phase 1. Use the `$global:ProfileModules` cache rather than calling `Get-Module -ListAvailable` again.

## Prompt architecture (`Set-Prompt.ps1`)

- **Git is synchronous** — uses 3 git processes per prompt (`rev-parse` combined, `rev-list`, `status --porcelain`). The combined `rev-parse --abbrev-ref HEAD --git-dir --git-common-dir` doubles as the "are we in a repo" gate and detects worktrees (when git-dir ≠ git-common-dir).
- **jj (Jujutsu) takes precedence over git** (`Get-JjPromptInfo`, toggle `ShowJj`). The gate is `Find-JjRoot` — a pure filesystem walk up to a `.jj` dir, so non-jj dirs spawn no jj process and the found dir doubles as the truncate-to-repo anchor. When a jj repo is detected the git segment is skipped entirely (avoids git's detached-HEAD noise in colocated repos). Inside a jj repo it runs up to 3 jj processes (`@` info template, closest-bookmark name, bookmark→@ distance), all with `--ignore-working-copy` so the prompt never snapshots the working copy. **Tradeoff:** `FileCount` and the empty (`∅`) flag therefore reflect the *last* snapshot jj took, not un-snapshotted editor edits. Segment renders as `jj:<change-id> <closest-bookmark> ↑<dist> *<files> ∅ ✎` (`∅` = empty, `✎` = no description, `!` = conflict).
- **Az context is async** via a long-lived background runspace, refreshed every 60s by a `System.Timers.Timer`. The timer's `Elapsed` handler runs in a separate runspace and cannot see main-session functions, so it bridges back via `New-Event 'Profile.AzRefreshRequested'` → `Register-EngineEvent` (which *does* run in the main session and can call `Start-AzContextRefresh`). Don't try to call session functions directly from `Register-ObjectEvent -Action`. **`Initialize-AzTimer` is defined in `Set-Prompt.ps1` but called from Phase 2a** (not at profile load) — `runspace.Open()` plus the first eventing call cost ~200ms blocking; deferring it to first idle keeps startup fast, at the cost of the ☁ segment appearing one idle later. Its `PowerShell.Exiting` cleanup handler is registered inside `Initialize-AzTimer` for the same reason.
- **Idempotency**: every event registration unregisters prior subscribers first so `. $PROFILE` reloads don't stack handlers. `Get-EventSubscriber -SourceIdentifier` does **not** support wildcards — filter with `Where-Object`. `-SupportEvent` subscribers are hidden and require `-Force` to find.
- **`$?` / `$LASTEXITCODE` must be captured on the first two lines of `prompt`** before any other command runs, and `$LASTEXITCODE` is restored at the end so git calls inside the prompt don't leak a non-zero exit to the user's next command.
- Constants (ANSI escapes, admin check, length limits) are computed once into `$global:PromptConst`; the prompt body uses a `StringBuilder`.
- Emits Windows Terminal OSC 9;9 for CWD tracking when on a filesystem provider, and syncs `[System.Environment]::CurrentDirectory` so Zellij opens new panes in the current directory (see the Zellij section).
- **zoxide recording is driven by the prompt, not by zoxide's hook.** Zoxide is initialised with `zoxide init powershell --hook none` (Phase 2a), so it does *not* wrap `$function:prompt`. The default wrapper detaches on `. $PROFILE` (Phase 1 redefines the prompt and the deferred-once guard blocks re-wrapping), which silently stops recording. Instead the prompt records the directory itself inside the filesystem-provider block (mirroring zoxide's `__zoxide_hook`: dedup on `$global:__zoxide_oldpwd`, `zoxide add` only when it changed) — survives reloads, and the line-end `$LASTEXITCODE` restore undoes the exit code `zoxide add` leaves behind. It self-guards on `$function:__zoxide_pwd` (defined only with `--hook none`) so it no-ops until Phase 2a initialises zoxide.

## Git configuration

Files live under `git/`: `gitconfig` (base), `gitconfig-work` (work overrides), `gitignore`, `gitmessage`, `templates/hooks/`.

- `core.hooksPath = ~/.git_templates/hooks` — global hook directory, so `prepare-commit-msg` runs on every repo. Branches like `feature/PROJ-123-foo` get `[PROJ-123]-` prepended to commit messages; the skip list (`master`, `develop`, `staging`, deploy/*) is in the hook.
- `init.templatedir = ~/.git_templates` — new repos inherit the hooks too.
- `init.defaultBranch = main`, `pull.ff = only`, `push.autoSetupRemote = true`, `rebase.autoStash = true`, `rebase.updateRefs = true` (stacked branches), `rerere.enabled = true`.
- Pager and diff filter are **delta** (`core.pager = delta`, `interactive.diffFilter = delta --color-only`).
- `url."git@github.com:".insteadOf` rewrites both `https://github.com/` and the `gh:` shorthand to SSH.
- **Identity**: base `gitconfig` sets personal `[user]` (`justin@puah.dev`). Work identity is applied per-repo via `[includeIf "hasconfig:remote.*.url:*hollard*"]` which includes `gitconfig-work` (sets `justin.puah@hollard.com.au` + `diff.tool = delta`). Requires Git 2.36+. For local-only work repos without a remote, run `git config user.email justin.puah@hollard.com.au` manually.
- **Installer**: `setup.ps1/setup.sh -Module git` installs `~/.gitconfig` and `~/.gitconfig-work` as git `[include]` stubs pointing to the repo files (cross-volume safe, always live), then junctions `~/.git_templates` → `git/templates/`.

## Claude Code + Codex integration

Codex CLI is wired in as a **read-only second-opinion reviewer** for Claude Code (Claude is the primary driver; the integration is one-way, Claude → Codex). See `codex/README.md` for the full design.

- **MCP reviewer**: registered at **user scope** (in `~/.claude.json`, not a tracked file — `settings.json` can't hold `mcpServers`). `setup.ps1 -Module codex` runs `claude mcp add --scope user codex -- codex mcp-server -c sandbox_mode=read-only -c approval_policy=never`. The `-c` overrides pin the reviewer read-only/non-interactive regardless of `~/.codex/config.toml`.
- **Two postures, one config**: `codex/config.toml` sets the **standalone** posture (`workspace-write` + `on-request`) for when you run `codex` directly; the MCP registration overrides to **read-only/never** for the reviewer path.
- **Shared conventions**: `claude/AGENTS.md` installs to both `~/.claude/AGENTS.md` (imported by `CLAUDE.md`) and `~/.codex/AGENTS.md`, so both tools obey the same rules. Codex also concatenates a repo's own `AGENTS.md` on top — that's the layering point for work overlays (`codex/templates/work-AGENTS.md`).
- **Trigger**: review is **on-demand only** — the `/codex-review` skill, or Claude *offers* a second opinion after a change but never calls Codex or applies findings without approval (see `claude/CLAUDE.md` → "Codex second opinion"). Auth is `codex login` (interactive, run once).
- **Skills**: `codex/skills/` holds global custom skills in Codex's own format (`SKILL.md` + optional `agents/openai.yaml`), junctioned per-subdirectory into `~/.codex/skills/` by `setup.ps1 -Module codex` — the same pattern the claude module uses for `claude/skills/`. Codex has no separate top-level "agents" dir like Claude; an "agent" there is just an `agents/openai.yaml` nested inside a skill folder, so the skills junction covers both. Codex's own built-in skills live alongside at `~/.codex/skills/.system/` and are untouched.

## Claude Code hooks (`claude/`)

`claude/settings.json` wires `SessionStart`/`UserPromptSubmit`/`PreToolUse`/`PostToolUse` hooks alongside the Stop/Notification beeps. The seven pwsh hooks (`inject-handoff.ps1`, `block-destructive-vcs.ps1`, `block-pwsh-in-bash.ps1`, `lint-powershell.ps1`, `warn-legacy-files.ps1`, `warn-hardcoded-secrets.ps1`, `warn-reasoning-extraction.ps1`) are symlinked into `~/.claude` by `setup.ps1/setup.sh -Module claude` and invoked through **bash** (`pwsh -NoProfile -File ~/.claude/<x>.ps1`) so `~` expands; each reads the hook JSON on stdin, **fails open**, and emits JSON only when it acts. The older `no-claude-session-trailer.sh` (bash) is the eighth hook. The `handoff` skill writes `.claude/handoff.md` in the workspace; `inject-handoff.ps1` is the `SessionStart` hook that reads it back into a fresh session (on `startup`/`clear`) via `additionalContext` — nothing else auto-reads that file. See `claude/README.md` → Hooks for the full table.

### Key decisions (do not reverse without asking)

- **Deterministic guardrails, not only the skill.** `block-destructive-vcs.ps1` denies destructive **git** (`push --force` — allows `--force-with-lease` —, `reset --hard`, `clean -f`, `branch -D`) as a non-bypassable `PreToolUse` deny, where the `git-guardrails` skill only *advises*. **jj is intentionally ungated** (its op-log makes rewrites recoverable). `block-pwsh-in-bash.ps1` denies PowerShell sent to the Bash tool, enforcing the pwsh-native rule.
- **Both deny hooks strip quoted substrings before matching**, so a destructive phrase quoted in a commit message (`git commit -m "reset --hard …"`) or a separator inside a quoted arg does not mis-trigger. VCS matching is **case-sensitive** on purpose: `git branch -d` (safe) and `-D` (force) differ only by case, so a case-insensitive match would deny the safe form too. Cmdlet detection is command-position + capitalized `Verb-Noun` only (lowercase cmdlets are *not* caught — that would false-block executables like `start-stop-daemon`).
- **Lint is a per-file inner-loop nudge, not CI.** `lint-powershell.ps1` runs PSScriptAnalyzer on the single edited `.ps1/.psm1/.psd1` (using the nearest `.vscode/PSScriptAnalyzerSettings.psd1` when present) and feeds findings back via `additionalContext` — non-blocking. It does **not** replace the full `-Recurse` run CI does over the whole source tree (a per-file pass can miss violations in untouched files).
- **The two `warn-*` hooks replace the `hookify` plugin** (disabled in `enabledPlugins`), which was broken on Windows — its hooks shell out to `python3`, which resolves to the Microsoft Store stub. `warn-legacy-files.ps1` (`PreToolUse` Edit|Write) emits an **`ask`** decision before editing a legacy/do-not-touch dotfile (root `pwsh_profile.ps1`, `bootstrap.sh`, `Makefile`, `config/bspwm|sxhkd/`); it is **scoped to `$env:DOTFILES`** so the globally-wired hook never fires on same-named files in other repos, and no-ops if `$env:DOTFILES` is unset. `warn-hardcoded-secrets.ps1` (`PostToolUse` Edit|Write) warns via `additionalContext` when written content looks like a secret (assigned api-key/secret/token/password, private-key block, AWS access-key id); **global** on purpose, and it reports only rule names, never the matched value. Both are advisory, not hard denies.
- **`warn-reasoning-extraction.ps1` guards the Fable-5 `reasoning_extraction` fallback (lever 5).** Reasoning-extraction phrasing (`'explain your reasoning step by step'`, chain-of-thought demands) can trip Claude Fable 5's refusal → fallback to Opus (Claude Code shows a transcript notice; the raw API returns `stop_reason: refusal`) — costly because subagents often run Fable under an Opus main loop. One script, two wirings: on **`UserPromptSubmit`** it warns via `additionalContext` (never denies a user prompt); on **`PreToolUse` Edit|Write** it emits an **`ask`** only when the phrase is being written into a config/prompt-bearing file (`CLAUDE.md`, `AGENTS.md`, `*SKILL.md`, `agents/*.md`, `codex/**`) — the worst case, a *standing* instruction persisted into config. Like the deny hooks it **strips quoted substrings before matching** (so docs that quote the phrase to ban it don't self-trigger) and applies a negation guard (`never`/`don't`/…). Advisory + ask, never a hard deny; reports rule names only. The full 12-lever set it enforces lives in `claude/AGENTS.md` → "Prompting downstream models".

## Code intelligence (serena + ast-grep)

Two tools give the coding agent better-than-grep understanding of the code:

- **serena** — a semantic code-intelligence MCP (LSP-backed: symbol search, find-references, type hierarchy, symbol-level edits) covering the whole stack including **PowerShell** and **C#**. `setup.ps1 -Module serena` installs it as a `uv` tool (`uv tool install -p 3.13 serena-agent`, `uv` from the `winget` module) and registers it at **user scope** in `~/.claude.json` (`claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd --open-web-dashboard False`) — the same registration model as the codex MCP. It activates a project from each session's working dir; the MCP loads at session start, so a new session is needed after registering. The `--open-web-dashboard False` flag stops a dashboard window opening on every session; to also tie a manually-opened dashboard to the session lifecycle, set `web_dashboard_interface: app` in the machine-local `~/.serena/serena_config.yml` (no CLI flag exists for the interface, so it isn't reproducible from the repo).
- **ast-grep** (`ast-grep.ast-grep`, alias `sg`; in `winget/packages.json`) — tree-sitter **structural** search/replace, used straight from the shell (no server). Covers C#, Lua, JS/TS, Bash, YAML, etc. — **not PowerShell** (no built-in grammar), which is exactly the gap serena fills.

The `.serena/` dir is created per-project on first activation. Commit the whole dir and let serena's own nested `.serena/.gitignore` (`/cache`, `/project.local.yml`) filter it — that leaves `.serena/.gitignore` and `.serena/project.yml` (the shared, versioned config: `project_name`, `languages`) tracked, while the machine-specific symbol cache and local overrides stay untracked. Keep anything machine-specific or private out of `project.yml`; it belongs in the ignored `project.local.yml`. In **work (Hollard) repos** `.serena/` is excluded entirely via `git/gitignore-work` so it is never pushed.

## Documentation lookup (Context7)

**Context7** is a hosted MCP that serves up-to-date, version-specific library/API docs on demand — it complements the **Microsoft Learn** MCP (which only covers MS/Azure) for third-party packages (npm, .NET, Lua/Neovim plugins, etc.).

- **Registration**: `setup.ps1 -Module context7` registers it as a **remote HTTP** MCP at **user scope** in `~/.claude.json` (`claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp`) — same registration model as codex/serena, but HTTP transport (like the other hosted connectors) instead of a local stdio command, so there is **nothing to install** and no Node/`uv` dependency. The MCP loads at session start, so a new session is needed after registering.
- **API key (optional)**: basic use is anonymous and rate-limited. Set `$env:CONTEXT7_API_KEY` (free key from `context7.com/dashboard`) **before** running the module to raise limits — it is passed as a request `CONTEXT7_API_KEY` header and stored only in `~/.claude.json` (untracked), never committed. Re-run the module to apply.
- **Windows-only**, like the codex/serena modules: `setup.sh` does not register MCP servers.

## Fastmail MCP (`fastmail`)

Fastmail's **official** hosted MCP server gives Claude Code read access to email, calendar, and contacts — used for inbox summaries, surfacing important mail, and listing upcoming events/deadlines (all read-only; it never sets flags or sends).

- **Registration**: `setup.ps1 -Module fastmail` registers it as a **remote HTTP** MCP at **user scope** in `~/.claude.json` (`claude mcp add --scope user --transport http fastmail https://api.fastmail.com/mcp`) — same model as context7/codex/serena, nothing to install. The MCP loads at session start, so a new session is needed after registering.
- **Auth is a separate one-time step** (unlike context7's API-key header): Fastmail uses **OAuth 2.0**, so the module registers the endpoint only. Run `claude mcp login fastmail` (needs Claude Code ≥ 2.1.186; on older builds use the `/mcp` command in a session instead), complete the browser consent, and **choose Read-only** on Fastmail's consent screen. This mirrors the `codex login` pattern — the OAuth flow is interactive and can't be done from the installer.
- **Read-only is a consent-screen choice, not a CLI flag.** Fastmail's advertised OAuth scopes are domain-based (`…:mail`, `…:contacts`, `…:calendars`); the read/write/send *access tier* is picked at consent and can't be pinned by `claude mcp add`. So reproducibility stops at endpoint registration — the access level is set (and revoked) by you, in Fastmail (Settings → Privacy & Security → Connected apps, or `claude mcp logout fastmail`).
- **Idempotency**: the module does `remove`-then-`add`, which rewrites only the `~/.claude.json` entry. OAuth credentials are managed separately via `login`/`logout`, so re-running `setup.ps1` never silently revokes auth.
- **Why the official server over community JMAP servers**: the community Fastmail/JMAP MCPs (Jordonh18, doronkatz, MadLlama25, wyattjoh) are **email-only** — JMAP calendar is still an IETF draft and isn't exposed to API tokens, so they can't surface calendar events. The official server isn't limited to the public JMAP token surface, so it has calendar + contacts.
- **Verify**: `claude mcp get fastmail`. **Windows-only**, like the other MCP modules: `setup.sh` does not register MCP servers.

## Subagents (`claude/agents/`)

User-scope Claude Code subagents live as flat `.md` files (frontmatter + system-prompt body) under `claude/agents/`, installed to `~/.claude/agents/`. See `claude/README.md` for the full design.

- **Whole-dir link, not per-file** — the entire `agents/` dir is junctioned (Windows) / symlinked (Linux), deliberately unlike skills (junctioned per-subdir). Agents are flat files in a dir nothing else writes to, so this keeps live == repo *and* lets agents created via `/agents` land straight in the repo.
- **Bodies are self-contained** — a subagent body cannot `@import AGENTS.md`. Share conventions via the `skills:` frontmatter field (injects a skill's `SKILL.md` at startup) or restate them in the body with a maintenance note to keep them in sync with `claude/AGENTS.md`.
- **Roster**: `pwsh-implementer` — TDD PowerShell 7+ specialist (`skills: tdd`, `model: inherit`); `powershell-module-architect` — its module *design/review* companion (`model: inherit`, no `skills:` preload) that owns module layout/manifest/structure and reports unwritten behaviour (function bodies + tests) for the caller to dispatch to `pwsh-implementer`; `csharp-implementer` — the C#/.NET TDD counterpart (xUnit first, `skills: tdd`, Microsoft `src`/`tests/<Proj>.Tests` layout matching the `<leader>A` toggle); `bicep-implementer` — Azure Bicep IaC specialist (`skills: bicep-tdd`, strictly offline — no tenant auth/what-if/deploy); and `chief-orchestrator` — coordination-only fan-out agent (has the `Agent` tool for nested dispatch, deliberately **no Write/Edit**; locks contracts + file ownership, integrates, verifies once). Role-based, not domain-based; we dropped proposed `explorer`/`reviewer` as redundant with the built-in `Explore` agent and `code-review` skill + Codex. The orchestrator's roster table must be updated when agents are added/removed.

## Conventions

- **EditorConfig**: 2-space default, LF, UTF-8, trim trailing whitespace, final newline. Overrides: 4-space for `*.sh`/`*.bash*`, `git*`/`.git*`, and `*.ps1`/`*.psd1`/`*.psm1`.
- **Commit style**: imperative, sometimes `feat:` / `fix:` prefixed (`feat: Refactor Set-Prompt.ps1 for async Azure and Git support`). Stay consistent with the surrounding files' recent history.
- **PowerShell**: target pwsh 7 (`#Requires -Version 7`), Vi edit mode, custom Vi cursor handler (`OnViModeChange` toggles `` `e[1 q `` ↔ `` `e[5 q ``), `Ctrl+Oem4` (left bracket) for `ViCommandMode` — see [PSReadLine #906](https://github.com/PowerShell/PSReadLine/issues/906#issuecomment-916847040).

## Neovim (`nvim/`)

Modular Lua config targeting Neovim 0.12+. Uses `vim.pack` (Neovim 0.12 built-in package manager) — no external plugin manager. LSP is configured via the native `vim.lsp.config` / `vim.lsp.enable` API (not the lspconfig Lua framework).

Load order: `performance` → `user` → `plugins` → `options` → `keymaps` → `autocmds` → `treesitter` → `lsp` → `gitsigns` → `ui`

The `vim/` directory (Vimscript setup) is the older Vim config — kept as the Linux fallback, not the active Neovim config. `vim/vimrc` is the vimrc; Vim finds it automatically at `~/.vim/vimrc` (Linux) or `~/vimfiles/vimrc` (Windows).

### Key decisions (do not reverse without asking)

- **Plugin manager**: `vim.pack` (Neovim 0.12 built-in). `vim.pack.add(specs, { load = true, confirm = false })` in `plugins.lua` — installs in parallel on first launch, writes a lock file to `nvim/nvim-pack-lock.json`. Plugins stored in `nvim-data/site/pack/core/opt/`. Do not revert to `ensure_plugin()` or a third-party manager.
- **Treesitter branch**: `nvim-treesitter` (and `-textobjects`) are **pinned to `master`** in `plugins.lua` (`{ src = …, version = 'master' }`). Upstream archived the repo (2026-04) and made `main` the default — but `main` is a from-scratch rewrite that drops the `require('nvim-treesitter.configs').setup{}` module framework `treesitter.lua` relies on. Do not unpin to `main` without rewriting `treesitter.lua`. Building parsers needs a C compiler on PATH; **Zig** (`winget install zig.zig`) is used as `zig cc`. After changing `version`, vim.pack only re-checks-out on `vim.pack.update()` (a changed spec alone doesn't move an installed plugin); vim.pack also rewrites the lockfile `version` as `'master'` (quoted) on every startup — that's expected, leave it.
- **LSP API**: `vim.lsp.config` / `vim.lsp.enable` only. Do not use `require('lspconfig').xxx.setup{}`.
- **`_G.user_config`**: defined in `user.lua`, read by `lsp.lua` and `ui.lua`. Controls `profile` (`full`/`minimal`), LSP tool paths, and sunrise/sunset fallback hours for theme detection.
- **Profile system**: `NVIM_PROFILE=minimal` disables all plugins and uses a built-in colorscheme. Each module guards itself with an early return so the env var is the only thing to set.
- **Theme detection**: `ui.lua` queries OS dark/light mode (Windows registry → macOS `defaults` → GNOME `gsettings` → KDE `kreadconfig5`), falls back to `sunrise_hour`/`sunset_hour` from `user.lua`.
- **`vim.loader.enable()`**: must remain the first line of `performance.lua`.
- **Bicep filetype**: no built-in Neovim support — autocmd in `lsp.lua` registers `filetype = bicep` for `*.bicep`, only when `bicep_lsp_path` is non-empty.
- **Azure Pipelines filetype**: `autocmds.lua` sets `filetype = azure-pipelines` for `*.azure-pipelines.yml/yaml` so `azure_pipelines_ls` attaches exclusively and `yamlls` does not compete. Because that custom filetype has no Treesitter grammar of its own, `autocmds.lua` also calls `vim.treesitter.language.register('yaml', 'azure-pipelines')` so highlighting/indent fall back to the `yaml` parser — without it the buffer renders unhighlighted.
- **C# / .NET**: `roslyn.nvim` (seblyng) is the C# LSP — not OmniSharp. Configured in `lsp.lua` (`require('roslyn').setup({})` + `vim.lsp.config('roslyn', …)`), gated on `dotnet` being on PATH (no `user_config` field). Analysis scope is pinned to `openFiles` (not `fullSolution`) — a deliberate perf choice. `*.cs` is a built-in filetype, so no autocmd is needed. Testing/run/build are buffer-local keymaps (`<leader>nt/nr/nb`) in `after/ftplugin/cs.lua` that shell out to the `dotnet` CLI — no `easy-dotnet`/plugin, kept minimal on purpose. Inlay hints are off by default (`<leader>th` toggles). Prerequisite global tool: `dotnet tool install -g roslyn-language-server --prerelease` (auto-detected on PATH).
- **oil git status**: `refractalize/oil-git-status.nvim` shows per-file git status in oil's two sign columns (left = index, right = working tree). Requires oil's `win_options = { signcolumn = 'yes:2' }` (set in `ui.lua`) and `require('oil-git-status').setup()`.
- **Lockfile discipline**: `nvim/nvim-pack-lock.json` is vim.pack-managed — any `plugins.lua` change must be reflected there (launch nvim or `vim.pack.update()` to regenerate) and **committed together** with the plugin edit.
- **Offline / GitHub-blocked install**: `nvim/Install-PluginsOffline.ps1` provisions plugins and Treesitter parsers without cloning from `github.com`, for machines where it is blocked but `codeload.github.com` (the ZIP host) is reachable. It reads `nvim-pack-lock.json`, downloads each plugin as a ZIP of its pinned rev into `<data>/site/pack/core/opt/<name>` — `vim.pack` loads any dir matching a valid lockfile entry via `:packadd` with no git calls, so a plain ZIP extract works. For parsers, it stages each `ensure_installed` grammar's source from codeload (repo from nvim-treesitter's parser config, rev from its `lockfile.json`) and lets nvim-treesitter compile from the **local** path (no network), using `zig` as the compiler. Every `nvim` call runs without the user config (`-u NONE` / minimal `packadd`) so `vim.pack.add` never fires a blocked clone. Rev-aware idempotent (per-dir `.codeload-rev` markers + a central parser-rev file) — re-run after a lockfile change to update. The parser step needs a C compiler (`winget install zig.zig`) **and** the `git` executable present (nvim-treesitter requires it, though no network is used).
- **No per-machine variants yet**: single `init.lua` only — no `init.WORK-PC.lua`. Apply the `.<HOSTNAME>` suffix convention when machine-specific behaviour is needed.
- **Source/test alternate toggle**: `<leader>A` (`alternate_test_file` in `autocmds.lua`) swaps a source file and its mirrored test, lazy-bound to `cs`/`ps1` buffers via a `FileType` autocmd (no plugin). Conventions are deliberate: C# follows the Microsoft/xUnit layout (`src/<Proj>/Foo.cs ↔ tests/<Proj>.Tests/FooTests.cs` — project folder gains `.Tests`, filename suffix `Tests` with no dot); PowerShell follows Pester (`src/…/Foo.ps1 ↔ tests/…/Foo.Tests.ps1`, pure `src`↔`tests` mirror). The project root is resolved with `vim.fs.root(abs, { '.git', '.jj' })` — `.jj` is required because non-colocated Jujutsu repos have no `.git`, and anchoring on the root (not the nearest/leftmost `src`/`tests` segment) is what avoids both the ancestor-dir and nested-dir false positives. Behaviour is open-or-create (tpope projectionist model): jump to the counterpart if it exists, else open an unsaved buffer whose parent dirs are created lazily on first write.

### Install

Installed via `setup.ps1` (Windows) or `setup.sh` (Linux) at the repo root — see the Installation entry points section. The per-tool install scripts inside `nvim/` (`install.sh`, `install.ps1`, `install.py`) are an older standalone installer kept for backward compatibility.

## Zellij (`zellij/`)

Single KDL config file at `zellij/config.kdl`. Installed via `setup.ps1 -Module zellij` (Windows — junction of the whole `zellij/` dir) or `setup.sh -m zellij` (Linux — symlink of `config.kdl`).

### Key decisions (do not reverse without asking)

- **Locked-first**: `default_mode "locked"` — all input passes to the pane by default; Ctrl+g enters command mode. Do not change the default mode.
- **Default shell**: `default_shell "pwsh"`. Zellij opens new panes in the focused pane's Win32 process CWD, which pwsh's `Set-Location` does not update (only its provider location moves), so panes would open at `$HOME`. Worked around in the PowerShell profile: `Set-Prompt.ps1` sets `[System.Environment]::CurrentDirectory` each prompt (see upstream [zellij#5052](https://github.com/zellij-org/zellij/issues/5052)). Not fixable in Zellij's own config.
- **Themes**: `theme_dark "catppuccin-mocha"` / `theme_light "catppuccin-latte"`. Theme files live in `zellij/themes/` using the new semantic format (`text_unselected`, `ribbon_selected`, etc.) required by Zellij 0.40+. The old `fg`/`bg` palette format renders incorrectly — do not revert to it. Windows Terminal does not emit CSI 2031 so auto-switching does not work; use `zellij action toggle-theme` manually.
- **Color under Windows Terminal**: Zellij mishandles terminal color negotiation (truecolor fallback + OSC 11 background queries), which breaks diff/TUI colors in tools running inside it. Two workarounds are in place — `COLORTERM=truecolor` in the PowerShell profile and pinning Claude Code to a `*-ansi` theme. See `docs/zellij-windows-terminal-colors.md`.
- **Pane navigation**: `Alt+hjkl` in locked mode moves between Zellij panes (`MoveFocusOrTab` on left/right). Inside nvim, use `Ctrl+w hjkl` for window splits; at the window edge nvim falls back to `zellij action move-focus` via CLI (see `keymaps.lua`). vim-zellij-navigator and zellij-nav.nvim have been removed.
- **No layout files yet**: single `config.kdl` only. Add layouts to `zellij/layouts/` if needed.

## Yazi (`yazi/`)

Three config files: `yazi.toml` (manager/opener/preview settings), `keymap.toml` (keybinding additions via `prepend_keymap`), `theme.toml` (flavor reference). Installed via `setup.ps1 -Module yazi` (Windows — junction of the whole `yazi/` dir to `%AppData%\yazi\config\`).

### Key decisions (do not reverse without asking)

- **Junction strategy**: the entire `yazi/` dir is junctioned to `%AppData%\yazi\config\`, so `package.toml` (the `ya pkg` lock file) is version-controlled alongside the hand-written config. `plugins/` and `flavors/` are gitignored because they are downloaded content managed by `ya pkg`.
- **Editor opener**: `nvim %s` with `block = true` — yazi suspends while nvim is open. No platform split needed since nvim is on PATH everywhere.
- **Enter behaviour**: opens with the first matching `[open]` rule — text/code → nvim, everything else → OS default (`start`, `xdg-open`, `open`). Press `o` to get the interactive picker instead. **Exception**: `text/html` has a dedicated rule above `text/*` that prefers `open` (so Enter opens HTML in the default browser, not nvim); edit is still on the `o` picker.
- **MIME detection (`file`)**: yazi shells out to `file(1)` to guess MIME types that its rules don't match (without it, `text/html` etc. fall back and Enter rules misfire). Windows has no native `file`, so the PowerShell profile points yazi at Git for Windows' bundled `file.exe` via `YAZI_FILE_ONE` (`$env:ProgramFiles\Git\usr\bin\file.exe`, guarded by `Test-Path`) — avoids putting Git's `usr\bin` on PATH. Verify with `yazi --debug` (look for the `file` and `YAZI_FILE_ONE` lines).
- **Theme**: `catppuccin-mocha` (dark) / `catppuccin-latte` (light) via the flavor system, matching Zellij. Run `ya pkg add yazi-rs/flavors:catppuccin-mocha` and `ya pkg add yazi-rs/flavors:catppuccin-latte` after `setup.ps1`.
- **Plugins**: installed via `ya pkg add` (recorded in `package.toml`; the `plugins/` dir itself is gitignored, so re-run the `ya pkg add`s after `setup.ps1` on a fresh machine).
  - `git.yazi` (VCS status as a linemode) — `ya pkg add yazi-rs/plugins:git`. Wiring is in tracked config: `init.lua` calls `require("git"):setup{ order = 1500 }` and `yazi.toml`'s `[plugin].prepend_fetchers` registers it. On yazi > v26.1.22 the fetchers drop the `id` field and dedup by `group` — keep that form. Shells out to `git`, so git must be on PATH.
  - `lazygit.yazi` (open lazygit in the cwd) — `ya pkg add Lil-Dank/lazygit`. Bound to `g i` via `keymap.toml`'s inline `prepend_keymap` array (the README's `[[mgr.prepend_keymap]]` block form would collide with the existing inline array — keep the inline form). Needs `lazygit` on PATH.
- **Shell wrapper**: `y` function in the PowerShell profile wraps `yazi --cwd-file` so the shell follows yazi's final directory on quit. `yazi` still works as-is.
- **Keymap style**: defaults are kept intact; only `prepend_keymap` additions are used. Do not switch to a full `keymap` replacement.
