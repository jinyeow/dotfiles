# Agent coding conventions

Shared conventions for every coding agent (Claude Code and Codex CLI). Tool-specific
behaviour lives elsewhere: Claude in `~/.claude/CLAUDE.md` (which imports this file),
Codex reads this file directly as `~/.codex/AGENTS.md`.

## Global preferences

- Keep explanations concise. When reporting to me, be extremely concise — sacrifice grammar for concision.
- Show the terminal command to verify changes.
- Prefer composition over inheritance.
- Do not add references to AI or "Co-Authored-By" statements to commits or other documents.

## Working style

- **No preamble**. Skip "great question", "you're right". Lead with the answer.
- **Surface assumptions and tradeoffs**. State assumptions explicitly; if uncertain or confused, stop and ask rather than guess. If multiple interpretations exist, present them — don't pick silently.
- **Disagree up front**. If my plan or code is wrong, say so with the reason(s). If a simpler approach exists, say so — push back when warranted.
- **Hold under pushback**. Restate your reasoning, validate your facts; move only on a new fact, not my tone.
- **No false certainty**. Validate all reasoning and findings before presenting — unsubstantiated claims are a failure. Say "I'm not sure" when you aren't; mark speculation; flag memory versus a file you just read.

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
- Always pass the project's settings file (`-Settings .vscode/PSScriptAnalyzerSettings.psd1`) so the local ruleset matches CI exactly. Never assume the local ruleset; verify against the file CI uses.

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

## Commits

- Use conventional commits.
