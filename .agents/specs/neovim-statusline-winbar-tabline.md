# Neovim statusline, winbar, and tabline

## Problem Statement

Neovim runs with its default statusline. The default does not show the current working
directory, so it is hard to know where a relative path for `:e` starts. It does not show
the git branch. In the bare-repo + worktree layout, the branch and the directory together
identify which checkout is open, and neither is visible. With several tabs open, there is
no tab number to use with `{N}gt`.

## Solution

A native-Lua set of bars that replaces the defaults in both profiles:

- **Winbar** (top of each window): the window's working directory on the left, with a
  marker when the window or tab has its own directory. The current buffer's position
  among listed buffers on the right.
- **Statusline** (bottom of each window): the mode initial in a mode-coloured block, the
  git branch with diff counts, a separator, the file path relative to the working
  directory with modified/read-only flags, then diagnostics, LSP client names,
  non-default file format or encoding, and cursor position.
- **Tabline**: each tab as a zero-padded two-digit number and the name of its active
  file, for example `01 README.md  02 AGENTS.md`.

Rendered examples from the prototype (80 columns):

```text
winbar:     E:/Personal Projects/dotfiles/main                                         2/2
statusline: N  main +1 ~1 │ README.md [+]                                         1:1 0%
tabline:    01 README.md  02 AGENTS.md  03 [No Name]
```

## User Stories

