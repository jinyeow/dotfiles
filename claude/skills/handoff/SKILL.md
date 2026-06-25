---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it to `.claude/handoff.md` in the current workspace (create the `.claude/` directory if it does not exist), so it persists across reboots and the next session can find it by convention.

Keep the handoff out of version control so it is never committed into the workspace's repo. If the workspace is a git repo (`git rev-parse --is-inside-work-tree` succeeds) and `git check-ignore -q .claude/handoff.md` reports it is *not* already ignored, append a line `/.claude/handoff*.md` to the local exclude file at the path returned by `git rev-parse --git-path info/exclude` (creating it if absent). This is worktree-safe, never committed, idempotent, and the glob also covers the `handoff-<timestamp>.consumed.md` archives the SessionStart hook leaves behind. Skip this step silently when not inside a git repo.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
