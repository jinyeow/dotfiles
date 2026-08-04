#!/usr/bin/env bash
# Install dotfiles on Linux / WSL.
#
# Usage:
#   ./setup.sh -m neovim,vim
#   ./setup.sh -m all --dry-run
#
# Modules: neovim, vim, powershell, git, bash, tig, tmux, zellij, herdr, curl, claude, codex, pi, langservers, lazygit, windowsterminal, all

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES=()
DRY_RUN=0
CLEAN_BACKUPS=0
KEEP_BACKUPS=5
MAX_BACKUP_AGE_DAYS=0

# ── Arg parsing ───────────────────────────────────────────────────────────────

usage() {
    echo "Usage: $0 -m <module[,module,...]> [--dry-run] [--clean-backups [--keep-backups N] [--max-backup-age-days N]]"
    echo "  Modules: neovim, vim, powershell, git, bash, tig, tmux, zellij, herdr, curl, claude, codex, pi, langservers, lazygit, windowsterminal, all"
    echo "  --clean-backups          remove old .bak.TIMESTAMP files from previous runs"
    echo "  --keep-backups N         keep N most recent backups per file (default: 5, 0 = no limit)"
    echo "  --max-backup-age-days N  delete backups older than N days (default: 0 = disabled)"
    echo "  Example: $0 -m neovim,vim"
    echo "  Example: $0 --clean-backups --keep-backups 3"
    echo "  Example: $0 -m git --clean-backups --max-backup-age-days 30"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--module)
            [[ -n "${2:-}" ]] || { echo "Error: -m requires an argument" >&2; usage; }
            IFS=',' read -ra MODULES <<< "$2"
            shift 2
            ;;
        --dry-run) DRY_RUN=1; shift ;;
        --clean-backups) CLEAN_BACKUPS=1; shift ;;
        --keep-backups)
            [[ -n "${2:-}" ]] || { echo "Error: --keep-backups requires an argument" >&2; usage; }
            KEEP_BACKUPS="$2"; shift 2 ;;
        --max-backup-age-days)
            [[ -n "${2:-}" ]] || { echo "Error: --max-backup-age-days requires an argument" >&2; usage; }
            MAX_BACKUP_AGE_DAYS="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

