# Agent workflow

This is the shared repository configuration for the spec, design, ticket, triage, and
wayfinding skills. It is an explicit cross-harness convention, not an auto-loaded Agent
Skills standard file. Claude Code, Codex, and Pi read it only when one of those skills
needs the workflow configuration.

A private `.agents/workflow.local.md` takes precedence when present. Run
`/setup-agent-skills` before changing either file.

- **Specs**: `.agents/specs/`
- **High-level designs**: `docs/design/`
- **Tickets**: GitHub Issues in `jinyeow/dotfiles`
- **Labels**: `spec-ready`, `design-ready`, `triaged`, `ready`, `ready-for-human`, `needs-info`, `wontfix`
- **Domain docs**: single-context layout with root `CONTEXT.md` and `docs/adr/`
- **Wayfinding**: GitHub parent/child issues for maps; use `wayfinder:map`, `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, and `wayfinder:task`; use GitHub's native blocking relationships; frontier means open, unblocked, unassigned child issues; claim by assigning the issue to the implementing developer.