1. As a Neovim user, I want the working directory at the top left of each window, so that I know where a relative `:e` path starts.
2. As a Neovim user, I want the directory shortened with `~` when it is under my home directory, so that it takes less space.
3. As a Neovim user, I want a `[win]` marker when the window has a local directory (`:lcd`), so that I know this window resolves paths differently from the others.
4. As a Neovim user, I want a `[tab]` marker when the tab has a tab directory (`:tcd`), so that I know the tab resolves paths differently.
5. As a Neovim user, I want each window's winbar to show the directory for that window, so that split windows with different local directories are each correct.
6. As a Neovim user, I want the current buffer's position among listed buffers (`3/7`) at the top right, so that I know how many buffers are open and where I am in the `:bnext` order.
7. As a Neovim user, I want `-/7` when the current buffer is unlisted, so that the count stays correct for help and other unlisted buffers.
8. As a Neovim user, I want the mode shown as a single initial (N, I, V, R, C, T, S) at the bottom left, so that it takes little space.
9. As a Neovim user, I want the mode block coloured per mode, so that I can see the mode at a glance.
10. As a Neovim user, I want the mode colours to come from the active colorscheme and update when it changes, so that they work in Catppuccin mocha, Catppuccin latte, and the minimal profile's built-in schemes.
11. As a Neovim user, I want the git branch after the mode block, so that I can see which branch the file is on.
12. As a Neovim user, I want gitsigns diff counts (`+a ~c -r`, non-zero parts only) after the branch, so that I can see uncommitted change size.
13. As a Neovim user, I want a `│` separator between the git information and the file name, so that the two read as separate groups.
14. As a Neovim user, I want no branch, no diff counts, and no separator outside a git repository, so that the bar has no empty or misleading parts.
15. As a Neovim user, I want no worktree tag, because the directory and branch already identify the checkout.
16. As a Neovim user, I want the file path relative to the working directory, so that it matches what I would type after `:e`.
17. As a Neovim user, I want a file outside the working directory shown with its full path shortened with `~`, so that I can see that a relative path will not reach it.
18. As a Neovim user, I want `[+]` for a modified buffer and `[RO]` for a read-only or non-modifiable normal buffer, so that I do not lose edits or try to edit a locked buffer. Terminals show no `[RO]`.
19. As a Neovim user, I want diagnostic counts per severity on the right, so that I can see problems in the file without opening a list.
20. As a Neovim user, I want the names of attached LSP clients on the right, so that I can confirm the language server attached.
21. As a Neovim user, I want `CRLF` shown only when the file format is `dos`, so that I can catch line-ending problems on Windows without noise on normal files.
22. As a Neovim user, I want the encoding shown only when it is not UTF-8, so that unusual encodings stand out.
23. As a Neovim user, I want line, column, and percentage at the bottom right, so that I know my position in the file.
24. As a Neovim user in a narrow window, I want the file name truncated first, so that the mode, branch, and position stay visible.
25. As a Neovim user, I want the tabline to number each tab as `01`, `02`, and so on, so that I can jump with `{N}gt`.
26. As a Neovim user, I want each tab label to show the file in that tab's active window, so that I can recognise the tab.
27. As a Neovim user, I want to click a tab label to switch to it, so that mouse use works.
28. As a Neovim user, I want the tabline to appear only with two or more tabs (Neovim's default), so that a single tab costs no screen line.
29. As a Neovim user on the minimal profile, I want the same bars without gitsigns, with the branch from a cached git lookup and no diff counts, so that both profiles look the same.
30. As a Neovim user, I want no shell command run on each redraw, so that the bars do not slow down editing.
31. As a Neovim user, I want the branch to refresh after `:cd`, a focus change, or a gitsigns update, so that it is not stale.
32. As a maintainer, I want automated tests for the rendered bar text, so that a change cannot break the layout without CI failing.

## Implementation Decisions

- **One module** in the Neovim config owns the statusline, winbar, tabline, their
  highlight groups, and their autocommands. `init.lua` loads it after the UI module, so
  the colorscheme is set before highlights are derived. The module loads in both the full
  and minimal profiles.
- **Interface**: the module sets `statusline`, `winbar`, and `tabline` to `%!` expressions
  that call three render functions on a module table. The render functions take no
  arguments and return a statusline-format string. The render functions read
  `g:statusline_winid` to find the window being drawn. Inside `%!`, the current window can
  differ from the drawn window (on 0.12.6 it was window 1001 for both windows, while
  `g:statusline_winid` was 1001 and 1000). The mode block shows only in the current window.
- **Options**: `laststatus = 2` (a statusline per window). `showtabline` stays at its
  default (shown with two or more tabs).
- **Git data**: read `vim.b.gitsigns_status_dict` (`head`, `added`, `changed`, `removed`)
  first. If gitsigns has not attached, use an async `git rev-parse --abbrev-ref HEAD` run
  with `vim.system`. The fallback runs `git -C <buffer's directory>`, or in the window's
  working directory for non-file buffers. The result is cached per directory. The cache is
  cleared on `DirChanged` and `FocusGained`. A generation check stops an in-flight lookup
  from overwriting a cleared cache. The bars redraw on the `GitSignsUpdate` user event and
  when the async lookup returns. If `git` is not on `PATH`, the fallback is off and the
  module shows one warning per session. Editing is never blocked. No worktree name is
  derived or shown.
- **Working directory**: for the drawn window `win` (from `g:statusline_winid`),
  `getcwd(win)` with `fnamemodify(':~')`. Backslashes are shown as forward slashes.
  `haslocaldir(win)` selects `[win]`. Otherwise the tab-level check
  `haslocaldir(-1, tabnr)` for the drawn window's tab selects `[tab]`.
- **File path**: `vim.fs.relpath(cwd, name)` against the drawn window's working directory.
  A file outside that directory shows its full path shortened with `~`. URI-style names
  (`oil://`, `term://`, `fugitive://`) are shown as-is. An empty name shows `[No Name]`.
  The `%<` truncation point sits before the file name. The `[RO]` flag shows for a
  `readonly` or non-`modifiable` buffer with an empty `buftype`. Terminals show no `[RO]`.
- **Buffer index**: listed buffers ordered by buffer number. The list is computed on each
  render, so it needs no cache and no refresh autocommands.
- **LSP names**: cached per buffer on `LspAttach`/`LspDetach` and joined with commas. The
  update is scheduled because `LspDetach` fires before the client is removed. The cache
  entry is removed when the buffer is deleted.
- **Diagnostics**: `vim.diagnostic.count(bufnr)` for the drawn window's buffer. The bars redraw on `DiagnosticChanged`.
- **Highlights**: groups are derived from the live colorscheme and re-applied on
  `ColorScheme`. Mode colours come from this mapping (from the prototype):

  ```lua
  -- mode key (first char of nvim_get_mode().mode) -> { initial, colour source group }
  n = { 'N', 'Function' }, i = { 'I', 'String' }, v/V/^V = { 'V', 'Statement' },
  R = { 'R', 'DiagnosticError' }, c = { 'C', 'DiagnosticWarn' }, t = { 'T', 'Type' },
  s/S/^S = { 'S', 'Statement' }
  ```

  The mode block uses the source group's foreground as its background and the `Normal`
  background as its foreground. Other parts use the `StatusLine` background with
  foregrounds from `Comment` (dim), `String` (branch), `Directory` (cwd), `Special`
  (markers), `WarningMsg` (flags), and the `Diagnostic*` groups. The segment groups keep a
  correct background in the statusline, the inactive statusline, and the winbar. The
  module accounts for `reverse` in `StatusLine` when it picks the background.
- **Tabline label**: `%{N}T` click target, then ` NN name `, where `NN` is the tab number
  zero-padded to two digits and `name` is the tail of the active window's buffer name.
  The current tab uses `TabLineSel`, the others use `TabLine`, and the rest uses
  `TabLineFill`.
- **Escaping**: user-controlled text (paths, branch, LSP names, tab names) has `%`
  doubled before it goes into a statusline string.

## Testing Decisions

- A good test asserts on the rendered bar text from `nvim_eval_statusline` (with
  `use_winbar` / `use_tabline` as needed, and a fixed `maxwidth`). It does not inspect
  module internals, autocommand registration, or highlight group values.
- The seam is the three rendered bars. A Pester test file launches headless Neovim with
  the module loaded against fixture directories it creates (a git repo, a non-git
  directory, a CRLF file), and asserts the returned strings.
- Cases to cover: directory and buffer index in the winbar; `[win]` after `:lcd` and
  `[tab]` after `:tcd`; mode initial; branch from the git fallback, separator, and
  relative file name in a git repo; no branch or separator outside git; `[+]` on a
  modified buffer; `CRLF` on a `dos` file and none on a `unix` file; `-/N` for an
  unlisted buffer; the file name truncated first at a narrow `maxwidth`; tab labels
  `01`, `02`, `03` with three tabs; a `%` in a file name rendered literally.
- Gitsigns diff counts and LSP names depend on plugins and servers that are not present
  in a clean headless run. Tests for these may stub the buffer variable
  (`gitsigns_status_dict`) and fire `LspAttach` with a fake client only if this does not
  require reaching into module internals. Otherwise these parts are verified by hand.
- Prior art: the repository's Pester suites under `tests/` (for example the prompt and
  setup tests) and the headless test script written for the prototype. There are no
  existing Neovim tests.

