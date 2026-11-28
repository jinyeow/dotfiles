# dotfiles

Personal dotfiles for Windows (primary) and Linux/WSL.

Mirrored on Codeberg at <https://codeberg.org/jinyeow/dotfiles>. GitHub is the primary repository; open issues and pull requests there.

## Structure

| Directory | Tool | Platform |
|---|---|---|
| `powershell/` | PowerShell 7 profile + prompt | Windows |
| `nvim/` | Neovim (Lua, 0.12+) | Windows + Linux |
| `git/` | Git config, hooks, ignore | Windows + Linux |
| `vim/` | Vim config (Linux fallback) | Linux |
| `bash/` | Bash config + fzf helpers | Linux / WSL |
| `tig/` | Tig terminal git browser | Windows + Linux |
| `fzf/` | fzf default options + catppuccin theme | Windows + Linux |
| `curl/` | Global curl defaults | Windows + Linux |
| `ripgrep/` | ripgrep config | Windows + Linux |
| `lazygit/` | lazygit config + Catppuccin themes | Windows + Linux |
| `claude/` | Claude Code settings, statusline, hooks, agents, global skills | Windows + Linux |
| `windowsterminal/` | Windows Terminal settings | Windows |
| `bat/` | bat syntax highlighter config | Windows + Linux |
| `vscode/` | VSCode settings snapshot | Windows |
| `winget/` | winget bootstrap script + package list | Windows |
| `zellij/` | Zellij terminal multiplexer | Windows + Linux |
| `psmux/` | psmux config (native-Windows tmux clone, daily-driver multiplexer) | Windows |
| `yazi/` | Yazi terminal file manager config | Windows |
| `codex/` | Codex CLI config (read-only second-opinion reviewer) | Windows + Linux |
| `eza/` | eza (`ls` replacement) Catppuccin theme | Windows |
| `pi/` | Pi coding agent settings, extensions, and skills | Windows + Linux |
| `herdr/` | Herdr terminal workspace manager for AI coding agents | Windows + Linux |
| `ai-agents/` | Portable agent conventions, skills, and agent definitions | Windows + Linux |
| `tmux/` | tmux config | Linux / WSL |
| `nix/` | Nix/Home Manager (legacy snapshot) | Linux |

Legacy configs (not actively maintained): `vim/`, `config/bspwm/`, `config/rofi/`, `config/sxhkd/`, `config/direnv/`, `config/ranger/`, `i3/`, `mpd/`, `ncmpcpp/`, `postgres/`, `ruby/`, `ctags`, `wgetrc`, `Xresources.d/`, `urxvt/`, `etc/`, `scripts/`.

## Installation

### Windows

```powershell
git clone git@github.com:jinyeow/dotfiles.git $HOME/dotfiles
cd $HOME/dotfiles
.\setup.ps1 -Module all        # install everything
.\setup.ps1 -Module git,nvim   # or pick specific modules
.\setup.ps1 -Module all -DryRun  # preview without changes
```

Available modules: `neovim`, `vim`, `powershell`, `git`, `bash`, `tig`, `tmux`, `zellij`, `psmux`, `yazi`, `curl`, `claude`, `codex`, `pi`, `ai-agents`, `serena`, `context7`, `fastmail`, `langservers`, `biceptools`, `herdr`, `lazygit`, `windowsterminal`, `bat`, `vscode`, `winget`

`ai-agents` is a composite that runs `claude`, `codex`, and `pi` in sequence (used by `all` instead of listing the three individually); each remains independently invocable on its own.

`biceptools` installs the Bicep language server (`dotnet tool install --global
Azure.Bicep.LangServer`) so `bicep-ls` is on PATH. Like `langservers`, it depends on a toolchain
from the curated winget set (here, the .NET SDK) that the `winget` module only prints the
bootstrap command for — on a bare machine it warns and skips until `winget/packages.ps1` has
actually been run, then a re-run of `setup.ps1` picks it up.

### Linux / WSL

```bash
git clone git@github.com:jinyeow/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh -m all              # install everything
./setup.sh -m git,neovim       # or pick specific modules
./setup.sh -m all --dry-run    # preview without changes
```

Available modules: `neovim`, `vim`, `powershell`, `git`, `bash`, `tig`, `tmux`, `zellij`, `curl`, `claude`, `codex`, `pi`, `ai-agents`, `langservers`, `herdr`, `lazygit`, `windowsterminal`

