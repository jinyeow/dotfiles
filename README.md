# dotfiles

Personal dotfiles for Windows (primary) and Linux/WSL.

## Structure

| Directory | Tool | Platform |
|---|---|---|
| `powershell/` | PowerShell 7 profile + prompt | Windows |
| `nvim/` | Neovim (Lua, 0.11+) | Windows + Linux |
| `git/` | Git config, hooks, ignore | Windows + Linux |
| `vim/` | Vim config (Linux fallback) | Linux |
| `bash/` | Bash config + fzf helpers | Linux / WSL |
| `tig/` | Tig terminal git browser | Windows + Linux |
| `fzf/` | fzf default options + catppuccin theme | Windows + Linux |
| `curl/` | Global curl defaults | Windows + Linux |
| `ripgrep/` | ripgrep config | Windows + Linux |
| `lazygit/` | lazygit config + Catppuccin themes | Windows + Linux |
| `claude/` | Claude Code settings, statusline, global skills | Windows + Linux |
| `windowsterminal/` | Windows Terminal settings | Windows |
| `bat/` | bat syntax highlighter config | Windows + Linux |
| `vscode/` | VSCode settings snapshot | Windows |
| `winget/` | winget bootstrap script + package list | Windows |
| `zellij/` | Zellij terminal multiplexer | Windows + Linux |
| `tmux/` | tmux config | Linux / WSL |
| `nix/` | Nix/Home Manager (legacy snapshot) | Linux |

Legacy configs (not actively maintained): `bash/`, `vim/`, `config/bspwm/`, `config/rofi/`, `config/sxhkd/`, `i3/`, `tmux/`, `mpd/`, `ncmpcpp/`, `postgres/`, `ruby/`.

## Installation

### Windows

```powershell
git clone git@github.com:jinyeow/dotfiles.git $HOME/dotfiles
cd $HOME/dotfiles
.\setup.ps1 -Module all        # install everything
.\setup.ps1 -Module git,nvim   # or pick specific modules
.\setup.ps1 -Module all -DryRun  # preview without changes
```

Available modules: `neovim`, `vim`, `powershell`, `git`, `bash`, `tig`, `tmux`, `zellij`, `yazi`, `curl`, `claude`, `codex`, `lazygit`, `windowsterminal`, `bat`, `vscode`, `winget`

### Linux / WSL

```bash
git clone git@github.com:jinyeow/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh -m all              # install everything
./setup.sh -m git,neovim       # or pick specific modules
./setup.sh -m all --dry-run    # preview without changes
```

Available modules: `neovim`, `vim`, `powershell`, `git`, `bash`, `tig`, `tmux`, `zellij`, `curl`, `claude`, `lazygit`, `windowsterminal`

## Requirements

On a fresh machine, run the winget bootstrap first to install all tools at once:

```powershell
.\winget\packages.ps1 -DryRun  # preview
.\winget\packages.ps1           # install
```

Or install individually:

