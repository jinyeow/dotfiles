---
name: wrapup
description: Two-question self-review before ending a session — run before /clear, /compact, or quitting so the agent reflects while it still has the turn.
disable-model-invocation: true
---

# Wrap up

Answer these two questions about the current conversation, grounded in what was actually
done (cite file:line or command output, not impressions):

1. What are you least confident about in your recent work?
2. What's the biggest thing you're probably missing that you haven't thought to ask?

Keep the answer tight — a few sentences per question, not a report. If the session did
nothing substantive yet, say so instead of inventing concerns.

After answering, tell the user it's safe to end the session (`/clear`, `/compact`, or quit)
now that the review is in context.
