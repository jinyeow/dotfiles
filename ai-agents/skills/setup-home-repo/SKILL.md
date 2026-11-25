---
name: setup-home-repo
description: Set up or adopt a Home Repo (`gateroom`) for a workspace on any machine, in four steps with an approval gate before any change.
disable-model-invocation: true
---

Set up a workspace Home Repo, or adopt an existing brain, wiki and notes folder into one. The
Home Repo layout, the brain and the `brains.json` schema are defined by the `project-brain`
skill. Read its "Home Repo layout" and "Scaffolding" sections before step 3.

Rules for the whole run:

- Read-only until the user approves the plan in step 3. Run no write command before then.
- Never read secret files: `.env*`, key files, credential or token stores, `*.pfx`, and the
  contents of any `secrets` folder. List their paths only.
- Never push. Never run `git push`, `git subtree push` or `gh pr create`.
- Ask in numbered rounds. Give a recommended answer for each question. A reply of "yes" accepts
  the recommendations. Do not start the next step until the user has answered the round.
- Refer to global rules and skills by runtime folder (Claude, Codex, shared agent skills, Pi).
  Never use a path into the source repo that installs them. This applies to every instruction
  file you write in the Home Repo: `AGENTS.md`, `CLAUDE.md`, `repos/`, `skills/` and wiki pages.
  The Home Repo can still list the source repo as a workspace repo, and the brain can hold an
  initiative about it.

## Step 1. Inventory the repos

1. Ask round 0: which workspace scope this run is for. Read
   `~/.claude/project-brain/brains.json`. Recommend the listed `scope` that contains the current
   folder. If no listed scope contains it, recommend the current folder as a new scope. Inventory
   only the chosen scope and the home folder. List the other scopes as out of scope.
2. Find every git repo under the scope, then under the home folder. Skip these folders:
   - dependency and build folders: `node_modules`, `.venv`, `venv`, `vendor`, `target`, `bin`,
     `obj`, `.terraform`, `.git`;
   - the runtime folders `~/.claude/`, `~/.codex/`, `~/.agents/` and `~/.pi/agent/`;
   - `AppData` and tool cache folders, for example `.cache`, `.npm`, `.nuget` and `go/pkg/mod`.
3. A bare-worktree layout counts as one repo. List the `.bare` folder once and its worktrees
   under it. Read the hint from one worktree, the one on the default branch if it exists.
4. For each repo, record the path, the `origin` remote (`git remote get-url origin`, or "none"),
   the default branch, and a one-line hint from its README or `AGENTS.md`. The default branch is
   `origin/HEAD`. If `origin/HEAD` is not set, record the current branch and mark it unconfirmed.
5. Mark each repo that looks like a backup or stale clone, for example a name that ends in
   `.backup-*`, `.old` or `-backups`.
6. Ask round 1:
   1. Which repos the Home Repo points at. Recommend all repos under the scope, except the
      marked backup and stale clones.
   2. Whether to adopt an existing brain, wiki or `work/` notes folder. Recommend a brain or a
      `work/` folder that you found. Recommend a wiki only when it holds standards and
      conventions for this workspace. A general notes or documentation wiki stays outside.
   3. The default tracker (for example Azure Boards or GitHub Issues). Recommend the tracker
      of the most common remote host.

Completion criterion: the user has chosen the scope in round 0, the repo table has one row per
repo found in the scope and in home, and the user has answered all three questions of round 1.

## Step 2. Inventory the shared material

Collect every rule, skill, wiki page, template, config file and notes folder that applies to
more than one repo, plus each file or folder in the scope that is outside a git repo. An item is
one file, or one skill or notes folder. A runtime folder counts as one item.

Put each item in exactly one bucket:

- installed: the item lives in a runtime folder: `~/.claude/`, `~/.codex/`, `~/.agents/` or
  `~/.pi/agent/`. Leave it in place. Never move or delete it.