| Tool | Purpose | Install |
|---|---|---|
| [delta](https://github.com/dandavison/delta) | Git pager / diff viewer | `winget install dandavison.delta` |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | `winget install junegunn.fzf` |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast grep | `winget install BurntSushi.ripgrep.GNU` |
| [bat](https://github.com/sharkdp/bat) | Syntax-highlighted cat | `winget install sharkdp.bat` |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smart `cd` | `winget install ajeetdsouza.zoxide` |
| [lazygit](https://github.com/jesseduffield/lazygit) | Terminal git UI | `winget install JesseDuffield.lazygit` |
| [tig](https://jonas.github.io/tig/) | Terminal git browser | `winget install Jonas.Tig` |
| [jujutsu (jj)](https://github.com/jj-vcs/jj) | Git-compatible VCS (prompt-integrated) | `winget install jj-vcs.jj` |
| [Neovim](https://neovim.io) 0.11+ | Editor | `winget install Neovim.Neovim` |

See each tool's `README.md` for full prerequisites and setup notes.

## Claude Code skills

Global skills live in `claude/skills/` and are junctioned into `~/.claude/skills/` by `setup.ps1 -Module claude`. They are available across all Claude Code sessions, not just this repo.

Not sure which one fits? Run `/router` — a manual index that maps these as flows and decision tables. Built-in Claude Code skills (`code-review`, `compact`, `deep-research`, `security-review`, `verify`) are provided by the harness and aren't listed here.

| Skill | Source | Purpose |
|---|---|---|
| `grill-with-docs` | mattpocock/skills | Stateful grilling against the domain model; updates `CONTEXT.md`/ADRs inline |
| `grilling` | mattpocock/skills | Stateless relentless-interview primitive to stress-test a plan |
| `prototype` | mattpocock/skills | Throwaway prototype for a state/logic question or UI exploration |
| `to-spec` | mattpocock/skills | Turn the conversation into a spec |
| `to-hld` | local | Turn the discussion into a high-level design doc — decisions + mermaid |
| `to-tickets` | mattpocock/skills | Split a plan into tracer-bullet tickets with blocking edges |
| `implement` | mattpocock/skills | Build from a spec/ticket — TDD at seams, review, commit |
| `tdd` | mattpocock/skills | Red-green-refactor TDD loop |
| `spec-review` | local | Review a diff for conformance to its originating spec/ticket |
| `setup-agent-skills` | mattpocock/skills | One-time per-repo config for the spec → tickets → wayfinding flow |
| `triage` | mattpocock/skills | State-machine triage of issues/PRs you didn't create |
| `diagnosing-bugs` | mattpocock/skills | Diagnosis loop for hard bugs and regressions |
| `wayfinder` | mattpocock/skills | Chart a huge, foggy effort as a map of investigation tickets |
| `improve-codebase-architecture` | mattpocock/skills | Find deepening opportunities; consolidate coupling |
| `codebase-design` | mattpocock/skills | Deep-module vocabulary for designing a module's shape |
| `codex-review` | local | Read-only cross-model Codex second opinion on a diff |
| `deep-review` | local | Multi-dimension cross-model review of a diff/PR → findings store |
| `fix-findings` | local | Apply deep-review findings — partitioned, one commit per fix-unit |
| `review-fix-loop` | local | Chain deep-review + fix-findings until the diff passes clean |
| `council` | local | Adversarial panel for a non-diff artifact (idea/design/plan/doc) |
| `council-{code,business,plan,doc}` | local | Thin aliases pinning `council`'s panel by artifact type |
| `prompt-draft` | local | Draft a new prompt against the 12-lever checklist |
| `prompt-lint` | local | Score, critique, and rewrite an existing prompt |
| `azure-boards-organiser` | local | Azure Boards work items — PBIs/Bugs/Tasks, sprint planning |
| `azure-devops` | MicrosoftDocs/Agent-Skills | ADO org/project management, Analytics/OData, permissions |
| `azure-pipelines` | MicrosoftDocs/Agent-Skills | YAML pipelines, service connections, Key Vault secrets, agents |
| `azure-resource-manager` | MicrosoftDocs/Agent-Skills | Bicep/ARM troubleshooting, deployment stacks, template specs |
| `bicep-tdd` | local | Offline RED→GREEN loop for authoring Azure Bicep |
| `azure-prepare` | microsoft/azure-skills | Prepare apps for Azure deployment — IaC, Dockerfiles, `azure.yaml` |
| `azure-enterprise-infra-planner` | microsoft/azure-skills | Architect enterprise infra — landing zones, hub-spoke, Bicep/Terraform |
| `azure-validate` | microsoft/azure-skills | Pre-deployment validation — Bicep/Terraform, RBAC, what-if |
| `azure-compliance` | microsoft/azure-skills | Compliance/security audits via `azqr`, Key Vault expiry checks |
| `write` | tw93/Waza | De-AI and polish English prose (drafts, READMEs, release notes) |
| `teach` | mattpocock/skills | Learn a concept over multiple sessions (stateful workspace) |
| `zoom-out` | mattpocock/skills | Step back and assess the bigger picture |
| `quick-research` | mattpocock/skills | Background-agent primary-source research → a cited Markdown file |
| `storm-research` | local | Multi-perspective, citation-verified HTML research briefing |
| `jj` | local | Jujutsu (jj) VCS workflow — Windows/pwsh-native (adapts HotThoughts/jj-skills) |
| `resolving-merge-conflicts` | mattpocock/skills | Resolve an in-progress git merge/rebase conflict |
| `git-guardrails-claude-code` | mattpocock/skills | Hook blocking dangerous git commands |
| `handoff` | local | Compact the conversation into a handoff doc for a fresh session |
| `project-brain` | local | Durable cross-repo initiative knowledge (core/STATUS/ADRs), auto-loaded by a SessionStart hook |
| `health` | tw93/Waza | Audit the agent setup — config drift, hooks, MCP, skills, memory |
| `router` | mattpocock/skills | Manual index over this roster, as flows and decision tables (from ask-matt) |
| `writing-great-skills` | mattpocock/skills | Reference for writing and editing skills well |
| `fastmail` | local | Live inbox + calendar digest |
| `linkedin-jobs` | local | Parse LinkedIn job-alert emails and InMails into cards |
| `caveman` | mattpocock/skills | ~75% token-reduction communication mode |
