# git

Git configuration, global ignore rules, commit template, and hook templates.

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| [delta](https://github.com/dandavison/delta) | Pager, diff viewer | `winget install dandavison.delta` / `cargo install git-delta` |
| [nvim](https://neovim.io) | Commit editor | see `nvim/` |
| pwsh 7+ | PowerShell hook variant | `winget install Microsoft.PowerShell` |

## Files

| File | Installed as | Notes |
|---|---|---|
| `gitconfig` | `~/.gitconfig` | Base config for all machines |
| `gitconfig-work` | `~/.gitconfig-work` | Work overrides; auto-included per-repo via `[includeIf]` |
| `gitignore` | `~/.gitignore` | Global ignore rules |
| `gitmessage` | `~/.gitmessage` | Commit message template |
| `templates/` | `~/.git_templates/` | Hook templates copied into every new repo |
| `work-hooks/` | `~/.git_work_hooks/` | Work-only hooks, wired via `[hook]` in `gitconfig-work`. **Not** under `~/.git_templates/` — see below |

## Key settings

- **Delta** as pager and diff filter — side-by-side view, line numbers, syntax highlighting
- **`[delta "dark-mode"]` / `[delta "light-mode"]`** — Catppuccin Mocha/Latte syntax-theme feature blocks, selected via `$env:DELTA_FEATURES` (set alongside `BAT_THEME` in the PowerShell profile) so delta's colors track the OS dark/light setting
- **Histogram diff algorithm** — better diff quality on refactored code
- **zdiff3 conflict style** — shows common ancestor in conflict markers
- **`pull.ff = only`** — never creates merge commits on pull
- **`rebase.updateRefs = true`** — automatic stacked branch ref updates
- **`rebase.rescheduleFailedExec = true`** — retry failed `exec` steps in interactive rebase
- **`merge.autoStash = true`** — parallels `rebase.autoStash`: auto-stash/pop local changes around a merge
- **`rerere.enabled = true`** — remembers and replays conflict resolutions
- **`rerere.autoUpdate = true`** — stages a rerere-resolved conflict automatically, no manual `git add`
- **`tag.sort = version:refname`** — `git tag` lists in version order instead of creation-date order
- **`help.autocorrect = prompt`** — prompts before running a corrected mistyped command, instead of auto-executing it
- **`fetch.parallel = 0`** — let git pick the parallelism for multi-remote/submodule fetches
- **`push.autoSetupRemote = true`** — no manual upstream needed on first push
- **`push.useForceIfIncludes = true`** — safety check: force push only if remote hasn't diverged unexpectedly
- **`fetch.fsckObjects` + `transfer.fsckObjects`** — integrity check on every fetch/clone
- **`column.ui = auto`** — columnize `git branch`, `git tag`, and similar list output
- **`maintenance.strategy = incremental`** — background repo maintenance; activate per-repo with `git maintenance register`
- **`submodule.fetchJobs = 0`** (work only, `gitconfig-work`) — parallelizes submodule fetches, alongside `submodule.recurse = true`
- **GitHub SSH rewrite** — both `https://github.com/` and `gh:` resolve to SSH

## Work identity (`[includeIf]`)

Work email and `diff.tool = delta` are applied automatically for any repo whose
remote URL matches the work domain. Requires Git 2.36+. Three `hasconfig:remote.*.url`
stanzas cover HTTPS (with and without embedded userinfo) and SSH clones of the same
Azure DevOps org, plus a `gitdir/i` fallback for a fixed local work path.

For local-only work repos without a remote yet:
```sh
git config user.email your-work-email
```

## Hooks (`templates/hooks/`)

Hooks are copied into `~/.git_templates/` and inherited by every new repo via
`init.templatedir`. Existing repos need `git init` re-run to pick them up.

### `prepare-commit-msg`

A sh dispatcher that delegates to `.ps1` (if pwsh is available) or `.sh`
(POSIX fallback). Both implementations:

- Detect JIRA tickets (`WORD-123`) or ADO work items (numeric) from the branch name
- Append as a footer trailer — keeps the subject line clean for conventional commits:
  ```
  feat(scope): add the thing

  Refs: PROJ-123
  ```
  or for ADO:
  ```
  feat(scope): add the thing

  Refs: AB#1234
  ```
- Skip merge and squash commits
- Skip configurable branches (default: `main`, `master`, `develop`, `staging`, `test`, `deploy/*`)
- Skip if the trailer is already present (safe to `--amend`)

Override the skip list per-repo:
```sh
git config hooks.skipBranches "main,release/*,hotfix/*"
```

### `post-commit`, `post-checkout`, `post-merge`, `post-rewrite`

Auto-regenerate ctags after relevant git operations. Reads `~/.ctags` for
tag configuration. Create a `.notags` file in any repo to disable.

## Work-only hooks (`work-hooks/`)

`core.hooksPath` is global — it cannot scope a hook to work repos. Git 2.54's
**config-based hooks** can, because a `[hook]` stanza obeys the same `[includeIf]`
conditions as everything else in `gitconfig-work`:

```ini
[hook "work-policy"]
    event = pre-commit
    command = "test -f ~/.git_work_hooks/policy || exit 0; exec ~/.git_work_hooks/policy"
```

Three things about that value are load-bearing, all pinned by
`tests/git-work-hooks.Tests.ps1`:

- **The guard makes it fail open when the dispatcher isn't installed.** Git does
  *not* fail open on a missing command — it errors `cannot spawn <path>` and
  **blocks the commit**. `~/.gitconfig-work` includes the repo copy, so the stanza
  goes live the moment a clone pulls, while `~/.git_work_hooks` only appears once
  `setup.ps1 -Module git` re-runs; without the guard every work commit fails in
  that window. A dispatcher that *is* present and exits non-zero still blocks.
- **`-f` (exists), not `-x` (executable).** Fail-open is meant to cover "not
  installed yet", never "installed but broken". With `-x`, a present-but-non-
  executable dispatcher — an install that dropped the exec bit — makes the guard
  exit 0 and the policy is **silently skipped**; with `-f` it reaches `exec` and
  fails loudly (126). The difference is only visible on Linux: Windows reports
  every file executable and `chmod` is a no-op there.
- **The double quotes are required.** `;` starts a comment in git config, so
  unquoted the value silently truncates to `test -f ... || exit 0` — the policy
  never runs and the hook enforces nothing while still appearing in
  `git hook list`. Git strips the quotes before handing the value to sh, so `~`
  still expands. (`test -x ... && exec ...` dodges the `;` but is wrong: with the
  dispatcher absent, `test` exits 1 and that becomes the hook's status, blocking
  the commit. The explicit `|| exit 0` is what fails open.)

`policy` is a POSIX-sh dispatcher that execs `policy.ps1` (pwsh) or `policy.sh`
(fallback) — the same shim pattern as `prepare-commit-msg`. It is an **example
placeholder**: it looks for a generic `work-policy-scan` tool, and when absent
warns and allows the commit (fails **open**, like the gitleaks hook). Override
the tool name with `WORK_POLICY_TOOL`; bypass one commit with
`SKIP_WORK_POLICY=1 git commit ...`.

### Why this splits when `pre-commit` doesn't

The gitleaks `pre-commit` is one sh file, and documents that a `.ps1`/`.sh` split
is only warranted for real pwsh-native logic. This hook splits anyway, for a
reason that rule doesn't cover: **sh and pwsh resolve PATH differently.**
`command -v` follows Unix semantics and does not find a Windows `.cmd`/`.bat`/
`.ps1` — only `.exe` — while pwsh's `Get-Command` honours `PATHEXT` and does.
gitleaks is unaffected because it ships as a `.exe`. A policy scanner shipping as
a `.cmd` wrapper would be invisible to sh, and this hook fails **open**, so an
sh-only version would silently enforce nothing on Windows — the same trap as
running it on git < 2.54. Collapse to a single sh file only once the scanner is
guaranteed to be a `.exe`.

### Ordering is additive — existing hooks still run

Configured hooks run **first** (system → global → local, in file order), then the
`core.hooksPath` script runs **last**. The gitleaks `pre-commit` and the
`prepare-commit-msg` ticket trailer are untouched. Verify:

```console
$ git hook list pre-commit          # in a work repo
work-policy
hook from hookdir                   # <- the gitleaks pre-commit, still last

$ git hook list pre-commit          # in a personal repo
hook from hookdir                   # work-policy absent: [includeIf] did not match
```

`git hook list --show-scope pre-commit` adds where each came from (`global`,
`local`). Opt out without deleting the stanza:

```sh
git config hook.work-policy.enabled false   # -> "disabled  work-policy"
```

### Why not `~/.git_templates/work-hooks`?

`init.templatedir` copies the template directory's **contents** into every new
repo's `.git/`, so nesting the work hooks there would put a `.git/work-hooks/` in
every personal repo. `~/.git_work_hooks` is a sibling path, outside templatedir.

The `command` path is deliberately **unquoted**: git runs it through `sh`, which
expands the leading `~`. Quoting would defeat that, so the path must stay free of
spaces (`sh` word-splits an unquoted path).

### Requires Git >= 2.54

```sh
git --version
```

Below 2.54 the `[hook]` stanza is **ignored silently** — no error, the hook simply
never runs, and `git hook list` does not exist. For a *policy* hook that is a trap,
so `setup.ps1`/`setup.sh -Module git` check the version and warn at install time.
Verified on 2.55.0.windows.2; Debian bookworm ships 2.39.2, so WSL needs a newer
git before the stanza does anything there.

**No config key enables parallel hooks.** `hook.<name>.parallel = true` is silently
ignored (unknown hook keys always are) — measured identical serial timing with and
without it on 2.55. Only `git hook run --jobs=N` runs same-event hooks
concurrently, and git does not use it on the commit path, so `git commit` is
serial regardless.

## fsmonitor

`core.fsmonitor = true` and `core.untrackedCache = true` are set in the **base**
`gitconfig`, so they apply everywhere, not just work repos. They speed up the
status-heavy PowerShell prompt (`Set-Prompt.ps1` shells out to
`git status --porcelain` on every prompt) by having a daemon watch the filesystem
instead of rescanning it.

Caveats:

- Spawns a per-repo background daemon (`git fsmonitor--daemon`), so tiny repos pay
  startup cost for little gain. Disable per-repo with
  `git config core.fsmonitor false`.
- Windows has a native daemon; **Linux needs Git >= 2.55** for the inotify backend.
  On older Linux git the setting is inert.
- `untrackedCache` needs a filesystem with reliable mtimes; git probes on enable.

## Install

```sh
./setup.ps1 -Module git   # Windows
./setup.sh  -m git        # Linux / WSL
```

Installs `~/.gitconfig` and `~/.gitconfig-work` as `[include]` stubs pointing
to the repo files (changes are live immediately, works cross-volume).
Junctions/symlinks `~/.git_templates` → `git/templates/` and `~/.git_work_hooks`
→ `git/work-hooks/`, then warns if git is older than 2.54.
