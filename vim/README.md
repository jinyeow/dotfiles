# vim

Legacy Vimscript config — kept as a fallback for machines where Neovim isn't
available. The active config is in `nvim/`.

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| Vim 8+ | Editor | `winget install vim.vim` / system package manager |

## Files

| File | Installed as | Notes |
|---|---|---|
| `vimrc` | `~/vimfiles/vimrc` (Win) / `~/.vim/vimrc` (Linux) | Main config — Vim finds it automatically inside the vimfiles dir |

The rest of `vim/` is the vimfiles directory itself (installed as `~/vimfiles`
or `~/.vim`). Notable subdirectories:

| Directory | Purpose |
|---|---|
| `common/after/ftplugin/` | Filetype-specific settings (indent, formatoptions, etc.) |
| `common/after/` | Settings applied after plugins load |
| `b16.vim` | Base16 colour scheme helper |

## Key settings (vimrc)

- 2-space tabs, `expandtab`, `smarttab`
- `relativenumber` + `number`
- `wildmode=list:full` with wildignore for build artefacts
- `tags` search from file directory up to `$HOME`
- `matchit.vim` enabled (extends `%` to match `def/end`, HTML tags, etc.)
- `laststatus=2` — statusline always visible
- `undofile` — persistent undo across sessions

## Install

```sh
./setup.ps1 -Module vim   # Windows — junctions ~/vimfiles → vim/
./setup.sh  -m vim        # Linux   — symlinks ~/.vim     → vim/
```

Vim finds `vimrc` at `~/vimfiles/vimrc` (Windows) or `~/.vim/vimrc` (Linux)
automatically — no separate vimrc link needed.
