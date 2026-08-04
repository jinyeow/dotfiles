---
name: linkedin-jobs
description: Read LinkedIn job alert emails and recruiter InMails, extract role details, and present them as structured cards grouped by inferred category. Use when the user wants to review job opportunities from their inbox.
---

Produce a LinkedIn jobs digest from the inbox. Default window: last 14 days, unread only. If args were passed (e.g. "30d", "7d"), use that window instead.

## Step 1 — Fetch emails

Run these three searches in parallel via `mcp__fastmail__search_email`:
1. `from:jobalerts-noreply@linkedin.com is:unread after:14d` (limit 30)
2. `from:inmail-hit-reply@linkedin.com is:unread after:14d` (limit 30)
3. `from:jobs-listings@linkedin.com is:unread after:14d` (limit 30)

## Step 2 — Filter

Discard anything that is clearly not a job posting or recruiter outreach (connection suggestions, profile views, endorsements, "people you may know", etc.). Keep only emails about specific roles or expressing intent to recruit.

## Step 3 — Read full bodies

For each email that passes the filter, call `mcp__fastmail__read_email` to get the full body. Run in parallel.

## Step 4 — Extract and categorise

For each role found, extract:
- **Title** and **Company**
- **Location** (on-site / hybrid / remote; city)
- **Salary range** (if stated)
- **Requirements** (skills, experience, qualifications)
- **Responsibilities** (key duties)
- **Source** (Job Alert / InMail — include recruiter name if InMail)
- **Apply link** (if present)

Then infer broad categories from the roles themselves — do not use a hardcoded list. Group similar roles under a shared label (e.g. "Platform Engineering", "DevOps / Infrastructure", "Engineering Leadership", "Software Engineering"). Let the actual roles drive the groupings; use as few or as many categories as make sense.

Within each category, sort newest-first.

## Step 5 — Output

One card per role:

### [Category] — Company: Role Title
- **Location**: ...
- **Salary**: ... (omit if not stated)
- **Requirements**: bullet list
- **Responsibilities**: bullet list
- **Source**: Job Alert / InMail from [Name]
- **Link**: ... (omit if not present)

End with a one-line summary: total roles found, breakdown by category.

If no matching emails are found, say so and suggest widening the window (e.g. `/linkedin-jobs 30d`).
