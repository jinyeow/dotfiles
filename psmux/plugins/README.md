# Vendored psmux plugins

Third-party psmux plugins **vendored and pinned** into the repo, not fetched at runtime.

| Source | `github.com/psmux/psmux-plugins` |
|---|---|
| Pinned commit | `0f46ccca5a9b748fd03851db00b85fd784f42791` |
| Vendored | `psmux-resurrect`, `psmux-continuum` |

## Why vendored, and why no PPM

PPM (the plugin manager) resolves each `@plugin 'psmux-plugins/<name>'` by cloning
`github.com/psmux-plugins/<name>.git` **first** — an org that is currently **unregistered**
(HTTP 404), i.e. an attacker-registrable namespace whose code would then run via
`run '~/.psmux/plugins/ppm/ppm.ps1'` at startup (namespace-hijack → RCE).

We avoid PPM **entirely**. Each plugin ships a `plugin.conf` (its "source-file compatible" static
form — the keybinds and hooks) plus pre-generated `scripts/`, so `psmux.conf` loads them with plain
`source-file '~/.psmux/plugins/<name>/plugin.conf'` — no resolver, no `@plugin`, no `run ppm.ps1`,
no network, no `Prefix+I/U/M`. `ppm` itself is not carried at all.

`setup.ps1 -Module psmux` **copies** these committed dirs into `~/.psmux/plugins/` (copied, not
junctioned: `psmux-continuum` rewrites its own `scripts/` at load, so a junction would mutate the
committed repo).

The theme, `sensible`, and `prefix-highlight` plugins are **not** vendored — their behaviour is
inlined as native `set` lines in `psmux.conf`, so only the two stateful persistence plugins carry
vendored PowerShell.

## Updating

Deliberate, reviewed bumps only:
1. `git clone https://github.com/psmux/psmux-plugins.git` at the new revision.
2. Re-copy `psmux-resurrect`, `psmux-continuum` over these dirs.
3. Update the pinned commit above and review the diff (`git diff`) before committing.

Do **not** edit these files in place — they are upstream code.
