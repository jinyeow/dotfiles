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

## Local patches

Two deliberate divergences from upstream, kept in-repo:

- **`psmux-resurrect/scripts/save.ps1`** — a zero-session guard: if a save captures no
  sessions it skips writing and keeps the previous `last` snapshot, and the `list-sessions`
  retry discards output on a non-zero psmux exit so a "no server running" stderr line can't be
  parsed as a bogus session. Without this, the 15-min auto-save loop firing against a server
  with no sessions clobbers the last good snapshot, so restore-on-server-start brings back
  nothing. Covered by `tests/psmux.Tests.ps1` (empty-output + psmux-error cases).
- **`psmux-sidebar/plugin.conf`** — the `Prefix+Tab`/`Prefix+BTab` binds resolve the plugin's
  own script path via `$env:USERPROFILE` instead of a literal `~`. `run-shell` runs its
  argument as PowerShell, so `$env:USERPROFILE` is expanded by the outer pwsh before the inner
  `pwsh -File` ever sees it; `pwsh -File` itself does **not** tilde-expand, so a literal `~`
  would fail to find the script and the bind would silently no-op (psmux's own `~` handling is
  also unreliable — see `psmux/psmux.conf`). The rationale is inlined as a comment above the
  binds in `plugin.conf` itself.

A re-copy during an update (below) overwrites both — **re-apply both patches after step 2** and
confirm `tests/psmux.Tests.ps1` passes.

## Updating

Deliberate, reviewed bumps only:
1. `git clone https://github.com/psmux/psmux-plugins.git` at the new revision.
2. Re-copy `psmux-resurrect`, `psmux-continuum`, `psmux-sidebar` over these dirs.
3. Re-apply **both** local patches above (`save.ps1`'s zero-session guard, and
   `psmux-sidebar/plugin.conf`'s `$env:USERPROFILE` binds) and run `tests/psmux.Tests.ps1`.
4. Update the pinned commit above and review the diff (`git diff`) before committing.

Otherwise do **not** edit these files in place — they are upstream code, save for the
documented patches above.
