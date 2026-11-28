# git

Git configuration, global ignore rules and attributes, commit template, and global hook scripts.

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| git 2.54+ | Config-based hooks (`[hook]` stanzas). Older git ignores them, so no global hook runs | `winget install Git.Git` |
| [delta](https://github.com/dandavison/delta) | Pager, diff viewer | `winget install dandavison.delta` / `cargo install git-delta` |
| [nvim](https://neovim.io) | Commit editor | see `nvim/` |
| pwsh 7+ | PowerShell hook variant; the JSON check and PowerShell lint in the work hooks | `winget install Microsoft.PowerShell` |
| PSScriptAnalyzer (optional) | PowerShell lint in the work `push-lint` hook | `Install-Module PSScriptAnalyzer -Scope CurrentUser` |
| bicep (optional) | Bicep lint in the work `push-lint` hook | `winget install Microsoft.Bicep` |

## Files

| File | Installed as | Notes |
|---|---|---|
| `gitconfig` | `~/.gitconfig` | Base config for all machines. Ends by including the untracked `~/.gitconfig.local` |
| `gitconfig-work` | `~/.gitconfig-work` | Work overrides; included per repo by the `[includeIf]` blocks in `~/.gitconfig.local`. Sets `work.aiReferenceScan = true` and adds the work-only hook stanzas. Ends by including the untracked `~/.gitconfig-work.local` |
| `gitignore` | `~/.gitignore` | Global ignore rules |
| `gitignore-work` | `~/.gitignore-work` | Global ignore rules for work repos. Replaces `gitignore` there via `core.excludesFile` in `gitconfig-work`. Adds .NET, Terraform, and Azure Functions build output, plus AI tooling files |
| `gitmessage` | `~/.gitmessage` | Commit message template |
| `gitattributes` | `~/.gitattributes` | Global attributes (`core.attributesfile`). Per-type whitespace rules for formats indented with tabs (Go, Makefiles, `.gitmodules`, TSV) |
| `templates/` | `~/.git_templates/` | Global hook scripts in `templates/hooks/`, run by the `[hook "dotfiles-<event>"]` stanzas in `gitconfig`. Work-only hook scripts in `templates/work-hooks/`, run by the `[hook "work-*"]` stanzas in `gitconfig-work` |

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
- **GitHub fetch over HTTPS, push over SSH**: `gh:owner/repo` fetches from `https://github.com/owner/repo`, and both `gh:` and `https://github.com/` push to `git@github.com:`. Fetch works on a machine without an SSH key or where port 22 is blocked. Git applies `insteadOf` and `pushInsteadOf` to the original URL, so `gh:` takes the same split. Check a remote with `git remote get-url origin` and `git remote get-url --push origin`

## Machine-local config (`~/.gitconfig.local`, `~/.gitconfig-work.local`)

This repo is public, so it never names the employer, its Azure DevOps organisation or
project, the work email, or the work root. Those values live in two untracked files in
your home folder:

- `~/.gitconfig.local` holds the `[work]` keys and the `[includeIf]` blocks that load
  `~/.gitconfig-work` in work repos.
- `~/.gitconfig-work.local` holds the work `[user]` email.

The include chain:

1. `gitconfig` includes `~/.gitconfig.local` last, so its values win over the base config.
2. The `[includeIf]` blocks in `~/.gitconfig.local` load `~/.gitconfig-work` for any repo
   with a work remote, and for repos under the work root.
3. `gitconfig-work` sets `work.aiReferenceScan = true`, then includes
   `~/.gitconfig-work.local` last. So the work email overrides the personal one only in
   work repos, and the AI-reference scan runs only there.

Git ignores a missing include file. Without `~/.gitconfig.local`, no repo gets the work
identity. The `hasconfig:remote.*.url` conditions need Git 2.36+.

The AI-reference hooks (`pre-commit` and `commit-msg` below, plus the Claude Code, Codex,
and Pi guards) read `work.aiReferenceScan`, which `gitconfig-work` sets. So they scan
exactly the repos that get the work identity, including a repo with no remote under the
work root. They fail open when the key is unset or false. The `rfc`, `agent-staging`, and
board-triage skills read the `[work]` keys in `~/.gitconfig.local`.
`tests/public-repo-hygiene.Tests.ps1` reads those four keys and checks that no tracked
file names their values.

Template for `~/.gitconfig.local` (replace every `<...>` placeholder):

```ini
# ~/.gitconfig.local (untracked; never commit)
[work]
    employer = <employer>
    adoOrgUrl = https://dev.azure.com/<org>
    adoProject = <project>
    root = <work-root>

# Work identity: load ~/.gitconfig-work for any repo with a work remote, and for
# local-only repos under the work root. hasconfig needs Git 2.36+.
[includeIf "hasconfig:remote.*.url:https://<org>@dev.azure.com/**"]
    path = ~/.gitconfig-work
[includeIf "hasconfig:remote.*.url:git@ssh.dev.azure.com:v3/<org>/**"]
    path = ~/.gitconfig-work
[includeIf "hasconfig:remote.*.url:https://dev.azure.com/<org>/**"]
    path = ~/.gitconfig-work
[includeIf "gitdir/i:<work-root>/"]
    path = ~/.gitconfig-work
```

Template for `~/.gitconfig-work.local`:

```ini
# ~/.gitconfig-work.local (untracked; never commit)
[user]
    email = <work-email>
```

Write `<work-root>` with forward slashes, in the `root` key and in the `gitdir/i`
condition. Git reads a backslash in a config value as an escape. A hand-written
`X:\Foo` makes the file invalid, and because `gitconfig` includes it, every git command
then fails. To set a key safely, use the command line, which escapes the value for you:

```sh
git config --file ~/.gitconfig.local work.root '<work-root>'
```

To check which identity a repo gets, run `git config --show-origin user.email`.

A work repo outside the work root with no remote yet matches no condition. Set its
email by hand:
```sh
git config user.email <work-email>
```

`git config --global` writes to `~/.gitconfig`. On Windows that file is the stub that
`setup.ps1` generates and overwrites. On Linux it is a symlink to the tracked
`gitconfig`. So write machine-local values to the local file instead:

```sh
git config --file ~/.gitconfig.local <key> <value>
```

### Commit signing

`gitconfig` sets `gpg.format = ssh`, so git signs with an SSH key. It does not turn
signing on. To sign on this machine, add this block to `~/.gitconfig.local`:

```ini
[user]
    signingkey = <path to your .pub key>
[gpg "ssh"]
    allowedSignersFile = ~/.ssh/allowed_signers
[commit]
    gpgsign = true
[tag]
    gpgsign = true
```

`~/.ssh/allowed_signers` lets git verify signatures locally, for example in
`git log --show-signature` and in tig. Add one line per identity, including the work
email:

```text
<email> <key-type> <key>
```

For example, `<email> ssh-ed25519 AAAA...`. Copy the key type and key from your `.pub`
file.

The forge must also know the key:

- GitHub: add the public key as a Signing Key. An Authentication Key is not enough.
- Codeberg and other Forgejo hosts: add the SSH key, then verify it.

### Other machine-local settings

These also belong in `~/.gitconfig.local`, because they differ per machine:

- A corporate proxy: `http.proxy`, `http.sslCAInfo`, or `http.sslBackend`.
- `core.sshCommand`, for a specific SSH client or key.
- `safe.directory`, for a drive or folder that another user owns.
- An override of `core.editor`, or extra `url.<base>.insteadOf` rules.

## Hooks (`templates/hooks/`)

The hook scripts are installed in `~/.git_templates/hooks/` (the folder name is
historical). They run as config-based hooks, which need Git 2.54 or later. `gitconfig`
has one stanza per script:

```ini
[hook "dotfiles-pre-commit"]
    event = pre-commit
    command = "f=\"$HOME/.git_templates/hooks/pre-commit\"; test -f \"$f\" || exit 0; exec \"$f\""
```

The config does not set `core.hooksPath`. A global `core.hooksPath` hides every repo's
own `.git/hooks`, and the pre-commit framework refuses to install while it is set. With
config-based hooks, the global hooks run first, then the repo's own hook for the same
event. Every repo gets the global hooks at once, with no `git init` needed.

Git runs the command through `sh` and adds the hook's arguments after it, so the script
gets its usual arguments and stdin. These parts of the value are load-bearing, and
`tests/git-config.Tests.ps1` pins them:

- The double quotes are required. `;` starts a comment in git config, so without them
  the value ends at the first `;` and the script never runs.
- `"$HOME/..."` is quoted, so a home folder with a space in its path works.
- `test -f "$f" || exit 0` makes the hook fail open while `~/.git_templates` is not
  installed. Git does not fail open on a missing command: it blocks the commit. The
  guard uses `-f` (exists) and not `-x` (executable), so a script that is present but
  broken still fails loudly.

To see which hooks run for an event, use `git hook list --show-scope pre-commit`.

#### Existing repos: remove old template copies

`init.templatedir` used to copy the hook scripts into each new repo's `.git/hooks`.
`core.hooksPath` hid those copies. Now they run after the global hooks, so a repo
created before this change runs gitleaks and ctags twice. In a work repo the old
`pre-commit` and `commit-msg` copies can block every commit: they look for the AI-term
wordlist relative to `.git/hooks`, which is the wrong place. The pre-commit framework
also keeps such a copy as `pre-commit.legacy` and runs it.

In each existing repo, delete the files in `.git/hooks` that match the names in
`templates/hooks/` (`ctags`, `commit-msg`, `post-*`, `pre-commit`,
`prepare-commit-msg*`). Keep any hook that the repo installed for itself.

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

### `pre-commit`

Two independent checks, gitleaks first:

- **Secret scan** — blocks a commit whose staged diff looks like a secret
  (`gitleaks git --pre-commit --redact --staged`). Fails open when `gitleaks` is
  not on `PATH` (warn, allow) so a machine without the binary is never blocked —
  the gitleaks CI job is the backstop. Bypass one commit: `SKIP_GITLEAKS=1 git commit ...`
- **AI-reference scan** — blocks a commit whose staged diff adds a line matching
  `ai-agents/_shared/banned-ai-terms.txt` (added lines only; a banned term on a
  removed line does not block). Scoped to work repos only — see
  `### commit-msg` below for the scoping rule and fail-open/closed behaviour,
  which this check shares. Bypass one commit: `SKIP_AI_REFERENCE_SCAN=1 git commit ...`

Both checks run in the same file, under the one `dotfiles-pre-commit` stanza.
Neither check has pwsh-native logic worth a `.ps1`/`.sh` split: both only shell
out to cross-platform binaries.

### `commit-msg`

Two independent checks: the commit-format check and the AI-reference scan. Each has
its own config key and its own bypass variable. Both run, so one commit reports every
problem. Git invokes `commit-msg <path-to-commit-msg-file>`, so the hook sees the final
message text regardless of `-m`, `-F`, an editor, `--amend`, or a merge.

#### Commit-format check

Blocks a commit whose subject does not match this format:

```text
<type>(<scope>)?!?: [#<work item id>] <description>
```

The type is one of `feat`, `fix`, `refactor`, `chore`, `docs`, `style`, `test`, `ci`,
`build`, `perf` or `revert`. For example, `feat(api): [#123] add the endpoint`. The
subject is the first line that is not a comment and not blank. Subjects that start with
`Merge `, `Revert "`, `Reapply "`, `fixup! `, `squash! ` or `amend! ` pass. When the
subject uses an old style (a leading `[#123]` prefix, `AB#123`, or a bare `#123`), the
error message says which one.

The check runs only when `git config --type=bool --get work.commitFormat` prints
`true`. No tracked file sets the key, so the check is off by default.
`prepare-commit-msg` writes the work item as a `Refs:` trailer at the end of the
message. The check needs `[#id]` in the subject, so with the check on, every commit that
`prepare-commit-msg` prepares is blocked until you edit the subject. To turn the check on
in every work repo, add the key to `~/.gitconfig-work.local`:

```ini
[work]
    commitFormat = true
```

To turn it on in one repo only:

```sh
git config work.commitFormat true
```

Bypass one commit: `SKIP_COMMIT_FORMAT=1 git commit ...`

#### AI-reference scan

Blocks a commit whose message matches `ai-agents/_shared/banned-ai-terms.txt` —
the hard-block layer for AI/Claude/Codex/Copilot/co-authorship references
(issue #219 layer 2), replacing a prompt-level rule that already failed once.

Scoped to work repos only. The scan runs when
`git config --type=bool --get work.aiReferenceScan` prints `true`. `gitconfig-work`
sets the key, so the `[includeIf]` blocks that apply the work identity also turn on
the scan. The remote does not matter. GitHub repos (dotfiles, wiki, brain)
legitimately say "Claude"/"Codex" in their own subject matter and are never scanned.
If the key is unset, false, or not a boolean, or this is not a repo, the commit is
allowed. To turn the scan off in one work repo:

```sh
git config work.aiReferenceScan false
```

Fails open on every other condition, and fails closed only when scoped-in AND
the wordlist itself is missing or unreadable. This follows the guard in the
`[hook "dotfiles-<event>"]` commands: fail-open covers "not installed yet", never
"installed but broken". A missing wordlist in a scoped-in repo is the latter.

Bypass one commit: `SKIP_AI_REFERENCE_SCAN=1 git commit ...`

### `post-commit`, `post-checkout`, `post-merge`, `post-rewrite`

Auto-regenerate ctags after relevant git operations. Reads `~/.ctags` for
tag configuration. Create a `.notags` file in any repo to disable.

### Ordering is additive — existing hooks still run

Configured hooks run **first** (system → global → local, in file order), then the
repo's own `.git/hooks` script runs **last**. Verify:

```console
$ git hook list pre-commit
dotfiles-pre-commit                 # <- gitleaks and the AI-reference scan
work-checks                         # <- only in work repos
hook from hookdir                   # <- only if the repo has its own pre-commit
```

`git hook list --show-scope pre-commit` adds where each came from (`global`,
`local`).

### Requires Git >= 2.54

```sh
git --version
```

Below 2.54 git **ignores every `[hook]` stanza silently**. There is no error, and
`git hook list` does not exist. No global hook runs: not gitleaks, not the
AI-reference scan, not the work hooks. `setup.ps1`/`setup.sh -Module git` check the
version and warn at install time. Verified on 2.56.1.windows.1. Debian bookworm ships
2.39.2, so WSL needs a newer git before any hook runs there.

**No config key enables parallel hooks.** `hook.<name>.parallel = true` is silently
ignored (unknown hook keys always are) — measured identical serial timing with and
without it on 2.55. Only `git hook run --jobs=N` runs same-event hooks
concurrently, and git does not use it on the commit path, so `git commit` is
serial regardless.

## Work hooks (`templates/work-hooks/`)

`gitconfig-work` runs these scripts as config-based hooks, so they run only in the repos
that load it: the repos that get the work identity. They are reached through the
`~/.git_templates` link, so setup adds no extra link. Each stanza uses the same guarded
command as the stanzas in `gitconfig`, so a hook fails open until `~/.git_templates` is
installed:

```ini
[hook "work-checks"]
    event = pre-commit
    command = "f=\"$HOME/.git_templates/work-hooks/checks\"; test -f \"$f\" || exit 0; exec \"$f\""
```

| Hook | Event | What it does | Bypass for one run |
|---|---|---|---|
| `checks` | pre-commit | Blocks a commit on a protected branch, merge conflict markers, CRLF in a `.sh` file, and a `.json` file that does not parse | `SKIP_PROTECTED_BRANCH=1`, `SKIP_CONFLICT_MARKERS=1`, `SKIP_SH_CRLF=1`, `SKIP_JSON_CHECK=1` |
| `push-warnings` | pre-push | Warns when the upstream of a pushed branch is gone, or when the branch is more than 20 commits behind the default branch. Never blocks | none |
| `push-lint` | pre-push | Blocks on PSScriptAnalyzer findings in the changed PowerShell files, and on `bicep lint` findings in the changed `.bicep` files | `SKIP_PUSH_LINT=1` |

`git commit --no-verify` and `git push --no-verify` skip every hook.

### `checks`

Runs every check, so one commit reports every problem:

- Protected branch: blocks a commit on `main`, `master` or `wikiMaster` (the default
  branch of an Azure DevOps code wiki). The list is fixed in the script. A detached
  HEAD, an unborn branch, and a repo with no remote pass.
- Conflict markers: blocks an added line that starts with `<<<<<<<` or `>>>>>>>`. A
  bare `=======` is a Markdown setext heading, so it never counts.
- CRLF in `.sh`: blocks a staged `.sh` file with a CR in its staged content. A CRLF
  copy in the working tree over an LF staged copy passes.
- JSON: every staged `.json` file must parse. `checks-json.ps1` does the parsing in one
  pwsh process. It accepts JSONC comments, trailing commas, a BOM, and keys that differ
  only by case. An empty file fails. When pwsh is not on `PATH`, the check warns and
  skips.

The CRLF and JSON checks read the staged content.

### `push-warnings` and `push-lint`

Both read the pushed refs from stdin and skip tags and branch deletes. They use the
local remote-tracking refs and do not fetch. The default branch is the branch that
`origin/HEAD` points at. If `origin/HEAD` is not set (for example, the remote was added
by hand), it is `origin/main`, then `origin/master`. To set `origin/HEAD`, run
`git remote set-head origin --auto`.

`push-lint` lints the files that changed between the merge base with the default
branch and the pushed commit. Without a default branch, every file in the commit
counts as changed. It reads the working tree copy of each file, so it skips a pushed
branch that is not checked out, with a warning. PowerShell files are linted with the
repo's own `.vscode/PSScriptAnalyzerSettings.psd1` or `PSScriptAnalyzerSettings.psd1`,
never with the default rules. The lint warns and skips when the repo has no settings
file, or when pwsh, the PSScriptAnalyzer module, or the `bicep` CLI is missing. An
error from PSScriptAnalyzer itself blocks the push. Any output from `bicep lint`,
warnings included, counts as a finding.

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
Installs `~/.gitattributes` from `gitattributes`. Junctions/symlinks `~/.git_templates`
→ `git/templates/`, then warns if git is older than 2.54.
