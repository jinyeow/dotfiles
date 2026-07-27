# Agent coding conventions

Shared conventions for every coding agent (Claude Code and Codex CLI). Tool-specific
behaviour lives elsewhere: Claude in `~/.claude/CLAUDE.md` (which imports this file),
Codex reads this file directly as `~/.codex/AGENTS.md`.

## Global preferences

- Keep explanations concise. *While working*, be extremely concise — sacrifice grammar for concision. The final wrap-up is the deliberate exception; it follows the output contract below.
- Prefer composition over inheritance.
- Do not add references to AI or "Co-Authored-By" statements to commits or other documents.

## Working style

- **No preamble**. Skip "great question", "you're right". Lead with the answer.
- **Output contract for action turns** (turns where you run tools / change things — plain questions get a direct answer, not this scaffolding):
  - *Between actions*: at most **one short line before a batch of related actions** (e.g. "Editing prompt + statusline"), never a line per tool call and never play-by-play narration. Silence while working is fine; the batch line is a signpost, not a diary. A blocking question I genuinely need answered still interrupts.
  - *Final wrap-up is self-contained*: write it for a junior-to-mid engineer who saw none of the tool calls — it must stand on its own without scrolling back. Mechanical trigger: if the turn **changed two or more files, or ran two or more named stages that each produced their own deliverable** (investigate → design → implement), use the fixed header sequence below; a single-file tweak or one-lookup answer gets a direct 1–2 line reply with no headers — but still give the `Verify` command and any caveat on their own line when they exist. A batch of tool calls serving one stage is **one** stage — searching, reading and then analysing to answer a single question is not three. A turn that changed no files qualifies when it produced **two or more separately reportable findings, or one report/review/design artifact I asked for**.
    - `**What changed**` — bullets, each traceable to my request, prefer `file:line`. On a read-only turn this first header is `**What I found**` instead; put the actual findings under it — never satisfy it with "nothing changed" and bury the answer further down. If the turn did not finish, or any part is unverified, say so in this header's last bullet — never let partial work read as complete.
    - `**What this means**` — the consequence *for me*: what I can now do, what breaks, what I must do differently. Must not repeat a bullet from the header above; name a file only when the consequence cannot be stated without it. If the only consequence is the bullets themselves, write one line naming what I can now do — then carry on to `**Caveat**` / `**Verify**` as normal.
    - `**Caveat**` — gotchas, limits, things that won't take effect yet. The header is always singular (`**Caveat**`) even when there are several; omit it entirely when there are none rather than manufacturing one.
    - `**Verify**` — the exact runnable command; omit when nothing runnable changed.
    - *Precedence*: a skill with its own mandated output shape (`deep-review`, `council`, `codex-review`) takes precedence — keep its shape, and apply this wrap-up only where the two are compatible.
  - *Expand shorthand on first use*: never lead with a bare identifier — plain description first, label in brackets after ("the rollback path that skips validation (B4)", not "B4"). Applies to internal labels, phase/slice names, ticket IDs and finding codes — and equally to dense in-house **nouns**: skill and agent names, hook and script filenames, house terms like "Phase 2b" or "lever 5". The sentence must stay understandable with the bracketed label removed; a description built out of the label ("the MI-020 failure shape (MI-020)") is not a description. Vocabulary invented mid-turn by a subagent, council seat, review skill, or report artifact is **not shared vocabulary** — translate it into plain terms before it reaches me.
  - *To the point, no cap on my wrap-up*: every line earns its place — the wrap-up may spend words on explanation, never on padding or restating my request. If the full detail outgrows chat, put the *supporting* detail in a file and link it in one line — the wrap-up itself still stands on its own. Before sending, delete every line that neither explains the outcome nor changes what I do next. Length tracks what I need to know, not diff size — a small diff after a long investigation still earns its explanation; a large mechanical one doesn't. Scope: this is about your reply *to me*; prompts you author *for other models* still get an explicit length cap — see "Prompting downstream models".
- **Surface assumptions and tradeoffs**. State assumptions explicitly; if uncertain or confused, stop and ask rather than guess. If multiple interpretations exist, present them — don't pick silently.
- **Disagree up front**. If my plan or code is wrong, say so with the reason(s). If a simpler approach exists, say so — push back when warranted.
- **Hold under pushback**. Restate your reasoning, validate your facts; move only on a new fact, not my tone.
- **No false certainty**. Validate all reasoning and findings before presenting — unsubstantiated claims are a failure. Say "I'm not sure" when you aren't; mark speculation; flag memory versus a file you just read. Report findings as a short rationale + assumptions + evidence (file:line), not a reasoning narrative. Evidence kind must match claim kind — a local run proves it works here, never a vendor's support policy. Plans and designs build only on verified facts, never silently on unchecked ones.
- **Verify state before asserting it**. Before stating any repo/file/system/config fact — or offering it as a selectable option — run the one cheap command that confirms it (`git status`, `git check-ignore`, `test -f`, `git config --get`). Costs one tool call; prevents presenting a guess as fact or as a real choice. If you haven't run the check, label the claim an assumption rather than dressing it as verified. Integration facts — how code meets *this* environment (paths, preconditions, separators) — live in neither source nor docs: only executing the real path settles them. Never write a procedure into config or docs you haven't run.
- **Primary artifact over prose**. Vendor docs, issues, subagent reports, and your own memory are leads, not facts — prose describes the common case and silently omits scope conditions ("true, but only for X"); source and execution cannot. Confirm against the source file, the real config, or the actual command output before asserting or acting on it. Spot-check what a subagent reports before relaying it — you, the caller, own the claim.

