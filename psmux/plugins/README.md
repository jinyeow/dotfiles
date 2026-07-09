# Vendored psmux plugins

Third-party psmux plugins **vendored and pinned** into the repo, not fetched at runtime.

| Source | `github.com/psmux/psmux-plugins` |
|---|---|
| Pinned commit | `0f46ccca5a9b748fd03851db00b85fd784f42791` |
| Vendored | `psmux-resurrect`, `psmux-continuum`, `psmux-sidebar` |

## Why vendored, and why no PPM

PPM (the plugin manager) resolves each `@plugin 'psmux-plugins/<name>'` by cloning
`github.com/psmux-plugins/<name>.git` **first** — an org that is currently **unregistered**
(HTTP 404), i.e. an attacker-registrable namespace whose code would then run via
`run '~/.psmux/plugins/ppm/ppm.ps1'` at startup (namespace-hijack → RCE).

We avoid PPM **entirely**. Each plugin ships a `plugin.conf` (its "source-file compatible" static
form — the keybinds and hooks) plus pre-generated `scripts/`, so `psmux.conf` loads them with plain
`source-file '~/.psmux/plugins/<name>/plugin.conf'` — no resolver, no `@plugin`, no `run ppm.ps1`,
no network, no `Prefix+I/U/M`. `ppm` itself is not carried at all.

`setup.ps1 -Module psmux` **copies** every dir here into `~/.psmux/plugins/` (a generic loop over the
subdirectories — adding a plugin dir needs no installer edit). Copied, not junctioned: `psmux-continuum`
rewrites its own `scripts/` at load, so a junction would mutate the committed repo. `psmux-sidebar` is
stateless by contrast — its `scripts/` are static and its PPM loader (`psmux-sidebar.ps1`) is never run,
so `psmux.conf` `source-file`s its `plugin.conf` directly (Prefix+Tab toggles a directory-tree pane).

The theme, `sensible`, and `prefix-highlight` plugins are **not** vendored — their behaviour is inlined
as native `set` lines in `psmux.conf`. Likewise `psmux-pain-control` is **not** vendored: it ships only
keybindings, so its useful binds (vim-key resize, `Prefix+</>` window reorder, `|`/`-` split aliases) are
inlined into `psmux.conf`. Only the stateful persistence plugins + the sidebar carry vendored PowerShell.

## Updating

Deliberate, reviewed bumps only:
1. `git clone https://github.com/psmux/psmux-plugins.git` at the new revision.
2. Re-copy `psmux-resurrect`, `psmux-continuum`, `psmux-sidebar` over these dirs.
3. Update the pinned commit above and review the diff (`git diff`) before committing.

Do **not** edit these files in place — they are upstream code.