## Out of Scope

- Statusline plugins (lualine, heirline, mini.statusline). Repository policy keeps Neovim
  on native APIs.
- Worktree name detection or display.
- Showing macro recording or search count. Neovim already shows both in the command line
  with the current `showmode` and `cmdheight` settings.
- Keymaps for jumping to tabs. `{N}gt` already exists.
- A global statusline (`laststatus = 3`).
- Width thresholds that hide whole sections. The spec uses `%<` truncation only.
- Changes to the legacy Linux snapshot.

## Further Notes

- The prototype that this spec describes was tested with headless Neovim 0.12.6 on
  Windows. Mode colours in Catppuccin, LSP names, and diagnostics were not checked
  visually.
- CI installs Neovim. CI runs Pester on `windows-latest` and `ubuntu-latest`, and
  neither runner image includes Neovim. Both Pester jobs install it with
  `rhysd/action-setup-vim` (v1.6.1, `neovim: true`), so the new test file runs on both.
  The Neovim version is pinned to `v0.12.6`, the version the prototype was tested with.
  The pin keeps CI on the same version as local use, because statusline and `vim.pack`
  behaviour can change between releases.
- The test fails with a clear message when `nvim` is not on `PATH`. A skip would hide a
  broken bar if the install step failed.
- CI also runs a startup smoke test with `NVIM_PROFILE=minimal`. It runs headless Neovim
  with isolated XDG directories and fails on any startup error. The minimal profile
  loads no plugins, so the smoke test needs no network and no plugin install.
- Two checks are deferred to a separate change. A full-profile smoke test needs
  `vim.pack` to install plugins from the lockfile, which needs network access and a
  cache. `lua-language-server --check` can run as a CI mode: it exits 0 on pass and 1 on
  failure. No maintained install action exists for it, so it needs a release download.
- CI runs `stylua --check` over the Neovim config, so the module must pass stylua.
- `nvim/README.md` must describe the bars once they are implemented.
