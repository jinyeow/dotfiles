#!/usr/bin/env bash
set -euo pipefail

NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_SOURCE_DIR="$SCRIPT_DIR/nvim"

# ── Helpers ───────────────────────────────────────────────────────────────────

info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
die()     { echo "[ERROR] $*" >&2; exit 1; }

check_dep() {
  command -v "$1" &>/dev/null || die "'$1' is required but not found in PATH."
}

# ── Preflight ─────────────────────────────────────────────────────────────────

info "Checking dependencies..."
check_dep nvim
check_dep git

# ── Backup existing config ────────────────────────────────────────────────────

if [[ -e "$NVIM_CONFIG_DIR" ]]; then
  BACKUP="${NVIM_CONFIG_DIR}.bak.$(date +%Y%m%d_%H%M%S)"
  warn "Existing config found. Backing up to: $BACKUP"
  mv "$NVIM_CONFIG_DIR" "$BACKUP"
fi

# ── Install ───────────────────────────────────────────────────────────────────

info "Installing Neovim config to: $NVIM_CONFIG_DIR"
mkdir -p "$NVIM_CONFIG_DIR/lua/config"

cp "$NVIM_SOURCE_DIR/init.lua"                    "$NVIM_CONFIG_DIR/init.lua"
cp "$NVIM_SOURCE_DIR/lua/config/performance.lua"  "$NVIM_CONFIG_DIR/lua/config/performance.lua"
cp "$NVIM_SOURCE_DIR/lua/config/user.lua"         "$NVIM_CONFIG_DIR/lua/config/user.lua"
cp "$NVIM_SOURCE_DIR/lua/config/plugins.lua"      "$NVIM_CONFIG_DIR/lua/config/plugins.lua"
cp "$NVIM_SOURCE_DIR/lua/config/options.lua"      "$NVIM_CONFIG_DIR/lua/config/options.lua"
cp "$NVIM_SOURCE_DIR/lua/config/keymaps.lua"      "$NVIM_CONFIG_DIR/lua/config/keymaps.lua"
cp "$NVIM_SOURCE_DIR/lua/config/autocmds.lua"     "$NVIM_CONFIG_DIR/lua/config/autocmds.lua"
cp "$NVIM_SOURCE_DIR/lua/config/treesitter.lua"   "$NVIM_CONFIG_DIR/lua/config/treesitter.lua"
cp "$NVIM_SOURCE_DIR/lua/config/lsp.lua"          "$NVIM_CONFIG_DIR/lua/config/lsp.lua"
cp "$NVIM_SOURCE_DIR/lua/config/gitsigns.lua"     "$NVIM_CONFIG_DIR/lua/config/gitsigns.lua"
cp "$NVIM_SOURCE_DIR/lua/config/ui.lua"           "$NVIM_CONFIG_DIR/lua/config/ui.lua"

success "Neovim config installed."
info "Open Neovim — plugins will be cloned automatically on first launch."