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

Available modules: `git`, `neovim`, `vim`, `powershell`, `tig`, `zellij`, `curl`, `lazygit`, `windowsterminal`, `bat`, `vscode`, `winget`

### Linux / WSL

```bash
git clone git@github.com:jinyeow/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh -m all              # install everything
./setup.sh -m git,neovim       # or pick specific modules
./setup.sh -m all --dry-run    # preview without changes
```

Available modules: `git`, `neovim`, `vim`, `powershell`, `bash`, `tig`, `tmux`, `zellij`, `fzf`, `curl`, `lazygit`

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
| [Neovim](https://neovim.io) 0.11+ | Editor | `winget install Neovim.Neovim` |

See each tool's `README.md` for full prerequisites and setup notes.

## Claude Code skills

Global skills live in `claude/skills/` and are junctioned into `~/.claude/skills/` by `setup.ps1 -Module claude`. They are available across all Claude Code sessions, not just this repo.

| Skill | Source | Purpose |
|---|---|---|
| `azure-enterprise-infra-planner` | microsoft/azure-skills | Architect enterprise Azure infra — landing zones, hub-spoke, Bicep/Terraform |
| `azure-prepare` | microsoft/azure-skills | Prepare apps for Azure deployment — IaC, Dockerfiles, `azure.yaml` |
| `azure-validate` | microsoft/azure-skills | Pre-deployment validation — Bicep/Terraform, RBAC, what-if |
| `azure-compliance` | microsoft/azure-skills | Compliance/security audits via `azqr`, Key Vault expiry checks |
| `azure-devops` | MicrosoftDocs/Agent-Skills | ADO org/project management, Analytics/OData, permissions |
| `azure-pipelines` | MicrosoftDocs/Agent-Skills | YAML pipelines, service connections, Key Vault secrets, agents |
| `azure-resource-manager` | MicrosoftDocs/Agent-Skills | Bicep/ARM troubleshooting (BCP errors), deployment stacks, template specs |
| `diagnose` | mattpocock/skills | Disciplined debug loop — reproduce → minimise → hypothesise → fix |
| `tdd` | mattpocock/skills | Red-green-refactor TDD with interface-design references |
| `prototype` | mattpocock/skills | Throwaway prototype for logic questions or UI exploration |
| `improve-codebase-architecture` | mattpocock/skills | Find deepening opportunities, consolidate coupling |
| `git-guardrails-claude-code` | mattpocock/skills | Hook blocking dangerous git commands |
| `zoom-out` | mattpocock/skills | Step back and assess the bigger picture |
| `to-prd` | mattpocock/skills | Turn conversation into a PRD on the issue tracker |
| `to-issues` | mattpocock/skills | Break a plan into independently-grabbable issues |
| `triage` | mattpocock/skills | State-machine issue triage |
| `grill-me` | mattpocock/skills | Relentless interview to stress-test a plan or design |
| `grill-with-docs` | mattpocock/skills | Grilling against existing domain model and ADRs |
| `write-a-skill` | mattpocock/skills | Create new skills with proper structure |
| `handoff` | local | Compact conversation into a handoff doc for a fresh agent |
| `caveman` | mattpocock/skills | ~75% token reduction mode |
