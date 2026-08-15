#!/usr/bin/env bash
# Install dotfiles on Linux / WSL.
#
# Usage:
#   ./setup.sh -m neovim,vim
#   ./setup.sh -m all --dry-run
#
# Modules: neovim, vim, powershell, git, bash, tig, tmux, zellij, herdr, curl, claude, codex, pi, ai-agents, langservers, lazygit, windowsterminal, all
#   'ai-agents' is a composite that runs claude, codex, and pi in sequence; 'all' uses it instead
#   of listing the three individually. claude, codex, and pi remain independently invocable.

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
    echo "  Modules: neovim, vim, powershell, git, bash, tig, tmux, zellij, herdr, curl, claude, codex, pi, ai-agents, langservers, lazygit, windowsterminal, all"
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
        # 'herdr' MUST come after 'ai-agents': install_herdr runs `herdr integration install
        # claude` (and wires pi on Linux — pi has no herdr integration on Windows), which writes
        # a hook registration into ~/.claude/settings.json — a file the claude module symlinks to
        # the repo. If herdr ran first it would create a real settings.json, then the claude
        # symlink would replace it, dropping the herdr block. Running herdr last writes through
        # the established symlink so the block survives (same reasoning as setup.ps1).
        # 'langservers' has no ordering constraint here: setup.ps1 must run it after 'winget'
        # (which provides Volta), but there is no winget module on this side — Volta is installed
        # by hand, and the module warns and skips if it is absent.
        # 'ai-agents' replaces individually listing 'claude', 'codex', 'pi': it is the composite
        # module that runs all three in sequence (see install_ai_agents). Listing them here too
        # would run each runtime twice, since MODULES is not deduplicated by the runtimes a
        # composite entry fans out to.
        MODULES=(neovim vim powershell git bash tig tmux zellij curl ai-agents langservers lazygit windowsterminal herdr)
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

