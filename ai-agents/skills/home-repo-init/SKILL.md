---
name: home-repo-init
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
  the recommendations.
- The Home Repo never names the repo that installs the global rules and skills. Name the
  runtime folders (Claude, Codex, shared agent skills, Pi) when you refer to global material.
  This applies to every file you write there: `AGENTS.md`, wiki pages, commit messages and
  brain entries.

## Step 1. Inventory the repos

1. Read `~/.claude/project-brain/brains.json`. List each `scope`.
2. Find every git repo under each scope, then under the home folder. Skip dependency and build
   folders: `node_modules`, `.venv`, `venv`, `vendor`, `target`, `bin`, `obj`, `.terraform`,
   `.git`. A bare-worktree layout counts as one repo: list the `.bare` folder once and its
   worktrees under it.
3. For each repo, record the path, the `origin` remote (`git remote get-url origin`, or "none"),
   the default branch, and a one-line hint from its README or `AGENTS.md`.
4. Ask round 1:
   1. Which repos the Home Repo points at. Recommend all repos under the scope.
   2. The workspace scope: the common ancestor of those repos. Recommend the longest common
      ancestor.
   3. Whether to adopt an existing brain, wiki or `work/` notes folder. Recommend adopting
      each one you found.
   4. The default tracker (for example Azure Boards or GitHub Issues). Recommend the tracker
      of the most common remote host.

Completion criterion: the repo table has one row per repo found in every scope and in home, and
the user has answered all four questions of round 1.

## Step 2. Inventory the shared material

Collect every rule, skill, wiki page, template and notes folder that applies to more than one
repo. Put each item in exactly one bucket:

- installed: the item lives in a runtime folder: `~/.claude/`, `~/.codex/`, `~/.agents/` or
  `~/.pi/agent/`. Leave it in place. Never move or delete it.
- shared: the item exists once, outside the runtime folders, and applies to the whole
  workspace. It moves into the Home Repo.
- duplicate: the same item exists in more than one repo. Keep one copy in the Home Repo and
  list the other copies for removal.
- repo-specific: the item applies to one repo only. It stays in that repo.

Treat symlinks and junctions into a runtime folder as installed. Compare duplicates by content
hash.

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
   `AGENTS.md`), `repos/`, `wiki/`, `skills/` and `brain/`. State each of these:
   - whether `gateroom` is created or an existing repo is renamed;
   - which wiki enters through `git subtree add`;
   - which brain moves into `brain/` through `git mv`;
   - which `work/` items become initiatives;
   - the `brains.json` entry to add;
   - the child repos that lose a moved copy, and the new local branch name for each.

Ask for approval. If the user changes the plan, show the changed plan again.

Completion criterion: the user has approved the item table, the `AGENTS.md` draft and the
layout in this session. The approval is a reply that names the plan. Treat silence as no approval.

## Step 4. Apply

Run these actions in order. Stop at the first failure and report it. Do not skip an action.

1. Create or rename the Home Repo. For a new repo, run `git init <scope>/gateroom`, then make
   an empty first commit with `git -C <scope>/gateroom commit --allow-empty -m "chore:
   initialize Home Repo"`. `git subtree add` needs a commit to attach to. For an existing brain
   repo, rename its folder to `gateroom` and keep its history.
2. If you adopt an existing brain repo, move its contents into `brain/` with `git mv`, so each
   move shows as a rename and the history stays. First check that `git status --porcelain` prints
   nothing, so the commit holds only the move. Commit the move. `git subtree add` needs a
   clean working tree.
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
   move later.
5. Migrate each `work/` item. Create `brain/initiatives/<item>-<slug>/` from the brain
   `templates/` (`core.md`, `STATUS.md`, `log.md`). Move the item's notes into it. Add a
   `registry.json` entry. Follow "New initiative" in the `project-brain` skill. Retire the
   `work/` folder when it is empty.
6. Write `AGENTS.md`, `CLAUDE.md`, and any `repos/<area>.md` files from the approved draft.
7. Set the `brains.json` entry `{ "scope": "<scope>", "path": "<scope>/gateroom/brain" }`. If
   the file does not exist, create it as `{ "version": 1, "brains": [] }` first. When you adopt
   a brain, first remove any existing entry for the same scope or the old brain path. The file
   then holds one entry for the scope.
8. In each child repo that held a moved or duplicate copy, make the change on a new branch
   `chore/home-repo-<slug>`: remove the copy with `git rm`, and commit. In a normal clone, run
   `git switch -c chore/home-repo-<slug>` first. In a bare-worktree child repo, run `git
   worktree add ../chore-home-repo-<slug> -b chore/home-repo-<slug>` and do the `git rm` in that
   new worktree. Never switch the worktree of the default branch.
9. In the Home Repo, run `git add -A` and commit with a conventional message. Do not push.

Completion criterion, checked with these commands:
- `git -C <scope>/gateroom status --short` prints nothing;
- `git -C <scope>/gateroom log --oneline -1` shows the new commit;
- `<scope>/gateroom/brain` holds `index.md`, `log.md`, `registry.json`, `templates/` and `adr/`;
- `rg -n "<name of the installer repo>" <scope>/gateroom` finds nothing, where the name is the
  repo that installs the global rules and skills;
- each child repo that changed is on its new local branch and its working tree is clean;
- `brains.json` parses and holds one entry for the scope.

Report the commit SHAs, the branch names, and the actions that you skipped, with the reason for
each. State that nothing was pushed.
