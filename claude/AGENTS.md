# Agent coding conventions

Shared conventions for every coding agent (Claude Code and Codex CLI). Tool-specific
behaviour lives elsewhere: Claude in `~/.claude/CLAUDE.md` (which imports this file),
Codex reads this file directly as `~/.codex/AGENTS.md`.

## Global preferences

- Keep explanations concise
- Show the terminal command to verify changes
- Prefer composition over inheritance
- When reporting information to me, be extremely concise and sacrifice grammar for the sake of concision.
- Do not add references to AI or "Co-Authored-By" statements to commits or other documents

## Code Style

- Comments in English only
- Follow DRY, KISS, and YAGNI principles
- Use strict typing everywhere - function returns, variables, collections
- Check if logic already exists before writing new code
- Avoid untyped variables and generic types
- Create proper type definitions for complex data structures
- All imports at the top of the file
- Prefer simple single-purpose functions over multi-mode behavior or flag parameters that switch logic. This is the rule that triggers a flag: these patterns are NOT banned, but when one looks like the best option, stop and raise it with me before implementing — name this rule, lay out the trade-off, and let me choose. Do not silently implement a flag/mode parameter, and do not silently contort the design to avoid one. Why it's needed: a parameter that switches behavior pushes complexity onto every caller and hides several behaviors behind one name, so adopting one should be a deliberate, shared decision rather than a default I make alone. (Note: an optional *output* parameter that adds a side-channel without changing the core return value or logic path — e.g. an out-variable like `-ResponseHeadersVariable` — does not count as a mode switch and does not need flagging.)

## Error Handling

- Always raise errors explicitly, never silently ignore them
- Use specific error types that clearly indicate what went wrong
- Avoid catch-all exception handlers that hide the root cause
- Error messages should be clear and actionable
- No fallbacks unless I explicitly ask for them
- Fix root causes, not symptoms
- External API or service calls: use retries with warnings, then raise the last error
- Error messages must include enough context to debug: request params, response body, status codes
- Logging should use structured fields instead of interpolating dynamic values into messages

## Language Specifics

- Prefer structured data models over loose dictionaries
- Avoid generic types like `Any`, `unknown`, or `List[Dict[str, Any]]`
- Use the language's strict type features when available

## Testing

- Respect the current repository testing strategy and existing test suite
- Use TDD for ALL code creation and changes: write the failing test first and confirm it fails (RED), then the minimal code to make it pass (GREEN), then refactor. One test at a time (vertical slices), never all-tests-then-all-code.
- For bug fixes, first write a test that reproduces the bug (confirm RED), then apply the fix.

## Linting

- Run PSScriptAnalyzer with `-Recurse` over the whole source tree (e.g. `<Module>/src`), not per changed file — CI does, so a per-file run can pass while CI fails on a pre-existing violation in an untouched file.
- Always pass the project's settings file (`-Settings .vscode/PSScriptAnalyzerSettings.psd1`) so the local ruleset matches CI exactly. Never assume the local ruleset; verify against the file CI uses.

## Terminal Usage

- Prefer non-interactive commands with flags over interactive ones
- Always use non-interactive git diff: `git --no-pager diff` or `git diff | cat`
- Prefer `rg` for searching code and files

## Documentation

- Code is the primary documentation - use clear naming, types, and docstrings
- Keep documentation in docstrings of the functions or classes they describe, not in separate files
- Separate docs files only when a concept cannot be expressed clearly in code
- Never duplicate documentation across files
- Store knowledge as current state, not as a changelog of modifications

## Commits

- Use conventional commits