# Copy a file into place, backing up any existing destination first. Used where the file must
# stay a plain copy rather than a symlink so the live copy can drift and be captured explicitly
# on re-run — same choice setup.ps1 makes for this module via Copy-Dotfile.
copy_dotfile() {
    local source="$1"  # path in the dotfiles repo
    local dest="$2"    # destination on the system

    if [[ ! -e "$source" ]]; then
        fail "Source file not found: $source — skipping"
        return
    fi

    if [[ -f "$dest" ]] && cmp -s "$source" "$dest"; then
        ok "Up to date: $dest"
        return
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        info "[DRY RUN] copy $source -> $dest"
        return
    fi

    backup "$dest"
    mkdir -p "$(dirname "$dest")"
    cp "$source" "$dest"
    ok "Copied:     $dest"
    warn "(Re-run setup.sh after editing this file in the repo)"
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

# Replace only an installer-managed whole-directory link. Real directories, files, external
# links, and malformed links are preserved. Historical roots are compared lexically so dangling
# links remain safely repairable after a source move.
make_managed_directory_symlink() {
    local target="$1" link="$2" historical resolved_target resolved_link candidate
    shift 2
    [[ -d "$target" ]] || { fail "Source directory not found: $target — skipping"; return; }
    if [[ -e "$link" && ! -L "$link" ]]; then
        warn "Preserved unmanaged directory: $link"
        return
    fi
    if [[ -L "$link" ]]; then
        resolved_link="$(resolve_link_target "$link")" || resolved_link=''
        resolved_target="$(canonical_path "$target")" || resolved_target=''
        if [[ -n "$resolved_link" && -n "$resolved_target" && "$resolved_link" == "$resolved_target" ]]; then
            ok "Up to date: $link"
            return
        fi
        local managed=0
        for historical in "$@"; do
            candidate="$(canonical_path "$historical")" || candidate=''
            if [[ -n "$resolved_link" && -n "$candidate" && "$resolved_link" == "$candidate" ]]; then
                managed=1
                break
            fi
        done
        if [[ $managed -eq 0 ]]; then
            if [[ ! -e "$link" ]]; then
                warn "Preserved unmanaged directory link (target missing): $link"
            else
                warn "Preserved unmanaged directory link: $link"
            fi
            return
        fi
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        info "[DRY RUN] symlink $link -> $target"
        return
    fi
    [[ -L "$link" ]] && rm -- "$link"
    mkdir -p "$(dirname "$link")"
    ln -s -- "$target" "$link"
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

    local skill_dir name link entry entry_name
    local portable_skills_root="$DOTFILES/ai-agents/skills"
    # Scoped to roots the Pi installer itself (current or historical) has ever written into —
    # Pi never wrote into any Claude- or Codex-only historical root (see issue #71).
    local managed_skill_roots=("$portable_skills_root" "$DOTFILES/pi/skills" "$DOTFILES/ai-agents/shared/skills")
    declare -A native_names=() desired_names=()
    while IFS= read -r -d '' skill_dir; do
        native_names["$(basename "$skill_dir")"]=1
        desired_names["$(basename "$skill_dir")"]=1
    done < <(find "$old_skills_target" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    while IFS= read -r -d '' skill_dir; do
        name="$(basename "$skill_dir")"
        [[ -n "${native_names[$name]:-}" ]] && continue
        desired_names["$name"]=1
    done < <(find "$portable_skills_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    # Remove obsolete managed links before projecting. Missing historical roots are never
    # recreated; canonical_path resolves them lexically for delayed-upgrade repair.
    if [[ -d "$skills_dst" ]]; then
        while IFS= read -r -d '' entry; do
            entry_name="$(basename "$entry")"
            [[ -n "${desired_names[$entry_name]:-}" ]] && continue
            is_managed_skill_link "$entry" "${managed_skill_roots[@]}" || continue
            if [[ $DRY_RUN -eq 1 ]]; then info "[DRY RUN] remove obsolete Pi skill link: $entry"; else rm "$entry"; warn "Removed obsolete Pi skill link: $entry"; fi
        done < <(find "$skills_dst" -mindepth 1 -maxdepth 1 -type l -print0 2>/dev/null)
    fi
    project_pi_skill() {
        local source="$1" project_name project_link
        project_name="$(basename "$source")"
        project_link="$skills_dst/$project_name"
        if [[ -e "$project_link" && ! -L "$project_link" ]]; then
            warn "Preserved unmanaged Pi skill: $project_link"
            return
        fi
        if [[ -L "$project_link" ]] && ! is_managed_skill_link "$project_link" "${managed_skill_roots[@]}"; then
            if [[ ! -e "$project_link" ]]; then
                warn "Preserved unmanaged Pi skill link (target missing): $project_link"
            else
                warn "Preserved unmanaged Pi skill link: $project_link"
            fi
            return
        fi
        make_symlink "$source" "$project_link"
    }
    while IFS= read -r -d '' skill_dir; do
        [[ -n "${native_names[$(basename "$skill_dir")]:-}" ]] && continue
        project_pi_skill "$skill_dir"
    done < <(find "$portable_skills_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    while IFS= read -r -d '' skill_dir; do
        project_pi_skill "$skill_dir"
    done < <(find "$old_skills_target" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
}

find_claude_cli() {
    if command -v claude >/dev/null 2>&1; then
        return 0
    fi

    # The native installer places the executable here, but a child installer cannot update this
    # shell's PATH. Refresh it before gating configuration so a successful bootstrap is usable now.
    local native_bin="$HOME/.local/bin"
    if [[ -x "$native_bin/claude" ]]; then
        case ":${PATH}:" in
            *:"$native_bin":*) ;;
            *) PATH="$native_bin:$PATH"; export PATH ;;
        esac
        command -v claude >/dev/null 2>&1
        return
    fi
    return 1
}

ensure_claude_cli() {
    if find_claude_cli; then
        ok 'Claude Code CLI is already installed.'
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        info '[DRY RUN] would install Claude Code CLI via https://claude.ai/install.sh'
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        fail 'Claude Code CLI bootstrap requires curl — install curl, then re-run: ./setup.sh -m claude'
        return 1
    fi

    info 'Claude Code CLI not found — installing via the native installer...'
    # Supported Linux install path; deliberately do not use npm/Volta.
    if ! curl -fsSL https://claude.ai/install.sh | bash; then
        fail 'Claude Code CLI bootstrap failed.'
    fi
    if ! find_claude_cli; then
        fail 'Claude setup stopped before configuration or projection because the CLI is unavailable.'
        info 'Install it manually with: curl -fsSL https://claude.ai/install.sh | bash'
        info 'Then verify claude is on PATH and re-run: ./setup.sh -m claude'
        return 1
    fi
    ok 'Claude Code CLI installed.'
    return 0
}

install_claude() {
    echo ''
    info '=== Claude Code ==='
    if ! ensure_claude_cli; then
        return
    fi
    make_symlink "$DOTFILES/claude/settings.json"          "$HOME/.claude/settings.json"
    make_symlink "$DOTFILES/claude/CLAUDE.md"              "$HOME/.claude/CLAUDE.md"
    # Shared conventions — CLAUDE.md imports this via `@../ai-agents/AGENTS.md` (resolves to ~/.claude/AGENTS.md).
    make_symlink "$DOTFILES/ai-agents/AGENTS.md"           "$HOME/.claude/AGENTS.md"
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

    # Skills — project portable and Claude-native resources into ~/.claude/skills/.
    # Native names win collisions; ai-agents/_shared is source-only and is not enumerated.
    local skills_dst="$HOME/.claude/skills"
    local portable_skills_root="$DOTFILES/ai-agents/skills"
    local native_skills_root="$DOTFILES/claude/skills"
    local historical_shared_root="$DOTFILES/ai-agents/shared/skills"
    local historical_claude_root="$DOTFILES/ai-agents/claude/skills"
    # Scoped to roots the Claude installer itself (current or historical) has ever written into —
    # never a root only Pi's or Codex's installer wrote (see issue #71).
    local managed_skill_roots=("$portable_skills_root" "$native_skills_root" "$historical_shared_root" "$historical_claude_root")
    if [[ $DRY_RUN -eq 0 ]]; then mkdir -p "$skills_dst"; fi
    local skill_dir skill_name link entry entry_name
    declare -A native_names=() desired_names=()
    while IFS= read -r -d '' skill_dir; do
        native_names["$(basename "$skill_dir")"]=1
        desired_names["$(basename "$skill_dir")"]=1
    done < <(find "$native_skills_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    while IFS= read -r -d '' skill_dir; do
        skill_name="$(basename "$skill_dir")"
        [[ -n "${native_names[$skill_name]:-}" ]] && continue
        desired_names["$skill_name"]=1
    done < <(find "$portable_skills_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    if [[ -d "$skills_dst" ]]; then
        while IFS= read -r -d '' entry; do
            entry_name="$(basename "$entry")"
            [[ -n "${desired_names[$entry_name]:-}" ]] && continue
            is_managed_skill_link "$entry" "${managed_skill_roots[@]}" || continue
            if [[ $DRY_RUN -eq 1 ]]; then info "[DRY RUN] remove obsolete Claude skill link: $entry"; else rm "$entry"; warn "Removed obsolete Claude skill link: $entry"; fi
        done < <(find "$skills_dst" -mindepth 1 -maxdepth 1 -type l -print0 2>/dev/null)
    fi
    project_claude_skill() {
        local source="$1" project_name project_link
        project_name="$(basename "$source")"
        project_link="$skills_dst/$project_name"
        if [[ -e "$project_link" && ! -L "$project_link" ]]; then
            warn "Preserved unmanaged Claude skill: $project_link"
            return
        fi
        if [[ -L "$project_link" ]] && ! is_managed_skill_link "$project_link" "${managed_skill_roots[@]}"; then
            if [[ ! -e "$project_link" ]]; then
                warn "Preserved unmanaged Claude skill link (target missing): $project_link"
            else
                warn "Preserved unmanaged Claude skill link: $project_link"
            fi
            return
        fi
        make_symlink "$source" "$project_link"
    }
    while IFS= read -r -d '' skill_dir; do
        [[ -n "${native_names[$(basename "$skill_dir")]:-}" ]] && continue
        project_claude_skill "$skill_dir"
    done < <(find "$portable_skills_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    while IFS= read -r -d '' skill_dir; do
        project_claude_skill "$skill_dir"
    done < <(find "$native_skills_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    # Agents — symlink the whole dir into ~/.claude/agents/ (Linux equivalent of the Windows
    # dir-junction; unlike skills, which link per-subdir). Agent definitions are flat .md files
    # in one dir nothing else writes to, so a whole-dir link preserves the no-drift philosophy
    # and lets agents created via /agents land in the repo. Bodies can't @import AGENTS.md.
    local agents_src="$DOTFILES/ai-agents/agents"
    local historical_agents_src="$DOTFILES/ai-agents/shared/agents"
    # The original agents source, before the ai-agents-module migration introduced
    # ai-agents/shared/agents (later itself migrated to ai-agents/agents). Kept as a historical
    # root indefinitely so a machine whose ~/.claude/agents link predates that migration stays
    # repairable instead of being permanently misclassified as an unrecognized/dangling link.
    local original_agents_src="$DOTFILES/claude/agents"
    if [ -d "$agents_src" ]; then
        make_managed_directory_symlink "$agents_src" "$HOME/.claude/agents" "$historical_agents_src" "$original_agents_src"
    else
        info 'No agents to install (ai-agents/agents/ is missing).'
    fi
}

find_codex_cli() {
    command -v codex >/dev/null 2>&1
}

ensure_codex_cli() {
    if find_codex_cli; then
        ok 'codex is already installed.'
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        info '[DRY RUN] would install Codex CLI via https://chatgpt.com/codex/install.sh'
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        fail 'Codex CLI bootstrap requires curl — install curl, then re-run: ./setup.sh -m codex'
        return 1
    fi

    info 'Codex CLI not found — installing via the native installer...'
    if ! curl -fsSL https://chatgpt.com/codex/install.sh | bash; then
        fail 'Codex CLI install failed.'
    fi
    if ! find_codex_cli; then
        fail 'Codex setup stopped before configuration or projection because the CLI is unavailable.'
        info 'Install it manually with: curl -fsSL https://chatgpt.com/codex/install.sh | bash'
        info 'Then verify codex is on PATH and re-run: ./setup.sh -m codex'
        return 1
    fi
    ok 'Codex CLI installed.'
    return 0
}

install_codex() {
    echo ''
    info '=== Codex CLI ==='

    # 1. Install the Codex CLI via OpenAI's native installer (self-updating), mirroring the
    #    claude module's native-install decision. A failed install stops before any Codex
    #    configuration or resource projection.
    if ! ensure_codex_cli; then
        return
    fi

    # 2. Global config: standalone posture (workspace-write + on-request). Copied (not
    #    symlinked) so the live copy can drift — same choice the claude module makes on Windows.
    copy_dotfile "$DOTFILES/codex/config.toml" "$HOME/.codex/config.toml"

    # 3. Shared conventions — same source the claude module installs to ~/.claude/AGENTS.md.
    copy_dotfile "$DOTFILES/ai-agents/AGENTS.md" "$HOME/.codex/AGENTS.md"

    # 4. Register Codex as a user-scope, read-only MCP reviewer in Claude Code. The -c overrides
    #    pin the reviewer read-only and non-interactive regardless of ~/.codex/config.toml.
    #    Idempotent: remove any prior entry first. Requires the Claude settings file too — its
    #    absence means the claude module has not run yet.
    local claude_settings="$HOME/.claude/settings.json"
    if ! command -v claude >/dev/null 2>&1; then
        warn 'claude CLI not found — skipping MCP registration. Install the claude module first.'
    elif [[ ! -f "$claude_settings" ]]; then
        warn 'Claude settings file not found — skipping MCP registration. Install the claude module first.'
    elif [[ $DRY_RUN -eq 1 ]]; then
        info '[DRY RUN] would register user-scope MCP: claude mcp add --scope user codex -- codex mcp-server -c sandbox_mode=read-only -c approval_policy=never -c model_reasoning_effort=medium'
    else
        claude mcp remove --scope user codex >/dev/null 2>&1 || true
        if claude mcp add --scope user --transport stdio codex -- codex mcp-server -c sandbox_mode=read-only -c approval_policy=never -c model_reasoning_effort=medium; then
            ok 'Registered read-only Codex MCP reviewer (user scope).'
        else
            fail 'claude mcp add failed.'
        fi
    fi

    # 5. Skills — project portable and Codex-native variants into ~/.codex/skills/.
    #    Codex's own built-in skills under ~/.codex/skills/.system/ remain untouched.
    local skills_dst="$HOME/.codex/skills"
    local portable_skills_root="$DOTFILES/ai-agents/skills"
    local native_skills_root="$DOTFILES/codex/skills"
    # Scoped to roots install_codex itself has ever written into. install_codex postdates the
    # ai-agents rehome entirely (added in 57b243d) and has only ever symlinked from
    # ai-agents/skills and codex/skills — never from claude/skills or any historical
    # ai-agents/shared or ai-agents/codex root (see issue #71).
    local managed_skill_roots=("$portable_skills_root" "$native_skills_root")
    if [[ $DRY_RUN -eq 0 ]]; then mkdir -p "$skills_dst"; fi
    local skill_dir skill_name link entry entry_name
    declare -A native_names=() desired_names=()
    while IFS= read -r -d '' skill_dir; do
        native_names["$(basename "$skill_dir")"]=1
        desired_names["$(basename "$skill_dir")"]=1
    done < <(find "$native_skills_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    while IFS= read -r -d '' skill_dir; do
        skill_name="$(basename "$skill_dir")"
        [[ -n "${native_names[$skill_name]:-}" ]] && continue
        desired_names["$skill_name"]=1
    done < <(find "$portable_skills_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    if [[ -d "$skills_dst" ]]; then
        while IFS= read -r -d '' entry; do
            entry_name="$(basename "$entry")"
            [[ -n "${desired_names[$entry_name]:-}" ]] && continue
            is_managed_skill_link "$entry" "${managed_skill_roots[@]}" || continue
            if [[ $DRY_RUN -eq 1 ]]; then info "[DRY RUN] remove obsolete Codex skill link: $entry"; else rm "$entry"; warn "Removed obsolete Codex skill link: $entry"; fi
        done < <(find "$skills_dst" -mindepth 1 -maxdepth 1 -type l -print0 2>/dev/null)
    fi
    project_codex_skill() {
        local source="$1" project_name project_link
        project_name="$(basename "$source")"
        project_link="$skills_dst/$project_name"
        if [[ -e "$project_link" && ! -L "$project_link" ]]; then
            warn "Preserved unmanaged Codex skill: $project_link"
            return
        fi
        if [[ -L "$project_link" ]] && ! is_managed_skill_link "$project_link" "${managed_skill_roots[@]}"; then
            if [[ ! -e "$project_link" ]]; then
                warn "Preserved unmanaged Codex skill link (target missing): $project_link"
            else
                warn "Preserved unmanaged Codex skill link: $project_link"
            fi
            return
        fi
        make_symlink "$source" "$project_link"
    }
    while IFS= read -r -d '' skill_dir; do
        [[ -n "${native_names[$(basename "$skill_dir")]:-}" ]] && continue
        project_codex_skill "$skill_dir"
    done < <(find "$portable_skills_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    while IFS= read -r -d '' skill_dir; do
        project_codex_skill "$skill_dir"
    done < <(find "$native_skills_root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    info 'Next: run codex login (interactive ChatGPT-account OAuth) to authenticate.'
}

install_ai_agents() {
    echo ''
    info '=== AI Agents (composite: Claude, Codex, Pi) ==='
    # Orchestrates the existing claude/codex/pi modules without duplicating their projection
    # logic. Order matters: install_codex's MCP registration (step 4) gates on
    # ~/.claude/settings.json already existing, so Claude must project first.
    install_claude
    install_codex
    # Pi is the least stable of the three (npm-installed, third-party CLI) — an unhandled error
    # here must not take down Claude/Codex projection that already ran, nor abort modules listed
    # after this one in the same invocation. `errexit` is ignored for the entire compound list
    # tested by an `if`/`&&`/`||`/`!`, including any subshell inside it — even one that explicitly
    # re-enables `set -e` — so `if ! ( set -e; install_pi ); then ...` would not help: a failing
    # command partway through install_pi would still silently continue, exactly like calling
    # install_pi directly as the condition. Instead, install_pi runs in a subshell as a plain
    # (non-conditional) statement, with the parent's own `set -e` toggled off just for that
    # statement so its nonzero exit doesn't abort the parent script. The subshell's own `set -e`
    # is a fresh, un-exempted context, so a failing command anywhere inside install_pi (or
    # anything it calls) aborts that subshell immediately, and only its exit status reaches
    # $pi_status. install_pi's own guarded fail+return paths are unaffected and keep returning
    # cleanly (0), since they were never relying on this mechanism.
    set +e
    ( set -e; install_pi )
    local pi_status=$?
    set -e
    if [[ $pi_status -ne 0 ]]; then
        fail 'Pi setup failed unexpectedly — Claude and Codex projection are unaffected.'
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
        codex)      install_codex      ;;
        pi)         install_pi         ;;
        ai-agents)  install_ai_agents  ;;
        langservers) install_langservers ;;
        lazygit)         install_lazygit    ;;
        windowsterminal) warn 'Windows Terminal is Windows-only — skipping.' ;;
        *)               warn "Unknown module '$module' — skipping." ;;
    esac
done

[[ $CLEAN_BACKUPS -eq 1 ]] && clean_backups

echo ''
ok 'Done.'
