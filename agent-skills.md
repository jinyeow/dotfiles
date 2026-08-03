# Agent skills

This file configures the repository's spec, design, ticket, triage, and wayfinding
skills. Run `/setup-agent-skills` before changing these values.

- **Specs**: `.claude/specs/`
- **High-level designs**: `docs/design/`
- **Tickets**: GitHub Issues in `jinyeow/dotfiles`
- **Labels**: `spec-ready`, `design-ready`, `triaged`, `ready`, `needs-info`, `wontfix`
- **Domain docs**: single-context layout with root `CONTEXT.md` and `docs/adr/`
- **Wayfinding**: GitHub parent/child issues for maps; use `wayfinder:map`, `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, and `wayfinder:task`; use GitHub's native blocking relationships; frontier means open, unblocked, unassigned child issues; claim by assigning the issue to the implementing developer.