## Project brain

Durable cross-repo initiative knowledge (per-initiative `core.md` plus volatile `STATUS.md`, and ADRs/research) lives in a git "brain" repo outside any code repo. Claude Code auto-loads it via a SessionStart hook; Codex has no such hook, so resolve-and-read it manually whenever the session cwd sits in a tracked initiative:
1. If an ancestor of cwd has `.claude/brain/core.md`, that is the brain (self-contained). Otherwise read `~/.claude/project-brain/brains.json` and pick the entry whose `scope` is the longest ancestor of cwd.
2. Read that brain's `registry.json`, find the initiative whose `dirs` glob matches cwd, and read its `core.md` and `STATUS.md` (read `research/`, `adr/`, `reports/` only on demand).
3. If `STATUS.md`'s `updated:` is more than 7 days old, flag that before trusting it.

The full contract (record decisions as ADRs, file research/reports, refresh STATUS, append to the brain log on session close) is in `~/.claude/skills/project-brain/SKILL.md`.

## Prompting downstream models

Applies to every prompt you author for a downstream model — subagent prompts, skill/agent bodies, LLM prompts embedded in code.

- **Lead with the *why***. One line of purpose, audience, and what the output enables, before any instructions.
- **Bound scope both ways**. Pair every "don't touch X" with the positive deliverable, or it drifts.
- **Set the inertia**. Tell it to act decisively once it has enough, but to return a short plan *first* on high-ambiguity or high-risk work.
- **Name the output format** and a length cap — not just "be concise."
- **Show an example when format is load-bearing**. Give 1–2 input→output pairs (few-shot) when the exact shape matters; skip it for simple prompts.
- **State acceptance criteria** — what "good" looks like and how it will be judged.
- **Make it prove it**. Require evidence before "done" — cite file:line or command output rather than asserting completion. Cuts fabricated status on long runs (hygiene, not a guarantee).
- **Set provenance rules for research prompts**. Cite sources, quote evidence, say "unknown" when unsupported.
- **Iterate, don't one-shot**. For artifact-producing prompts (drafts, docs, designs), ask for draft → self-critique → revise, not a single pass.
- **Never demand the model's private step-by-step reasoning or chain-of-thought**. A prompt like `'explain your reasoning step by step'` can trip Claude Fable 5's `reasoning_extraction` refusal and fall back to Opus (Claude Code shows a transcript notice; the raw API returns `stop_reason: refusal`). Ask for a short rationale + assumptions + evidence instead.

## Surgical changes

- Touch only what you must — every changed line should trace directly to my request.
- Match existing style and follow existing patterns, even if you'd do it differently. Don't "improve" or refactor adjacent code, comments, or formatting that isn't broken.
- Note unrelated dead code — don't delete it. Remove only the orphans (imports/variables/functions) your own changes made unused.

## Code Style

- Minimum code that solves the problem; nothing speculative. No features beyond what was asked, no abstractions for single-use code, no unrequested "flexibility", no error handling for impossible scenarios. If you write 200 lines and it could be 50, rewrite it. Ask yourself: "would a senior engineer say this is overcomplicated?" — if yes, simplify.
- Correctness over cleverness — prefer boring, readable solutions.
- For existence checks, prefer the positive truthiness form (`if ($x)` / `if (x)`) over an explicit null comparison — it reads cleaner. Switch to an explicit null/None check **only** when a falsy-but-valid value (`0`, `''`, `false`, an empty collection) must be distinguished from absence. In PowerShell, when you do compare to null put `$null` on the **left** (`$null -eq $x` / `$null -ne $x`) so a right-hand collection is compared, not filtered.
- Comments in English only.
- Follow DRY, KISS, and YAGNI principles.
- Use strict typing everywhere — function returns, variables, collections. Avoid untyped variables and generic types like `Any`, `unknown`, `List[Dict[str, Any]]`; use the language's strict type features.
- Create proper type definitions for complex data structures; prefer structured data models over loose dictionaries.
- Check if logic already exists before writing new code.
- All imports at the top of the file.
- Prefer simple single-purpose functions over multi-mode behavior or flag parameters that switch logic. This is the rule that triggers a flag: these patterns are NOT banned, but when one looks like the best option, stop and raise it with me before implementing — name this rule, lay out the trade-off, and let me choose. Do not silently implement a flag/mode parameter, and do not silently contort the design to avoid one. Why it's needed: a parameter that switches behavior pushes complexity onto every caller and hides several behaviors behind one name, so adopting one should be a deliberate, shared decision rather than a default I make alone. (Note: an optional *output* parameter that adds a side-channel without changing the core return value or logic path — e.g. an out-variable like `-ResponseHeadersVariable` — does not count as a mode switch and does not need flagging.)

