#!/usr/bin/env python3
"""
Neovim config installer — Linux and Windows (run with python3 / py)
Designed to be composable into a larger dotfiles install script.
"""

import os
import platform
import shutil
import sys
from datetime import datetime
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────

FILES = [
    "init.lua",
    "lua/config/performance.lua",
    "lua/config/user.lua",
    "lua/config/plugins.lua",
    "lua/config/options.lua",
    "lua/config/keymaps.lua",
    "lua/config/autocmds.lua",
    "lua/config/treesitter.lua",
    "lua/config/lsp.lua",
    "lua/config/gitsigns.lua",
    "lua/config/ui.lua",
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def info(msg: str)    -> None: print(f"[INFO]  {msg}")
def success(msg: str) -> None: print(f"[OK]    {msg}")
def warn(msg: str)    -> None: print(f"[WARN]  {msg}", file=sys.stderr)
def die(msg: str)     -> None: print(f"[ERROR] {msg}", file=sys.stderr); sys.exit(1)

def check_dep(name: str) -> None:
    if not shutil.which(name):
        die(f"'{name}' is required but not found in PATH.")

def get_nvim_config_dir() -> Path:
    system = platform.system()
    if system == "Windows":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if not local_app_data:
            die("LOCALAPPDATA environment variable is not set.")
        return Path(local_app_data) / "nvim"
    elif system == "Linux":
        xdg_config = os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
        return Path(xdg_config) / "nvim"
    else:
        die(f"Unsupported platform: {system}. Only Linux and Windows are supported.")

# ── Install ───────────────────────────────────────────────────────────────────

def install(source_dir: Path | None = None) -> None:
    """
    Install the Neovim config.

    Args:
        source_dir: Root of the nvim config source tree.
                    Defaults to the directory containing this script.
    """
    script_dir  = source_dir or Path(__file__).parent.resolve()
    nvim_source = script_dir
    nvim_config = get_nvim_config_dir()

    info("Checking dependencies...")
    check_dep("nvim")
    check_dep("git")

    # Backup existing config
    if nvim_config.exists():
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup    = nvim_config.parent / f"{nvim_config.name}.bak.{timestamp}"
        warn(f"Existing config found. Backing up to: {backup}")
        shutil.move(str(nvim_config), str(backup))

    info(f"Installing Neovim config to: {nvim_config}")

    for relative in FILES:
        # Normalise separators for the current OS
        rel_path  = Path(relative)
        src       = nvim_source / rel_path
        dest      = nvim_config / rel_path

        if not src.exists():
            die(f"Source file not found: {src}")

        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(str(src), str(dest))

    success("Neovim config installed.")
    info("Open Neovim — plugins will be cloned automatically on first launch.")


if __name__ == "__main__":
    install()