# Global preferences

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
- Write simple single-purpose functions - no multi-mode behavior, no flag parameters that switch logic

## Error Handling

- Always raise errors explicitly, never silently ignore them
- Use specific error types that clearly indicate what went wrong
- Avoid catch-all exception handlers that hide the root cause
- Error messages should be clear and actionable
- No fallbacks unless I explicitly ask for them
- Fix root causes, not symptoms
- External API or service calls: use retries with warnings, then raise the last error
- Error messages must include enough context to debug: request params, response body, status codes
- Logging should use structured fields instead of interpolating dynamic values into m

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

## Claude Code Workflow

- Read the existing code and relevant `CLAUDE.md` files before editing
- Keep changes minimal and related to the current request
- Match the existing style of the repository even if it differs from my personal preference
- Do not revert unrelated changes
- If you are unsure, inspect the codebase instead of inventing patterns
- When project instructions include test or lint commands, run them before finishing i

## Documentation

- Code is the primary documentation - use clear naming, types, and docstrings
- Keep documentation in docstrings of the functions or classes they describe, not in separate files
- Separate docs files only when a concept cannot be expressed clearly in code
- Never duplicate documentation across files
- Store knowledge as current state, not as a changelog of modifications

## Commits
- Use conventional commits