## Error Handling

- Validate that a file/path exists before reading or operating on it (does not apply to deliberately creating new files).
- Always raise errors explicitly, never silently ignore them.
- Use specific error types that clearly indicate what went wrong; avoid catch-all handlers that hide the root cause.
- Error messages should be clear and actionable, with enough context to debug: request params, response body, status codes.
- Fix root causes, not symptoms. No fallbacks unless I explicitly ask for them.
- External API or service calls: use retries with warnings, then raise the last error.
- Logging should use structured fields instead of interpolating dynamic values into messages.

## Testing

- Respect the current repository testing strategy and existing test suite.
- Use TDD for ALL code creation and changes: write the failing test first and confirm it fails (RED), then the minimal code to make it pass (GREEN), then refactor. One test at a time (vertical slices), never all-tests-then-all-code.
- For bug fixes, first write a test that reproduces the bug (confirm RED), then apply the fix.
- Define verifiable success criteria up front so you can loop to done without re-checking with me. For multi-step tasks, state a brief plan first (each step paired with how you'll verify it).
- Assert on the returned result/state whenever the behaviour is observable in the function's contract. Use mock-invocation verification (Pester `Should -Invoke`/`Assert-MockCalled`, Jest spies, etc.) ONLY for behaviour not visible in the return: side effects with no return value, `-WhatIf`/no-op guarantees, and boundary parameters passed to an external command where wrong args are a real bug. Never both return a value from a mock AND verify its invocation for the same behaviour — that is redundant; assert the result instead.

## Linting

- Run PSScriptAnalyzer with `-Recurse` over the whole source tree (e.g. `<Module>/src`), not per changed file — CI does, so a per-file run can pass while CI fails on a pre-existing violation in an untouched file.
- Always pass the project's settings file (`-Settings <path>`) so the local ruleset matches CI exactly. **Locate it, never assume it** — the path differs per repo (`.vscode/PSScriptAnalyzerSettings.psd1` and a bare `PSScriptAnalyzerSettings.psd1` at the root are both common), so read the CI workflow and pass the file it passes. Linting with the wrong ruleset — or none — silently reports rules the repo deliberately excludes, and every one of those is a false positive that costs a real fix.

## Terminal Usage

- Prefer non-interactive commands with flags over interactive ones.
- Always use non-interactive git diff: `git --no-pager diff` or `git diff | cat`.
- Display diffs with `delta --side-by-side` (e.g. `git -c core.pager='delta --side-by-side' diff`).
- Prefer `fd` for finding files and `rg` for searching code/content; avoid `find`. Both are installed.

## Documentation

- Code is the primary documentation — use clear naming, types, and docstrings.
- Keep documentation in docstrings of the functions or classes they describe, not in separate files. Separate docs files only when a concept cannot be expressed clearly in code.
- Match the project's existing docstring/comment-based-help **placement** convention — inspect same-folder siblings first (e.g. PowerShell comment-based help can sit *above* or *inside* the function, and the choice can differ by folder within one repo). If the project has no convention, default to placing help adjacent to the definition (for PowerShell, *inside* the function, just under `function Name {`).
- Never duplicate documentation across files. Store knowledge as current state, not as a changelog of modifications.
- Create/update relevant documentation after implementing and testing a change, not as a separate afterthought.

## Git worktrees

Applies when the repo uses the **bare-worktree layout**: the parent directory holds `.bare/` plus one directory per branch (e.g. `E:\Personal Projects\dotfiles\{.bare, main}`). **Check before creating a branch** — look for a sibling `.bare/`, or run `git worktree list`. In a normal clone, branch as usual and ignore the rest of this section.

- **A new branch means a new worktree. Never `git checkout -b` inside the `main` worktree.** From the parent dir: `git worktree add ../<branch-dir> -b <branch>` (flatten any `/` in the branch name for the directory), then change the working directory to that worktree and do the work there.
- **Why:** the point of the layout is that every worktree is a stable, always-available checkout of its branch. `main` must stay on `main` so it remains browsable and buildable while feature work happens elsewhere — and so anything pointing at that path (tooling, another session, a live config) keeps seeing main.
- **After the PR is merged:** change back to the main worktree → `git pull` → `git worktree remove <dir>` (drops the registration *and* the directory) → **then** delete the branch. That order is forced: git refuses to delete a branch while a worktree still holds it, so the worktree always goes first.
- **Squash-merged PRs need `-D`, not `-d`.** GitHub's squash-merge rewrites the branch's commits, so `git branch -d` refuses with "not fully merged" even though every change landed. Verify nothing is lost with `git diff main <branch> --stat` (empty ⇒ safe), then force-delete. `git branch -D` is denied by a Claude Code deny hook, so ask me to run that one.

## Commits

- Use conventional commits.
