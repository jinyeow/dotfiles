# Keep in-repo brain precedence over the registry, add a shadow notice

## Status

Accepted.

## Context

The project-brain SessionStart hook resolves an in-repo `.claude/brain/` first. When an
ancestor of cwd has `.claude/brain/core.md`, the hook treats that as the brain and exits
before consulting the registry (`brains.json` + a brain repo's `registry.json`).

In the `650872-branch-policy-audit` worktree, a repo-local `.claude/brain/` existed. It hid
the registered `650874-ado-governance-scripting` initiative for at least one session, because
the hook never reached the registry lookup that would have found it. The session redid work
already recorded in the hidden initiative.

The repo-local brain winning was not the defect. The defect was silence: the session had no
way to learn that a second, registered initiative also matched the same directory.

## Decision

Keep in-repo precedence: when an ancestor of cwd has `.claude/brain/core.md`, that brain loads
and the registry is not consulted for context injection.

Add a shadow notice. When an in-repo brain wins, the hook also checks the registry for an
initiative whose `dirs` glob matches the same cwd. If one matches, the hook prints a line
naming it:

`[project-brain] A registered initiative also matches this directory and was NOT loaded: <id> ...`

The `resolve-and-read` procedure in tools with no hook (Codex) follows the same rule by hand:
when the in-repo brain wins, still check the registry for a second match and say so.

Do not load both brains. Do not flip precedence.

## Alternatives considered

- **Load both brains.** Doubles injected context for every session in any repo that has a
  repo-local brain, for the rare case where a registered initiative also matches. Rejected.
- **Flip precedence so the registry wins.** Breaks self-contained, single-repo brains, which
  is the reason in-repo precedence was chosen in the first place. Rejected.
- **Drop the in-repo walk entirely.** Same breakage as flipping precedence: a single-repo
  initiative would lose its self-contained brain. Rejected.