`ai-agents` is a composite that runs `claude`, `codex`, and `pi` in sequence (used by `all` instead of listing the three individually); each remains independently invocable on its own.

## Requirements

On Windows, enable Developer Mode (Settings > For developers) before running `setup.ps1` —
symlink creation fails without it (junctions do not require it). The `pi` module additionally
requires Node.js/npm on PATH if Pi is not already installed.

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
| [Neovim](https://neovim.io) 0.12+ | Editor | `winget install Neovim.Neovim` |

See `fzf/`, `ripgrep/`, `lazygit/`, `tig/`, and `nvim/` for tool-specific `README.md` prerequisites and setup notes; delta, bat, zoxide, and jj have no dedicated config directory in this repo.

## Claude Code skills

Portable skills live in `ai-agents/skills/`; Claude-native skills live in `claude/skills/`, Codex-native variants in `codex/skills/`, and Pi-native variants in `pi/skills/`. Claude projects portable plus Claude-native skills, Codex (Windows and Linux) projects portable plus Codex-native skills, and Pi projects portable plus Pi-native skills. The portable review-support contract at `ai-agents/skills/_shared/` (`code-review`, `refine-until-ready`, `fix-findings`, `pr-review`) is projected with every runtime; `ai-agents/_shared/` holds only the hooks' `banned-ai-terms.txt` wordlist. User-scope agent definitions live under `ai-agents/agents/` and are projected to Claude Code. Installers safely migrate existing whole-directory links from the historical `ai-agents/shared/agents/` path without replacing user-owned entries.

Not sure which one fits? Run `/router` — a manual index that maps these as flows and decision tables. Built-in Claude Code skills (`compact`, `deep-research`, `security-review`, `verify`) are provided by the harness and aren't listed here. The `code-review` skill below replaces the built-in `/code-review`; the built-in's `/review` alias still runs Claude Code's own review. The `mattpocock/skills` rows are unedited copies of upstream at commit `6f7f783` (2026-11-25), including each skill's `agents/openai.yaml` Codex metadata; re-sync by copying the folders again. `code-review` is a local skill adapted from upstream's `code-review` at that commit, so a re-sync skips it. The customized versions they replaced are at commit `c7a774c`.

| Skill | Source | Purpose |
|---|---|---|
| `grill-with-docs` | mattpocock/skills | Grill a plan against the domain model, updating `GLOSSARY.md` and ADRs as decisions land |
| `grilling` | mattpocock/skills | Relentless-interview primitive to stress-test a plan, in batched frontier rounds |
| `domain-modeling` | mattpocock/skills | Challenge terminology against `GLOSSARY.md`, sharpen fuzzy language, record ADRs |
| `prototype` | mattpocock/skills | Throwaway prototype for a state/logic question or UI exploration |
| `to-spec` | mattpocock/skills | Turn the conversation into a spec |
| `to-hld` | local | Turn the discussion into a high-level design doc — decisions + mermaid |
| `to-tickets` | mattpocock/skills | Split a plan into tracer-bullet tickets with blocking edges |
| `critique-plan` | ayoubben18/ab-method | Check the spec and tickets against the domain model before implementing (trial) |
| `implement` | mattpocock/skills | Build from a spec/ticket — TDD at seams, review, commit |
| `implement-spec` | mattpocock/skills | Implement a whole spec with implementer subagents on one integration branch |
| `redraft` | local | Scrap a hacky fix and redo it properly with what the first attempt taught |
| `tdd` | mattpocock/skills | Red-green-refactor TDD loop |
| `code-review` | local (adapted from mattpocock/skills) | Review a diff on Standards, Spec and Bugs plus lenses picked by what it touches; validates findings, rates likelihood × impact, gives a merge verdict; replaces the built-in `/code-review` |
| `review` | local | Route a review: code to `code-review`, someone else's PR to `pr-review`, documents and plans to `council`, spec-and-tickets fit to `critique-plan` |
| `walk-me-through-it` | local | Walk me through a diff like a senior mentoring a junior — pair-programming style, chunk by chunk, concise, open to questions |
| `cross-examine` | local | Explain each piece of a diff to a junior and defend it to its reviewer before the PR |
| `to-pullrequest` | local | Open a GitHub or Azure DevOps PR with a body run through `write` |
| `wrapup` | local | Two-question self-review before clearing or ending a session |
| `retro` | mattpocock/skills | Session retrospective aimed at the agent's environment, not the code |
| `setup-matt-pocock-skills` | mattpocock/skills | Write `docs/agents/` (issue tracker, triage labels, domain docs) for the engineering skills |
| `triage` | mattpocock/skills | State-machine triage of issues/PRs you didn't create |
| `diagnosing-bugs` | mattpocock/skills | Diagnosis loop for hard bugs and regressions |
| `wayfinder` | mattpocock/skills | Chart a huge, foggy effort as a map of investigation tickets |
| `improve-codebase-architecture` | mattpocock/skills | Find deepening opportunities; consolidate coupling |
| `techdebt` | local | Inventory non-architectural tech debt from existing tool output; hand off to `to-tickets` |
| `worktree-janitor` | local | Post-merge worktree cleanup — merge/completion or STATUS.md signal, then remove + branch delete |
| `codebase-design` | mattpocock/skills | Deep-module vocabulary for designing a module's shape |
| `prove-it` | local | Diff observed behaviour between the base branch and the current branch |
| `pr-review` | local | Review someone else's GitHub or Azure DevOps PR with `code-review` in others' PR mode; posts back only on your go-ahead |
| `fix-findings` | local | Apply blocking review findings as minimal fixes, one commit per fix-unit |
| `refine-until-ready` | local | Loop code-review and fix-findings until nothing blocking is left, within rails |
| `council` | local | Adversarial panel for a non-diff artifact (idea/design/plan/doc) |
| `prompt-draft` | local | Draft a new prompt against the 12-lever checklist |
| `prompt-lint` | local | Score, critique, and rewrite an existing prompt |
| `azure-boards-organiser` | local | Azure Boards work items — PBIs/Bugs/Tasks, sprint planning |
| `rfc` | local | Draft and create an Azure DevOps Request for Change (RFC) work item |
| `azure-resource-manager` | MicrosoftDocs/Agent-Skills | Bicep/ARM troubleshooting, deployment stacks, template specs |
| `bicep-tdd` | local | Offline RED→GREEN loop for authoring Azure Bicep |
| `azure-enterprise-infra-planner` | microsoft/azure-skills | Architect enterprise infra — landing zones, hub-spoke, Bicep/Terraform |
| `azure-compliance` | microsoft/azure-skills | Compliance/security audits via `azqr`, Key Vault expiry checks |
| `write` | tw93/Waza | De-AI and polish English prose (drafts, READMEs, release notes) |
| `teach` | mattpocock/skills | Learn a concept over multiple sessions (stateful workspace) |
| `grill-me` | mattpocock/skills | Grilling without a repo, saving nothing |
| `wait-what` | mattpocock/skills | Re-pitch something that didn't land, simpler and with the missing context |
| `to-questionnaire` | mattpocock/skills | Turn a decision you can't answer into a questionnaire for someone else |
| `wizard` | mattpocock/skills | Generate a bash wizard that walks a human through steps only they can do |
| `research` | mattpocock/skills | Background-agent primary-source research → a cited Markdown file |
| `storm-research` | local | Multi-perspective, citation-verified HTML research briefing |
| `llmwiki-insights` | local | Turn an LLM-maintained wiki into prioritized findings about its subject |
| `jj` | local | Jujutsu (jj) VCS workflow — Windows/pwsh-native (adapts HotThoughts/jj-skills) |
| `handoff` | mattpocock/skills | Compact the conversation into a handoff doc in the OS temp directory |
| `project-brain` | local | Durable cross-repo initiative knowledge (core/STATUS/ADRs), auto-loaded by a SessionStart hook |
| `setup-home-repo` | local | Set up or adopt a workspace's Home Repo, with an approval gate |
| `agent-staging` | local | Per-workspace drop zone for files between you and your agents |
| `health` | tw93/Waza | Audit the agent setup — config drift, hooks, MCP, skills, memory |
| `refactor-agents-md` | local | Split an AGENTS.md into a minimal root plus linked category files |
| `i-have-adhd` | ayghri/i-have-adhd | Shape replies for a reader with ADHD until "stop adhd mode" |
| `ask-matt` | mattpocock/skills | Router over the mattpocock skills and the main flow |
| `router` | local | Index over your own skills, as flows and decision tables; defers the mattpocock flow to `ask-matt` |
| `writing-for-agents` | mattpocock/skills | Reference for writing skills, AGENTS.md and CLAUDE.md for agents |
| `fastmail` | local | Live inbox + calendar digest |
| `linkedin-jobs` | local | Parse LinkedIn job-alert emails and InMails into cards |