[[ ${#MODULES[@]} -eq 0 && $CLEAN_BACKUPS -eq 0 ]] && usage

# Expand 'all'
for m in "${MODULES[@]}"; do
    if [[ "$m" == "all" ]]; then
        # 'herdr' MUST come after 'claude': install_herdr runs `herdr integration install claude`,
        # which writes a hook registration into ~/.claude/settings.json — a file the claude module
        # symlinks to the repo. If herdr ran first it would create a real settings.json, then the
        # claude symlink would replace it, dropping the herdr block. Running herdr last writes
        # through the established symlink so the block survives (same reasoning as setup.ps1).
        # 'langservers' has no ordering constraint here: setup.ps1 must run it after 'winget'
        # (which provides Volta), but there is no winget module on this side — Volta is installed
        # by hand, and the module warns and skips if it is absent.
        MODULES=(neovim vim powershell git bash tig tmux zellij curl claude langservers lazygit windowsterminal pi herdr)
        break
    fi
done

# ── Output helpers ────────────────────────────────────────────────────────────

info()  { echo "[INFO]  $*"; }
ok()    { echo "[OK]    $*"; }
warn()  { echo "[WARN]  $*"; }
fail()  { echo "[ERROR] $*" >&2; }

# ── Core helpers ──────────────────────────────────────────────────────────────

backup() {
    local path="$1"
    [[ -e "$path" || -L "$path" ]] || return 0
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local backup_path="${path}.bak.${ts}"
    if [[ $DRY_RUN -eq 0 ]]; then mv "$path" "$backup_path"; fi
    warn "Backed up:  $path"
    warn "        ->  $backup_path"
}

# Canonicalize a stored symlink target for comparisons. Relative targets are interpreted
# against the link parent. Failure is reported to the caller so migration code preserves
# the existing link rather than assuming it is repository-managed.
resolve_link_target() {
    local link="$1" raw
    raw="$(readlink -- "$link")" || return 1
    if [[ "$raw" != /* ]]; then raw="$(dirname -- "$link")/$raw"; fi
    realpath -m -- "$raw" 2>/dev/null
}

canonical_path() {
    realpath -m -- "$1" 2>/dev/null
}

# A per-skill link is replaceable only when its resolved target is below one of the
# repository skill roots supplied after the link path.
is_managed_skill_link() {
    local link="$1" resolved root resolved_root
    shift
    [[ -L "$link" ]] || return 1
    resolved="$(resolve_link_target "$link")" || return 1
    for root in "$@"; do
        resolved_root="$(canonical_path "$root")" || continue
        case "$resolved" in
            "$resolved_root/"*) return 0 ;;
        esac
    done
    return 1
}

# Create a symlink, backing up any existing target first.
# Skips silently if the symlink already points to the correct target.
make_symlink() {
    local target="$1"  # path in the dotfiles repo (source)
    local link="$2"    # destination on the system

    if [[ ! -e "$target" ]]; then
        fail "Source not found: $target — skipping"
        return
    fi

    # Already correct — nothing to do. Canonical comparison also handles relative links.
    local resolved_link resolved_target
    if [[ -L "$link" ]] &&
        resolved_link="$(resolve_link_target "$link")" &&
        resolved_target="$(canonical_path "$target")" &&
        [[ "$resolved_link" == "$resolved_target" ]]; then
        ok "Up to date: $link"
        return
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        info "[DRY RUN] symlink $link -> $target"
        return
    fi

    backup "$link"
    mkdir -p "$(dirname "$link")"
    ln -sf "$target" "$link"
    ok "Symlink:    $link"
    ok "         -> $target"
}

# ── Modules ───────────────────────────────────────────────────────────────────

# Config-based hooks ([hook "work-policy"] in gitconfig-work) need Git >= 2.54.
# Older git ignores the stanza SILENTLY — no error, the hook simply never runs — so
# warn at install time rather than let a policy hook quietly enforce nothing.
check_git_hook_support() {
    if ! command -v git >/dev/null 2>&1; then
        warn 'git not on PATH — cannot verify config-based hook support (needs >= 2.54).'
        return
    fi

    raw=$(git --version | sed 's/^git version //')
    major=$(echo "$raw" | cut -d. -f1)
    minor=$(echo "$raw" | cut -d. -f2)
    case "$major$minor" in
        *[!0-9]*|'')
            warn "Could not parse git version '$raw' — config-based hooks need >= 2.54."
            return
            ;;
    esac

    if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 54 ]; }; then
        warn "git $raw is older than 2.54 — the work-policy hook in gitconfig-work is IGNORED SILENTLY."
        warn '  Upgrade git, or move the check into git/templates/hooks/pre-commit to enforce it on this machine.'
    else
        ok "git $raw supports config-based hooks (>= 2.54)."
    fi
}

install_git() {
    echo ''
    info '=== Git ==='
    make_symlink "$DOTFILES/git/gitconfig"      "$HOME/.gitconfig"
    make_symlink "$DOTFILES/git/gitconfig-work" "$HOME/.gitconfig-work"
    make_symlink "$DOTFILES/git/gitignore"      "$HOME/.gitignore"
    make_symlink "$DOTFILES/git/gitignore-work" "$HOME/.gitignore-work"
    make_symlink "$DOTFILES/git/gitmessage"     "$HOME/.gitmessage"
    make_symlink "$DOTFILES/git/templates"      "$HOME/.git_templates"
    # Not under ~/.git_templates: init.templatedir copies that directory's contents
    # into every new repo's .git/, which would put work hooks inside personal repos.
    make_symlink "$DOTFILES/git/work-hooks"     "$HOME/.git_work_hooks"
    check_git_hook_support
}

install_neovim() {
    echo ''
    info '=== Neovim ==='
    local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
    make_symlink "$DOTFILES/nvim" "$xdg_config/nvim"
}

install_vim() {
    echo ''
    info '=== Vim ==='
    # vimrc lives inside vim/ so Vim finds it at ~/.vim/vimrc automatically.
    make_symlink "$DOTFILES/vim" "$HOME/.vim"
}

install_powershell() {
    echo ''
    info '=== PowerShell ==='

    if ! command -v pwsh &>/dev/null; then
        warn "pwsh not found — skipping PowerShell module."
        warn "Install PowerShell and re-run to set up the profile."
        return
    fi

    local ps_config="${XDG_CONFIG_HOME:-$HOME/.config}/powershell"
    make_symlink "$DOTFILES/powershell/Microsoft.PowerShell_profile.ps1" "$ps_config/Microsoft.PowerShell_profile.ps1"

    # Link the Profile/ subdirectory if it exists (contains Set-Prompt.ps1 etc.)
    local profile_dir="$DOTFILES/powershell/Profile"
    if [[ -d "$profile_dir" ]]; then
        make_symlink "$profile_dir" "$ps_config/Profile"
    fi
}

install_bash() {
    echo ''
    info '=== Bash ==='
    make_symlink "$DOTFILES/bash/bashrc" "$HOME/.bashrc"
    make_symlink "$DOTFILES/bash/profile" "$HOME/.profile"
    make_symlink "$DOTFILES/bash/inputrc" "$HOME/.inputrc"
    make_symlink "$DOTFILES/bash/fzf_functions.sh" "$HOME/.fzf_functions.sh"

    if [[ -f "$DOTFILES/bash/bash_aliases" ]]; then
        make_symlink "$DOTFILES/bash/bash_aliases" "$HOME/.bash_aliases"
    fi
    if [[ -f "$DOTFILES/bash/bash_profile" ]]; then
        make_symlink "$DOTFILES/bash/bash_profile" "$HOME/.bash_profile"
    fi
}

install_tig() {
    echo ''
    info '=== Tig ==='
    make_symlink "$DOTFILES/tig/tigrc"     "$HOME/.tigrc"
    make_symlink "$DOTFILES/tig/tigrc.vim" "$HOME/.tigrc.vim"
}

install_tmux() {
    echo ''
    info '=== Tmux ==='
    make_symlink "$DOTFILES/tmux/tmux.conf" "$HOME/.tmux.conf"
}

install_zellij() {
    echo ''
    info '=== Zellij ==='
    local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
    # Symlink the whole directory so themes/ and layouts/ are included automatically.
    make_symlink "$DOTFILES/zellij" "$xdg_config/zellij"
}

install_herdr() {
    echo ''
    info '=== Herdr ==='
    local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
    # Link only config.toml, not the directory: herdr keeps its runtime state
    # (session.json, herdr.sock, *.log) in the same dir and that must stay untracked.
    make_symlink "$DOTFILES/herdr/config.toml" "$xdg_config/herdr/config.toml"

    # Wire herdr's agent-state hooks into installed AI agents so herdr can track each pane's
    # live agent session. `herdr integration install <agent>` is idempotent and writes files
    # herdr manages itself, so nothing is vendored — setup regenerates it per machine. Only
    # agents on PATH are wired. Unlike Windows, pi's integration is supported here.
    if command -v herdr >/dev/null 2>&1; then
        for agent in claude codex pi; do
            command -v "$agent" >/dev/null 2>&1 || continue
            if [[ $DRY_RUN -eq 1 ]]; then
                info "[DRY RUN] herdr integration install $agent"
            elif herdr integration install "$agent" >/dev/null 2>&1; then
                ok "Integration: $agent wired to herdr"
            else
                warn "herdr integration install $agent failed"
            fi
        done
    else
        warn 'herdr not found on PATH. Install from https://herdr.dev'
    fi
}

install_curl() {
    echo ''
    info '=== Curl ==='
    make_symlink "$DOTFILES/curl/curlrc" "$HOME/.curlrc"
}

install_langservers() {
    echo ''
    info '=== Language servers (JSON / YAML / Azure Pipelines) ==='

    # Neovim enables jsonls, yamlls and azure_pipelines_ls unconditionally (nvim/lua/config/lsp.lua),
    # so without these binaries every JSON/YAML buffer prints a spawn failure. Each package is paired
    # with the binary nvim-lspconfig's cmd actually spawns — vscode-langservers-extracted is a bundle
    # whose JSON server is the only one wired up here. Installed through Volta rather than
    # `npm install -g`: under Volta a bare global npm install does not produce working shims.
    # Verified on Windows — all three shim cleanly and Neovim attaches each server.
    # One "<package>:<binary>" entry each, not two index-coupled arrays: under `set -u` a pair
    # left half-added would abort the whole run mid-way (silently skipping every module after
    # this one) instead of failing on the one package.
    local servers=(
        vscode-langservers-extracted:vscode-json-language-server
        yaml-language-server:yaml-language-server
        azure-pipelines-language-server:azure-pipelines-language-server
    )

    # The dry run reports which packages this module owns, not which the machine happens to have,
    # so it stays deterministic — hence it precedes the volta and per-package presence checks.
    if [[ $DRY_RUN -eq 1 ]]; then
        for server in "${servers[@]}"; do
            info "[DRY RUN] would run: volta install ${server%%:*}"
        done
        return 0
    fi

    # Warn and skip, never fail: one missing toolchain must not abort an otherwise good -m all.
    if ! command -v volta >/dev/null 2>&1; then
        warn 'volta not found — install Volta (https://volta.sh), then re-run this module.'
        return 0
    fi

    local server package binary status
    for server in "${servers[@]}"; do
        package="${server%%:*}"
        binary="${server#*:}"
        if command -v "$binary" >/dev/null 2>&1; then
            ok "Language server: $binary (already installed)"
            continue
        fi
        # `|| status=$?` keeps `set -e` from aborting the whole run on one bad package, and
        # captures the exit code so a partial failure is reported rather than swallowed.
        status=0
        volta install "$package" || status=$?
        if [[ $status -eq 0 ]]; then
            ok "Language server: installed $package"
        else
            fail "volta install $package failed (exit $status)."
        fi
    done
}

install_lazygit() {
    echo ''
    info '=== Lazygit ==='
    local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
    # Symlink base config only; theme switching requires OS detection not available in bash.
    # On Windows the PowerShell profile sets LG_CONFIG_FILE with the appropriate theme.
    make_symlink "$DOTFILES/lazygit/config.yml" "$xdg_config/lazygit/config.yml"
}

install_pi() {
    echo ''
    info '=== Pi ==='
    if command -v pi >/dev/null 2>&1; then
        ok 'pi is already installed.'
    elif [[ $DRY_RUN -eq 1 ]]; then
        info '[DRY RUN] would install Pi via npm (@mariozechner/pi-coding-agent)'
    elif ! command -v npm >/dev/null 2>&1; then
        fail 'npm not found — Pi setup stopped before changing Pi configuration.'
        return
    elif ! npm install --global '@mariozechner/pi-coding-agent' || ! command -v pi >/dev/null 2>&1; then
        fail 'Pi installation failed — no Pi configuration or resources were changed.'
        return
    else
        ok 'Pi installed.'
    fi

    local pi_dir="$HOME/.pi/agent"
    # Install packages before projecting tracked configuration/resources. If a pinned package
    # fails, the return below leaves the existing Pi configuration and resources untouched.
    while IFS= read -r package; do
        if [[ $DRY_RUN -eq 1 ]]; then
            info "[DRY RUN] pi install $package"
        elif ! pi install "$package"; then
            fail "Pi package install failed for $package — repository resources were not projected."
            return
        fi
    done < <(grep -o '"npm:[^"]*"' "$DOTFILES/pi/settings.json" | tr -d '"')
    # Validate or migrate skills before projecting any tracked Pi configuration/resources.
    # Shared and Pi-native skills coexist as child links; Pi-native names win collisions.
    local skills_dst="$pi_dir/skills"
    local old_skills_target="$DOTFILES/pi/skills"
    if [[ -L "$skills_dst" ]]; then
        local resolved_skills resolved_old_skills
        resolved_skills="$(resolve_link_target "$skills_dst")" || resolved_skills=''
        resolved_old_skills="$(canonical_path "$old_skills_target")" || resolved_old_skills=''
        if [[ -n "$resolved_skills" && -n "$resolved_old_skills" && "$resolved_skills" == "$resolved_old_skills" ]]; then
            if [[ $DRY_RUN -eq 1 ]]; then
                info "[DRY RUN] remove managed Pi skills link: $skills_dst"
            else
                rm "$skills_dst"
                warn "Removed managed Pi skills link: $skills_dst"
            fi
        else
            fail "Pi skills link is unmanaged; preserving it: $skills_dst"
            return
        fi
    elif [[ -e "$skills_dst" && ! -d "$skills_dst" ]]; then
        fail "Pi skills destination is unmanaged and is not a directory: $skills_dst"
        return
    fi
    if [[ $DRY_RUN -eq 0 ]]; then mkdir -p "$skills_dst"; fi

    make_symlink "$DOTFILES/pi/settings.json" "$pi_dir/settings.json"
    for resource in extensions prompts themes; do
        make_symlink "$DOTFILES/pi/$resource" "$pi_dir/$resource"
    done

    local skill_dir name link
    declare -A native_names=()
    while IFS= read -r -d '' skill_dir; do
        native_names["$(basename "$skill_dir")"]=1
    done < <(find "$old_skills_target" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    while IFS= read -r -d '' skill_dir; do
        name="$(basename "$skill_dir")"
        [[ -n "${native_names[$name]:-}" ]] && continue
        link="$skills_dst/$name"
        if [[ -e "$link" && ! -L "$link" ]]; then
            warn "Preserved unmanaged Pi skill: $link"
            continue
        elif [[ -L "$link" ]]; then
            local resolved_existing shared_root old_root
            resolved_existing="$(resolve_link_target "$link")" || resolved_existing=''
            shared_root="$(canonical_path "$DOTFILES/ai-agents/shared/skills")" || shared_root=''
            old_root="$(canonical_path "$old_skills_target")" || old_root=''
            if [[ -z "$resolved_existing" || -z "$shared_root" || -z "$old_root" ]]; then
                warn "Preserved unmanaged Pi skill link: $link"
                continue
            fi
            case "$resolved_existing" in
                "$shared_root/"*|"$old_root/"*) ;;
                *) warn "Preserved unmanaged Pi skill link: $link"; continue ;;
            esac
        fi
        make_symlink "$skill_dir" "$link"
    done < <(find "$DOTFILES/ai-agents/shared/skills" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    while IFS= read -r -d '' skill_dir; do
        name="$(basename "$skill_dir")"
        link="$skills_dst/$name"
        if [[ -e "$link" && ! -L "$link" ]]; then
            warn "Preserved unmanaged Pi skill: $link"
            continue
        elif [[ -L "$link" ]]; then
            local resolved_existing shared_root old_root
            resolved_existing="$(resolve_link_target "$link")" || resolved_existing=''
            shared_root="$(canonical_path "$DOTFILES/ai-agents/shared/skills")" || shared_root=''
            old_root="$(canonical_path "$old_skills_target")" || old_root=''
            if [[ -z "$resolved_existing" || -z "$shared_root" || -z "$old_root" ]]; then
                warn "Preserved unmanaged Pi skill link: $link"
                continue
            fi
            case "$resolved_existing" in
                "$shared_root/"*|"$old_root/"*) ;;
                *) warn "Preserved unmanaged Pi skill link: $link"; continue ;;
            esac
        fi
        make_symlink "$skill_dir" "$link"
    done < <(find "$old_skills_target" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
}

install_claude() {
    echo ''
    info '=== Claude Code ==='
    make_symlink "$DOTFILES/claude/settings.json"          "$HOME/.claude/settings.json"
    make_symlink "$DOTFILES/claude/CLAUDE.md"              "$HOME/.claude/CLAUDE.md"
    # Shared conventions — CLAUDE.md imports this via `@AGENTS.md` (resolves to ~/.claude/AGENTS.md).
    make_symlink "$DOTFILES/claude/AGENTS.md"              "$HOME/.claude/AGENTS.md"
    make_symlink "$DOTFILES/claude/statusline-command.sh"  "$HOME/.claude/statusline-command.sh"
    # PreToolUse hook wired in settings.json; blocks commits carrying the AI session-URL trailer.
    make_symlink "$DOTFILES/claude/no-claude-session-trailer.sh" "$HOME/.claude/no-claude-session-trailer.sh"
    # pwsh-native hooks wired in settings.json: PreToolUse guardrails (destructive git, PowerShell
    # mis-sent to the Bash tool) and a PostToolUse PSScriptAnalyzer lint-on-edit pass. Need pwsh on
    # PATH to run; the lint hook also needs the PSScriptAnalyzer module (it self-skips if absent).
    make_symlink "$DOTFILES/claude/block-destructive-vcs.ps1" "$HOME/.claude/block-destructive-vcs.ps1"
    make_symlink "$DOTFILES/claude/block-pwsh-in-bash.ps1" "$HOME/.claude/block-pwsh-in-bash.ps1"
    make_symlink "$DOTFILES/claude/lint-powershell.ps1" "$HOME/.claude/lint-powershell.ps1"
    # PreToolUse ask-to-confirm on edits to legacy/do-not-touch dotfiles; PostToolUse hardcoded-secret warn.
    make_symlink "$DOTFILES/claude/warn-legacy-files.ps1" "$HOME/.claude/warn-legacy-files.ps1"
    make_symlink "$DOTFILES/claude/warn-hardcoded-secrets.ps1" "$HOME/.claude/warn-hardcoded-secrets.ps1"
    # UserPromptSubmit advisory + PreToolUse ask on reasoning-extraction phrasing (Fable fallback risk).
    make_symlink "$DOTFILES/claude/warn-reasoning-extraction.ps1" "$HOME/.claude/warn-reasoning-extraction.ps1"
    # SessionStart hook: inject a pending .claude/handoff.md (from the handoff skill) into a fresh session.
    make_symlink "$DOTFILES/claude/inject-handoff.ps1" "$HOME/.claude/inject-handoff.ps1"

    # Skills — project shared and Claude-specific resources into ~/.claude/skills/.
    local skills_dst="$HOME/.claude/skills"
    local name link old_target
    for name in council council-code council-business council-plan council-doc; do
        link="$skills_dst/$name"
        old_target="$DOTFILES/ai-agents/claude/skills/$name"
        local resolved_link resolved_old_target
        resolved_link="$(resolve_link_target "$link")" || resolved_link=''
        resolved_old_target="$(canonical_path "$old_target")" || resolved_old_target=''
        if [[ -L "$link" && -n "$resolved_link" && -n "$resolved_old_target" && "$resolved_link" == "$resolved_old_target" ]]; then
            if [[ $DRY_RUN -eq 1 ]]; then
                info "[DRY RUN] remove moved Claude council link: $link"
            else
                rm "$link"
                warn "Removed moved Claude council link: $link"
            fi
        fi
    done
    local skills_sources=("$DOTFILES/ai-agents/shared/skills" "$DOTFILES/ai-agents/claude/skills")
    # Released installers projected skills from the former top-level claude/skills source;
    # links into it are repository-managed legacy entries — replaced below when the skill
    # still exists, removed when it left the projection. Foreign links stay preserved.
    local legacy_skills_source="$DOTFILES/claude/skills"
    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$skills_dst"
    fi
    local skill_dirs=()
    for skills_src in "${skills_sources[@]}"; do
        while IFS= read -r -d '' d; do
            skill_dirs+=("$d")
        done < <(find "$skills_src" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    done
    local legacy_root entry entry_name resolved_entry skill_dir
    legacy_root="$(canonical_path "$legacy_skills_source")" || legacy_root=''
    if [[ -n "$legacy_root" && -d "$skills_dst" ]]; then
        declare -A desired_names=()
        for skill_dir in "${skill_dirs[@]}"; do
            desired_names["$(basename "$skill_dir")"]=1
        done
        while IFS= read -r -d '' entry; do
            entry_name="$(basename "$entry")"
            [[ -n "${desired_names[$entry_name]:-}" ]] && continue
            resolved_entry="$(resolve_link_target "$entry")" || continue
            case "$resolved_entry" in
                "$legacy_root/"*)
                    if [[ $DRY_RUN -eq 1 ]]; then
                        info "[DRY RUN] remove obsolete Claude skill link: $entry"
                    else
                        rm "$entry"
                        warn "Removed obsolete Claude skill link: $entry"
                    fi
                    ;;
            esac
        done < <(find "$skills_dst" -mindepth 1 -maxdepth 1 -type l -print0 2>/dev/null)
    fi
    if [ "${#skill_dirs[@]}" -gt 0 ]; then
        for skill_dir in "${skill_dirs[@]}"; do
            link="$skills_dst/$(basename "$skill_dir")"
            if [[ -e "$link" && ! -L "$link" ]]; then
                warn "Preserved unmanaged Claude skill: $link"
                continue
            elif [[ -L "$link" ]] && ! is_managed_skill_link "$link" "${skills_sources[@]}" "$legacy_skills_source"; then
                warn "Preserved unmanaged Claude skill link: $link"
                continue
            fi
            make_symlink "$skill_dir" "$link"
        done
    else
        info 'No skills to install (shared/ and claude/ skill sources are empty).'
    fi

    # Agents — symlink the whole dir into ~/.claude/agents/ (Linux equivalent of the Windows
    # dir-junction; unlike skills, which link per-subdir). Agent definitions are flat .md files
    # in one dir nothing else writes to, so a whole-dir link preserves the no-drift philosophy
    # and lets agents created via /agents land in the repo. Bodies can't @import AGENTS.md.
    if [ -d "$DOTFILES/ai-agents/shared/agents" ]; then
        make_symlink "$DOTFILES/ai-agents/shared/agents" "$HOME/.claude/agents"
    else
        info 'No agents to install (ai-agents/shared/agents/ is missing).'
    fi
}

clean_backups() {
    echo ''
    info '=== Cleaning backups ==='

    if [[ $KEEP_BACKUPS -eq 0 && $MAX_BACKUP_AGE_DAYS -eq 0 ]]; then
        warn '--keep-backups 0 and --max-backup-age-days 0 — nothing to prune.'
        return
    fi

    local xdg="${XDG_CONFIG_HOME:-$HOME/.config}"
    local search_dirs=(
        "$HOME"
        "$xdg/powershell"
        "$xdg/nvim"
        "$xdg/zellij"
        "$xdg/lazygit"
        "$HOME/.claude"
    )

    # Collect all backup files grouped by original path (stem).
    # Keys are stems; values are newline-separated lists of matching backup paths.
    declare -A stem_files

    for dir in "${search_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' f; do
            local stem="${f%.bak.[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9]}"
            stem_files[$stem]+="$f"$'\n'
        done < <(find "$dir" -maxdepth 1 \( -type f -o -type l \) \
            -name "*.bak.[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9]" \
            -print0 2>/dev/null)
    done

    if [[ ${#stem_files[@]} -eq 0 ]]; then
        info 'No backup files found.'
        return
    fi

    local cutoff_epoch=0
    if [[ $MAX_BACKUP_AGE_DAYS -gt 0 ]]; then
        cutoff_epoch=$(date -d "$MAX_BACKUP_AGE_DAYS days ago" +%s 2>/dev/null || echo 0)
    fi

    local removed=0

    for stem in "${!stem_files[@]}"; do
        mapfile -t sorted < <(printf '%s' "${stem_files[$stem]}" | sort -r)

        local i=0
        for f in "${sorted[@]}"; do
            [[ -z "$f" ]] && continue

            local remove_by_count=0 remove_by_age=0

            if [[ $KEEP_BACKUPS -gt 0 && $i -ge $KEEP_BACKUPS ]]; then
                remove_by_count=1
            fi

            if [[ $cutoff_epoch -gt 0 ]]; then
                local ts="${f##*.bak.}"
                local file_epoch
                file_epoch=$(date -d "${ts:0:8} ${ts:9:2}:${ts:11:2}:${ts:13:2}" +%s 2>/dev/null || echo 0)
                if [[ $file_epoch -gt 0 && $file_epoch -lt $cutoff_epoch ]]; then
                    remove_by_age=1
                fi
            fi

            if [[ $remove_by_count -eq 1 || $remove_by_age -eq 1 ]]; then
                local reason
                reason=$([ $remove_by_age -eq 1 ] && echo 'age' || echo 'count')
                if [[ $DRY_RUN -eq 0 ]]; then
                    rm -f "$f"
                    ok "Removed ($reason): $f"
                else
                    info "[DRY RUN] would remove ($reason): $f"
                fi
                removed=$((removed + 1))
            fi

            i=$((i + 1))
        done
    done

    if [[ $removed -eq 0 ]]; then
        info 'Nothing to prune.'
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

[[ $DRY_RUN -eq 1 ]] && warn 'DRY RUN — no changes will be made.'

for module in "${MODULES[@]}"; do
    case "$module" in
        neovim)     install_neovim     ;;
        vim)        install_vim        ;;
        powershell) install_powershell ;;
        git)        install_git        ;;
        bash)       install_bash       ;;
        tig)        install_tig        ;;
        tmux)       install_tmux       ;;
        zellij)     install_zellij     ;;
        herdr)      install_herdr      ;;
        curl)       install_curl       ;;
        claude)     install_claude     ;;
        pi)         install_pi         ;;
        langservers) install_langservers ;;
        lazygit)         install_lazygit    ;;
        windowsterminal) warn 'Windows Terminal is Windows-only — skipping.' ;;
        *)               warn "Unknown module '$module' — skipping." ;;
    esac
done

[[ $CLEAN_BACKUPS -eq 1 ]] && clean_backups

echo ''
ok 'Done.'