- shared: the item exists once, outside the runtime folders, and applies to the whole
  workspace. It moves into the Home Repo. Exception: an item that a tool reads at the scope
  root stays there with the action `keep`. Examples are the scope-root `.claude/` folder and an
  `agent-staging/` folder.
- duplicate: the same item exists in more than one repo. Keep one copy in the Home Repo and
  list the other copies for removal.
- repo-specific: the item applies to one repo only. It stays in that repo. A config file that a
  tool reads from the repo root (`.editorconfig`, `bicepconfig.json`, `ps-rule.yaml`) is
  repo-specific, even when the copies in two repos are the same.

Treat symlinks and junctions into a runtime folder as installed. Compare duplicates by content
hash. Hash one worktree per bare-worktree repo, so that the worktrees of one repo do not show
as duplicates.

List each `.claude/handoff.md` that you find. Put each one in the report as a follow-up for the
user.

Completion criterion: every item found is in exactly one bucket, and the item count of the four
buckets equals the number of items found.

## Step 3. Agree the plan

Show the plan as three parts, then ask for approval.

1. The item table. One row per item: source path, bucket, action (`keep`, `git mv`, `git
   subtree add`, `migrate`, `remove copy`), target path.
2. The draft `AGENTS.md` for the Home Repo. It has these parts:
   - an intro that names the workspace;
   - a Work tracking section with the default tracker;
   - Other Repos: one line per repo with its path, remote and hint. A repo with its own tracker
     gets a hint that points at its workflow config. Move the lines to `repos/<area>.md` files
     when the workspace has more than about 20 repos;
   - a rule that forbids `.claude/handoff.md`, with the brain session close-out as the
     handover;
   - a line that says global rules and skills load from the runtime folders.
3. The layout, as a tree: `gateroom/` with `AGENTS.md`, `CLAUDE.md` (one-line pointer to
   `AGENTS.md`), `wiki/`, `skills/` and `brain/`, plus `repos/` when the workspace has more
   than about 20 repos. State each of these:
   - whether `gateroom` is created or an existing repo is renamed;
   - which wiki enters through `git subtree add`, from which path and branch. For a
     bare-worktree wiki, use a worktree path and the `origin/HEAD` branch. Ask when the branch
     is not clear. With no wiki, `wiki/` starts empty;
   - which brain moves into `brain/` through `git mv`, and the changes that bring it to the
     current brain format (see step 4.2);
   - which `work/` items become initiatives;
   - the `brains.json` entry to add;
   - the child repos that lose a moved copy or hold the old brain path, and the new local branch
     name for each.

Ask for approval. If the user changes the plan, show the changed plan again.

Completion criterion: the user has approved the item table, the `AGENTS.md` draft and the
layout in this session. The approval is a reply that names the plan. Treat silence as no approval.

## Step 4. Apply

Run these actions in order. Stop at the first failure and report it. Do not skip an action.

1. Create or rename the Home Repo. For a new repo, run `git init <scope>/gateroom`, then make
   an empty first commit with `git -C <scope>/gateroom commit --allow-empty -m "chore:
   initialize Home Repo"`. `git subtree add` needs a commit to attach to. For an existing brain
   repo, rename its folder to `gateroom` and keep its history. On Windows the rename fails while
   a shell or editor has its working folder inside the brain. Ask the user to close them first.
2. If you adopt an existing brain repo:
   1. Check that `git status --porcelain` prints nothing. If it prints files, stop and list them.
      The user decides whether to commit or discard them.
   2. Move every path that `git ls-tree --name-only HEAD` lists into `brain/` with `git mv`, so
      each move shows as a rename and the history stays. The list includes hidden files such as
      `.gitignore`. Commit the move. `git subtree add` needs a clean working tree.
   3. Bring the brain to the current format and commit: add an empty `## Archived` section to
      `index.md` if it has none, and copy the `templates/` folder of the `project-brain` skill
      over `brain/templates/`. Ask the user before you add initiative-folder globs to
      `registry.json`.
