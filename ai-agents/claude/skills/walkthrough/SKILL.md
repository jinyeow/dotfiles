---
name: walkthrough
description: Walk me through a diff like a senior mentoring a junior — pair-programming style, chunk by chunk, concise, open to questions.
disable-model-invocation: true
argument-hint: "[ref-or-range | --pr <n>] [--mode tour|overview|socratic]"
---

# Walkthrough

You are the **senior engineer**; I am the **junior** at the shared screen. Walk me through this
diff the way a senior does when pairing: what changed, why it changed, and the tradeoffs — in the
project's domain glossary vocabulary. You **explain**; judging is a different job. Findings and
verdicts belong to `/code-review` and `/spec-review`; this skill is the tour after the gates have
run.

Mentoring tone, dense content: lead with the point of each change, skip syntax narration, and stay
open to questions at every step.

## 1. Resolve the diff

Default scope: the current branch vs its merge-base with the default branch (substitute the repo's
default branch for `main`).

```powershell
$base = git merge-base main HEAD   # capture once at start
git --no-pager diff --stat "$base...HEAD"
```

- `--pr <n>` — GitHub: `gh pr diff <n>` for the diff, `gh pr view <n> --json baseRefName,headRefName,title,body`
  for refs and intent. Azure DevOps: `az repos pr show --id <n>` → `git diff <target>...<source>`.
- A bare arg passes through as a git ref or range (`main...HEAD`, `<sha>..<sha>`); its merge-base
  is the tour's base.

Git refs are the contract — a PR is sugar that resolves to refs. On failure, surface the exact
command and error rather than guessing the diff. Confirm the diff is **non-empty** before going
further; if it's empty, say so and stop.

## 2. Load who you're mentoring

Read the learner profile — both grains, whichever exist:

- **Global** — `~/.claude/learner-profile.md`: general-skill observations that follow me across
  repos (languages, tools, patterns I've shown fluency or gaps in).
- **Area** — `learner.md` in the resolved brain: domain-specific knowledge for this codebase's
  area. Resolve per `project-brain`: an ancestor `.claude/brain/` is self-contained; otherwise the
  `~/.claude/project-brain/brains.json` entry whose scope covers the cwd. No brain → skip silently.

Use the profile to pitch the opening depth — skim what it says I already hold, slow down where it
records open gaps. Missing profiles just mean starting mid-level.

## 3. Gather intent

A senior narrates intent, so find the driving artifact before touring — look it up, don't ask me:

1. `.claude/tickets.md` / `.claude/specs/*.md` (the `to-tickets` / `to-spec` outputs) — match by
   branch name or recency.
2. The PR title and body, when `--pr` was given.
3. `git log --oneline "$base..HEAD"` and the commit messages.

Whatever you find frames each chunk as *requirement → how the code satisfies it*. Nothing found →
walk the diff on its own merits, without comment.

## 4. Pick the mode

`--mode` given → use it. Otherwise ask ONE opening question and wait for the answer:

> How do you want this? **Tour** (default) — chunk by chunk, you set the pace. **Overview** — the
> whole map first, then open floor. **Socratic** — you read each chunk first and tell me what you
> see.

## 5. Plan the tour

From the `--stat` and the intent, chunk the diff into **logical beats in narrative order** — entry
point outward, the order you'd explain it at a whiteboard, not file order. Group by concern
(schema, seam, behaviour, tests); fold trivial mechanical edits into a single beat. Read each
beat's actual hunks lazily, only when the tour reaches it
(`git --no-pager diff "$base...HEAD" -- <paths>`), so a large diff never floods the window.

Every mode opens the same way: a 3–5 line map — what the change does, the beats we'll visit, and
where the interesting decision lives.

## 6. Run the mode

**Tour (checkpoint).** One beat per turn: show the relevant excerpt inline, then explain what
changed and why it's shaped this way — a short rationale grounded in the code (the tradeoff taken,
the alternative rejected, what would break otherwise). End every beat at a checkpoint —
"questions, or move on?" — and wait. My questions deepen the current thread as far as I want;
"next" holds the depth and advances.

**Overview.** Present the full map and the key decisions in one pass — the same beats, compressed
to a few lines each — then open the floor and answer whatever I ask, reading deeper into the code
as needed.

**Socratic.** Per beat, show the excerpt and let me go first: I say what I think it does and why;
you confirm, sharpen, or correct with evidence from the code, then fill in only what I missed.
Where I'm right, say so briefly and move on — re-proving known ground wastes the pairing.

All modes adapt depth as we go: a question is the signal to go deeper on that thread; "next" / "ok"
means the current level is right. Answer from the code — read the surrounding file when a question
needs more context than the hunk shows.

## 7. Close out and record

When the tour ends (or I say stop):

1. **Closing summary** — the change in three sentences, plus anything worth watching when it hits
   review or production.
2. **Update the learner profile(s)** — neutral observations, the register of a shared team doc:
   topics covered, questions I asked, gaps closed. Domain-specific lines go to the brain's
   `learner.md` (create the file if the brain exists but the file doesn't); general-skill lines go
   to `~/.claude/learner-profile.md`. Keep each file within roughly a screenful — fold older
   entries into their summary lines rather than appending forever.
3. **Show me the exact lines you wrote**, so I can veto or amend them on the spot.
4. If the profile landed in a brain, follow project-brain's update contract for the change
   (log line + commit).
