#!/usr/bin/env bash
# Install dotfiles on Linux / WSL.
#
# Usage:
#   ./setup.sh -m neovim,vim
#   ./setup.sh -m all --dry-run
#
# Modules: neovim, vim, powershell, git, bash, tig, tmux, curl, claude, all

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES=()
DRY_RUN=0

# ── Arg parsing ───────────────────────────────────────────────────────────────

usage() {
    echo "Usage: $0 -m <module[,module,...]> [--dry-run]"
    echo "  Modules: neovim, vim, powershell, git, bash, tig, tmux, curl, claude, all"
    echo "  Example: $0 -m neovim,vim"
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
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

[[ ${#MODULES[@]} -eq 0 ]] && usage

# Expand 'all'
for m in "${MODULES[@]}"; do
    if [[ "$m" == "all" ]]; then
        MODULES=(neovim vim powershell git bash tig tmux curl claude)
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

install_curl() {
    echo ''
    info '=== Curl ==='
    make_symlink "$DOTFILES/curl/curlrc" "$HOME/.curlrc"
}

install_claude() {
    echo ''
    info '=== Claude Code ==='
    make_symlink "$DOTFILES/claude/settings.json"          "$HOME/.claude/settings.json"
    make_symlink "$DOTFILES/claude/statusline-command.sh"  "$HOME/.claude/statusline-command.sh"
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
        curl)       install_curl       ;;
        claude)     install_claude     ;;
        *)          warn "Unknown module '$module' — skipping." ;;
    esac
done

echo ''
ok 'Done.'
