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

## Key settings

- **Delta** as pager and diff filter — side-by-side view, line numbers, syntax highlighting
- **Histogram diff algorithm** — better diff quality on refactored code
- **zdiff3 conflict style** — shows common ancestor in conflict markers
- **`pull.ff = only`** — never creates merge commits on pull
- **`rebase.updateRefs = true`** — automatic stacked branch ref updates
- **`rerere.enabled = true`** — remembers and replays conflict resolutions
- **`push.autoSetupRemote = true`** — no manual upstream needed on first push
- **GitHub SSH rewrite** — both `https://github.com/` and `gh:` resolve to SSH

## Work identity (`[includeIf]`)

Work email and `diff.tool = delta` are applied automatically for any repo whose
remote URL matches the work domain. Requires Git 2.36+.

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

## Install

```sh
./setup.ps1 -Module git   # Windows
./setup.sh  -m git        # Linux / WSL
```

Installs `~/.gitconfig` and `~/.gitconfig-work` as `[include]` stubs pointing
to the repo files (changes are live immediately, works cross-volume).
Junctions/symlinks `~/.git_templates` → `git/templates/`.
