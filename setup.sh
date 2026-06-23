#!/usr/bin/env bash
# Install dotfiles on Linux / WSL.
#
# Usage:
#   ./setup.sh -m neovim,vim
#   ./setup.sh -m all --dry-run
#
# Modules: neovim, vim, powershell, git, bash, tig, tmux, zellij, curl, claude, all

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
    echo "  Modules: neovim, vim, powershell, git, bash, tig, tmux, zellij, curl, claude, all"
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
        MODULES=(neovim vim powershell git bash tig tmux zellij curl claude lazygit windowsterminal)
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

# Create a symlink, backing up any existing target first.
# Skips silently if the symlink already points to the correct target.
make_symlink() {
    local target="$1"  # path in the dotfiles repo (source)
    local link="$2"    # destination on the system

    if [[ ! -e "$target" ]]; then
        fail "Source not found: $target — skipping"
        return
    fi

    # Already correct — nothing to do
    if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
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

install_git() {
    echo ''
    info '=== Git ==='
    make_symlink "$DOTFILES/git/gitconfig"      "$HOME/.gitconfig"
    make_symlink "$DOTFILES/git/gitconfig-work" "$HOME/.gitconfig-work"
    make_symlink "$DOTFILES/git/gitignore"      "$HOME/.gitignore"
    make_symlink "$DOTFILES/git/gitignore-work" "$HOME/.gitignore-work"
    make_symlink "$DOTFILES/git/gitmessage"     "$HOME/.gitmessage"
    make_symlink "$DOTFILES/git/templates"      "$HOME/.git_templates"
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

install_curl() {
    echo ''
    info '=== Curl ==='
    make_symlink "$DOTFILES/curl/curlrc" "$HOME/.curlrc"
}

install_lazygit() {
    echo ''
    info '=== Lazygit ==='
    local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
    # Symlink base config only; theme switching requires OS detection not available in bash.
    # On Windows the PowerShell profile sets LG_CONFIG_FILE with the appropriate theme.
    make_symlink "$DOTFILES/lazygit/config.yml" "$xdg_config/lazygit/config.yml"
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

    # Skills — symlink each subdirectory into ~/.claude/skills/
    local skills_src="$DOTFILES/claude/skills"
    local skills_dst="$HOME/.claude/skills"
    mkdir -p "$skills_dst"
    local skill_dirs=()
    while IFS= read -r -d '' d; do
        skill_dirs+=("$d")
    done < <(find "$skills_src" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    if [ "${#skill_dirs[@]}" -gt 0 ]; then
        for skill_dir in "${skill_dirs[@]}"; do
            make_symlink "$skill_dir" "$skills_dst/$(basename "$skill_dir")"
        done
    else
        info 'No skills to install (claude/skills/ is empty).'
    fi

    # Agents — symlink the whole dir into ~/.claude/agents/ (Linux equivalent of the Windows
    # dir-junction; unlike skills, which link per-subdir). Agent definitions are flat .md files
    # in one dir nothing else writes to, so a whole-dir link preserves the no-drift philosophy
    # and lets agents created via /agents land in the repo. Bodies can't @import AGENTS.md.
    if [ -d "$DOTFILES/claude/agents" ]; then
        make_symlink "$DOTFILES/claude/agents" "$HOME/.claude/agents"
    else
        info 'No agents to install (claude/agents/ is missing).'
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
        done < <(find "$dir" -maxdepth 1 \( -f -o -L \) \
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
        curl)       install_curl       ;;
        claude)     install_claude     ;;
        lazygit)         install_lazygit    ;;
        windowsterminal) warn 'Windows Terminal is Windows-only — skipping.' ;;
        *)               warn "Unknown module '$module' — skipping." ;;
    esac
done

[[ $CLEAN_BACKUPS -eq 1 ]] && clean_backups

echo ''
ok 'Done.'