3. If you adopt no brain, scaffold `brain/` and commit it:
   - `index.md` with `okf_version: "0.2"` in its front matter, an empty active initiatives
     table, and an empty `## Archived` section with the columns `| Initiative | Title | Closed |`;
   - `log.md`;
   - `registry.json` with the content `{ "initiatives": {} }`;
   - `templates/`, a copy of the `templates/` folder of the `project-brain` skill (`core.md`,
     `STATUS.md`, `adr.md`, `log.md`);
   - `adr/`, with an empty `.gitkeep` file so git keeps the folder.
4. Add each wiki with `git subtree add --prefix=wiki <wiki-repo-path> <branch>`. Do not pass
   `--squash`: the full wiki history stays. `git subtree split --prefix=wiki` reverses the
   move later. With no wiki, create `wiki/.gitkeep`.
5. Migrate each `work/` item. Create `brain/initiatives/<item>-<slug>/` from the brain
   `templates/` (`core.md`, `STATUS.md`, `log.md`). Move the item's notes into it. Add a
   `registry.json` entry. Follow "New initiative" in the `project-brain` skill. Retire the
   `work/` folder when it is empty.
6. Write `AGENTS.md`, `CLAUDE.md`, and any `repos/<area>.md` files from the approved draft.
   Create `skills/.gitkeep`.
7. Set the `brains.json` entry `{ "scope": "<scope>", "path": "<scope>/gateroom/brain" }`. If
   the file does not exist, create it as `{ "version": 1, "brains": [] }` first. When you adopt
   a brain, first remove any existing entry for the same scope or the old brain path. The file
   then holds one entry for the scope.
8. When you renamed or moved a brain, search the brain and the child repos for its old path with
   `rg -n -F "<old brain path>"`. Fix each hit in the brain now. Fix each hit in a child repo in
   step 9.
9. In each child repo that held a moved or duplicate copy or the old brain path, make the change
   in a new worktree on a new branch `chore/home-repo-<slug>`. Never switch an existing checkout
   or worktree. In a bare-worktree child repo, run `git worktree add ../chore-home-repo-<slug> -b
   chore/home-repo-<slug>` from a worktree of that repo. In a normal clone, run `git -C <repo>
   worktree add ../<repo>-chore-home-repo-<slug> -b chore/home-repo-<slug>`, so the folder sits
   next to the clone. Remove the copy with `git rm` or fix the path, then commit in the new
   worktree with a conventional message, for example `docs: update project brain path after
   the Home Repo move`. After the branch merges, remove the worktree with `git worktree remove`.
   The new worktree can sit outside the initiative's registry globs, so the initiative may not
   load there on its own. Say so in the report.
10. In the Home Repo, run `git add -A` and commit with a conventional message. Do not push.

Completion criterion, checked with these commands:
- `git -C <scope>/gateroom status --short` prints nothing;
- `git -C <scope>/gateroom log --oneline -1` shows the new commit;
- `<scope>/gateroom/brain` holds `index.md`, `log.md`, `registry.json`, `templates/` and `adr/`;
- no instruction file in the Home Repo (`AGENTS.md`, `CLAUDE.md`, `repos/`, `skills/`, `wiki/`)
  uses a path into the source repo that installs the global rules and skills. Read each path
  in those files and list any that fail;
- `rg -n -F "<old brain path>"` over the brain and the changed child worktrees finds nothing;
- each child repo that changed has a new worktree on its `chore/home-repo-<slug>` branch, the
  worktree is clean, and the original checkout is on its old branch;
- `brains.json` parses and holds one entry for the scope;
- if the brain has at least one initiative, the `project-brain` SessionStart hook, run from a
  folder that the initiative's registry entry covers, loads it from `<scope>/gateroom/brain`.

Report the commit SHAs, the branch names, the `.claude/handoff.md` files found, and the actions
that you skipped, with the reason for each. State that nothing was pushed.
