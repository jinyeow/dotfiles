---
name: fastmail
description: Pull a live Fastmail digest — unread emails, upcoming calendar events, and other inbox signals. Use when the user asks for an inbox summary, what's on their calendar, or wants a Fastmail overview.
---

Produce a Fastmail digest with the Fastmail MCP server's tools. The tool prefix depends on how the server is registered: `mcp__fastmail__` when `setup.ps1 -Module fastmail` registered it, `mcp__Fastmail__` for the claude.ai connector. Use whichever is present. Query all sources in parallel before formatting:

1. **Recent unread** — `search_email`: unread emails from the last 48 hours. For each: sender, subject, one-line summary. Mark urgent or time-sensitive ones.

2. **Calendar** — `search_events`: events in the next 7 days. For each: date/time in the user's local time zone (read it from the system clock; do not assume a fixed UTC offset), title, location if present.

3. **Backlog** — `search_email`: unread emails older than 48 hours, up to 10. Sender + subject + age only.

If args were passed, adjust scope accordingly (e.g. "last week", "today only", "calendar only").

Output:

## Inbox (last 48h)
- **[Sender]** Subject — summary [URGENT if time-sensitive]

## Calendar (next 7 days)
- [Weekday DD Mon HH:MM <local zone abbreviation>] Title (Location)

## Unread backlog
- [Sender] Subject (~age)

Empty section → "Nothing." Be concise.
