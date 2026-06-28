---
name: fastmail
description: Pull a live Fastmail digest — unread emails, upcoming calendar events, and other inbox signals. Use when the user asks for an inbox summary, what's on their calendar, or wants a Fastmail overview.
---

Produce a Fastmail digest. Query all sources in parallel before formatting:

1. **Recent unread** — `mcp__fastmail__search_email`: unread emails from the last 48 hours. For each: sender, subject, one-line summary. Mark urgent or time-sensitive ones.

2. **Calendar** — `mcp__fastmail__search_events`: events in the next 7 days. For each: date/time (AEST, UTC+10), title, location if present.

3. **Backlog** — `mcp__fastmail__search_email`: unread emails older than 48 hours, up to 10. Sender + subject + age only.

If args were passed, adjust scope accordingly (e.g. "last week", "today only", "calendar only").

Output:

## Inbox (last 48h)
- **[Sender]** Subject — summary [URGENT if time-sensitive]

## Calendar (next 7 days)
- [Weekday DD Mon HH:MM AEST] Title (Location)

## Unread backlog
- [Sender] Subject (~age)

Empty section → "Nothing." Be concise.
