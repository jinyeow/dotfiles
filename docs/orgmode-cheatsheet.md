# Neovim orgmode cheatsheet

Quick reference for [nvim-orgmode](https://github.com/nvim-orgmode/orgmode) as set up in
this repo (`nvim/lua/config/orgmode.lua`, full profile only). For what the config itself
binds and the `~/org` setup requirement, see
[`nvim/README.md`](https://github.com/jinyeow/dotfiles/blob/main/nvim/README.md) → Org.

The config sets no `mappings` block, so **these are orgmode's defaults** — they match
upstream's `lua/orgmode/config/defaults.lua`. The prefix is `<Leader>o`; every key below
is written out in full.

> **Learn this one first: `g?`.** It opens a popup listing the mappings available in the
> current context — org buffer, agenda, capture window, or src-block editor. It is
> context-aware, so it always shows the keys that actually work where you are. If you
> remember nothing else on this page, `g?` gets you the rest.

## From any buffer

These two are the only global mappings — everything else is buffer-local to org windows.

| Key | Action |
|---|---|
| `<leader>oa` | Open the agenda |
| `<leader>oc` | Capture (then pick a template) |

## Capture

Templates in this config: `t` Task → `~/org/inbox.org`, `p` PBI → `~/org/work.org` under
`* PBIs`, `j` Journal → `~/org/journal.org` (year → month → day datetree).

| Key | Action |
|---|---|
| `<C-c>` | Finalise the capture |
| `<leader>ok` | Abort the capture |
| `<leader>or` | Refile the capture somewhere else |
| `g?` | Help popup |

## Org buffer — everyday

The keys you will actually reach for while working a heading.

| Key | Action |
|---|---|
| `cit` | Cycle TODO state forward (`TODO` → `NEXT` → `WAIT` → `DONE`) |
| `ciT` | Cycle TODO state backward |
| `<C-Space>` | Toggle checkbox |
| `<TAB>` | Fold / unfold the heading under the cursor |
| `<S-TAB>` | Fold / unfold the whole document |
| `<leader><CR>` | New heading / list item / table row (context-dependent) |
| `<leader>oo` | Open the link under the cursor |
| `<leader>ona` | Add a note to the heading |
| `g?` | Help popup |

## Org buffer — clock

| Key | Action |
|---|---|
| `<leader>oxi` | Clock in |
| `<leader>oxo` | Clock out |
| `<leader>oxq` | Cancel the running clock |
| `<leader>oxj` | Jump to the currently clocked heading |
| `<leader>oxe` | Set effort estimate |

## Org buffer — dates

| Key | Action |
|---|---|
| `<leader>ois` | Schedule |
| `<leader>oid` | Deadline |
| `<leader>oi.` | Insert active timestamp |
| `<leader>oi!` | Insert inactive timestamp |
| `cid` | Change the date under the cursor |
| `<leader>od!` | Toggle timestamp active / inactive |
| `<S-UP>` / `<S-DOWN>` | Date under cursor ± 1 day |
| `<C-a>` / `<C-x>` | Increment / decrement the date part under the cursor |

## Org buffer — structure

| Key | Action |
|---|---|
| `<<` / `>>` | Promote / demote the heading |
| `<s` / `>s` | Promote / demote the whole subtree |
| `<leader>oK` / `<leader>oJ` | Move the subtree up / down |
| `<leader>oih` | New heading after this heading's content, same level |
| `<leader>oiT` | New TODO heading right after this one, same level |
| `<leader>oit` | New TODO heading after this heading's content, same level |
| `<leader>o*` | Toggle a line between heading and plain text |
| `}` / `{` | Next / previous visible heading |
| `]]` / `[[` | Next / previous heading at the same level |
| `g{` | Up to the parent heading |

## Org buffer — links

| Key | Action |
|---|---|
| `<leader>ols` | Store a link to the current location |
| `<leader>oli` | Insert a link (offers the stored one) |
| `<leader>oo` | Open the link under the cursor |

## Org buffer — tags, priority, refile, archive

| Key | Action |
|---|---|
| `<leader>ot` | Set tags |
| `<leader>o,` | Set priority |
| `ciR` / `cir` | Priority up / down |
| `<leader>or` | Refile the heading |
| `<leader>o$` | Archive the subtree |
| `<leader>oA` | Toggle the ARCHIVE tag |

## Org buffer — text objects

Use with any operator, e.g. `dih` deletes the heading, `yar` yanks the whole subtree.

| Object | Selects |
|---|---|
| `ih` / `ah` | Inner / around heading |
| `ir` / `ar` | Inner / around subtree |
| `Oh` / `OH` | Inner / around heading, from the root |
| `Or` / `OR` | Inner / around subtree, from the root |

## Agenda

| Key | Action |
|---|---|
| `<CR>` | Go to the item (switch to its buffer) |
| `<TAB>` | Go to the item in a split |
| `K` | Preview the item |
| `q` | Quit |
| `r` | Redo / refresh |
| `f` / `b` | Forward / back one span |
| `.` | Jump to today |
| `J` | Jump to a date |
| `vd` / `vw` / `vm` / `vy` | Day / week / month / year view |
| `/` | Filter |
| `t` | Cycle TODO state |
| `I` / `O` / `X` | Clock in / out / cancel |
| `R` | Toggle the clock report |
| `+` / `-` | Priority up / down |
| `<leader>oo` | Open the link at point |
| `<leader>oxj` | Jump to the clocked heading |
| `<leader>ois` / `<leader>oid` | Schedule / deadline |
| `<leader>ot` | Set tags |
| `<leader>or` | Refile |
| `<leader>o$` | Archive |
| `g?` | Help popup |

## Src blocks

| Key | Action |
|---|---|
| `<leader>o'` | Edit the block in a dedicated buffer (and save + exit from inside it) |
| `<leader>ow` | Save the edit buffer back |
| `<leader>ok` | Abort the edit |
| `<leader>obt` | Tangle the file |
