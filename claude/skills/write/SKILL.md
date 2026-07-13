---
name: write
description: "Rewrite and polish English prose to remove AI-sounding wording while preserving the author's intent and voice, for drafts, docs, READMEs, release notes, and long-form articles. Use when asked to de-AI, polish, rewrite, proofread, tighten, or review prose, check paragraph coherence, or draft release notes from commits. Not for code comments, commit messages, or inline docs."
---

# Write: Cut the AI Taste

Strip AI patterns from prose and rewrite it to sound human. Do not improve vocabulary; remove the performance of improvement.

## Outcome Contract

- Outcome: the prose preserves the author's intent while sounding natural for its audience and surface.
- Done when: meaning, factual claims, and structure are preserved unless the user asked to change them, and AI-like wording is removed.
- Evidence: supplied text, target audience, project style references, and release or product state.
- Output: the edited prose only, unless the user asked for notes, variants, or review comments.

## Core Stance

This skill is a catalog of smells, not a checklist to run top to bottom. Use it to recognize AI taste, then make judgment calls. The reference file `references/write-en.md` is long because it accumulated examples over many sessions; do not try to apply every rule to every text. Applying more rules is not doing a better job.

- **Over-editing is failure, equal to under-editing.** If a sentence is already natural, clear, and stable, leave it. Most polish is subtraction (cut repetition, summary-tone, restated conclusions), not phrase-by-phrase replacement.
- **The author's voice wins.** Keep the author's existing colloquial words, cadence, and stance. When a rule conflicts with a deliberate authorial or genre choice (a question title in a narrative piece, a list the author wants kept), the author wins. Rules are defaults, not laws.
- **Banned-phrase lists and replacement tables are examples, not find-and-replace.** A flagged word that reads naturally in context stays. Match the smell, not the string.
- **Prefer fewer, stronger edits.** Three changes that matter beat thirty mechanical swaps that flatten the voice.

When distilling a new lesson into this skill, fold it into an existing principle instead of appending another banned phrase. This skill must not grow monotonically; collapsing specifics back into principles is part of maintaining it.

## Pre-flight

1. **Text present?** If the user gave only an instruction with no actual prose to edit, ask for the text in one sentence. Do not proceed.
2. **Audience locked?** If the intended audience is unclear and cannot be inferred from the text (blog reader vs RFC vs email), ask before editing. Junior engineer and senior architect prose should read completely different.
3. **Load `references/write-en.md`** for the AI-taste pattern catalog before editing.

No summary, no commentary, no explanation of changes unless explicitly asked.

## Hard Rules

- **Meaning first, style second.** If removing an AI pattern would change the author's intended meaning, keep the original.
- **No silent restructuring.** Do not reorganize headings, reorder paragraphs, or merge sections unless structural changes are explicitly requested. Edit in place. Structural assets are not cleanup noise: image placeholders, links, frontmatter, and example blocks stay unless the user asked to remove them, and any deletion gets listed with its reason instead of discovered later in the diff. (Exception: Long-form Article Mode treats structural cuts and merges as in-scope, since structure is the main problem there; it still proposes them as change-points first instead of doing them silently.)
- **No invented first-person experience.** When ghostwriting as the author, every personal anecdote, tool history, opinion, and quote must come from the supplied material or the author's published writing. The material lacking an example is a question to ask, not a gap to fill. Before drafting in the author's voice (rather than editing supplied text), read one or two of their published pieces as the voice and length baseline.
- **Shorter than the first draft wants to be.** Outward copy (README paragraphs, release notes, maintainer replies) defaults to the length of the user's previously accepted pieces; when a physical constraint exists (single-line rendering), derive the budget from the constraint before writing, not after the user trims it.
- **Artifact-grounded claims.** For release notes, product pages, and public replies, ground factual claims in real source material: current app behavior, runnable artifact, screenshot, product page, release page, changelog, issue/PR, or user-provided draft. Do not present handoffs, plans, old memory, or stale screenshots as current product truth, and do not turn concrete product evidence into generic marketing language.
- **No em-dash.** Never produce em-dash (U+2014 `—`) or en-dash (U+2013 `–`) in output. Em-dash is the strongest AI-tone fingerprint in this style of writing. Use commas, periods, colons, semicolons, or parentheses to break clauses. Hyphen-minus (`-`) inside compound words is allowed; replace it with a space or a period when possible. When editing a draft that contains em-dashes, replace every one before returning the text.
- **Stop after output.** Deliver the rewritten text. Do not append a list of changes, a justification, or a closer. (Exception: Long-form Article Mode returns change-points for review instead of a rewritten blob; see that mode.)

## Long-form Article Mode

Activate when: editing a Markdown article or file over ~300 lines, or one with multiple `##` sections plus tables and images (technical long-reads, blog posts, deep dives).

In long-form, the dominant problem is usually structural: the same checklist repeated across sections, prose that re-reads a table sitting right above it, list bloat, whole redundant sections. Sentence-level AI taste is the smaller half. A single in-place polish pass cannot see or fix the structural half, which is why a plain `/write` on a long article feels like it changed wording but left the bloat. This mode therefore overrides two Hard Rules: structural cuts and merges are in-scope, and the output is change-points for review, not a rewritten blob.

Workflow:

1. **Map first, read-only.** Before editing anything, read the whole article and list every `##` section, table, list, and image. Flag three structural problems: cross-section repetition (same checklist / judgment list / core claim in 2+ sections), table re-reading (a section whose prose walks the rows of the table above it), and whole redundant sections or paragraphs.
2. **Propose cuts as change-points.** Show before to after for each structural cut or merge and let the user pick the subset. Never delete a whole section or paragraph silently; confirm first, since it may hold a fact found nowhere else.
3. **Then line-level de-AI**, section by section, per `references/write-en.md`.
4. **Output is change-points, not a blob.** Show what changed so the user can review and keep their own hand-edits. Only return fully rewritten text when the user says just rewrite.

Do not single-pass rewrite a 40k-character article: it silently overwrites the author's hand-tuned phrasing and cannot be reviewed as a diff. See `references/write-en.md` (Re-anchoring after cutting recaps) for the matching content rules.

## Release Note Template Mode

Activate when: "release", "changelog", "version", "release notes"

Generate from commit messages:
- **Breaking Changes**
- **New Features**
- **Fixes & Improvements**
- **Deprecations**

Format: target-project style by default. If no project style is available, use numbered items with bold labels, one sentence on user effect.

### Release Notes Pre-flight

Before drafting, gather style references:

1. Read the target project's `CLAUDE.md` for its Release Convention / Release Flow section.
2. Read the target project's existing release source as a style, length, and density reference: changelog, release notes, registry page, update feed, or platform release page.
3. For GitHub projects, `gh release view --json body -R <owner>/<repo>` is the preferred way to read the most recent release when `gh` is available. If the project is not on GitHub, use the release source named by the project docs or user request.
4. If the user mentions comparing with a sibling project's release style, ask for the target identifier or release URL before fetching it.
5. Match the reference release's item count, sentence length, and tone. Do not invent a new format.
6. Keep each release-note item to one sentence unless the reference project clearly does otherwise. Do not add emoji to release prose unless the target surface is explicitly a reaction or celebratory social surface.

### Release Notes Content Rules

- **Group by user-perceivable feature**, not by internal taxonomy. "Polish", "Misc improvements", "Chores" are not categories users can act on. Group by product surface (Clean / Uninstall / Status / Settings) or by user-visible verb (Faster startup / New keyboard shortcut / Fixed crash on M3).
- **Extract from `git log <last-tag>..HEAD`** rather than from memory. Read every `feat:` and `fix:` commit; do not omit small items just because they look minor in commit form.
- **One sentence per item, naming the user-visible change**, not the implementation. "Use `CKDownloadQueue` observer for App Store updates" is not a release note; "App Store updates now run inside the app instead of opening App Store" is.

## Document Review Mode

Activate when: PDF, document, white paper, "review this document", "check this document"

Review checklist:
- **Privacy scan**: Detect PII (names, companies, employment dates, salary hints, location details). Hard stop if any text implies job seeking, competitor info, or personal data leakage.
- **Tone consistency**: Flag voice shifts, register mismatches, formulaic phrasing. Check for AI patterns using the `references/write-en.md` rules.
- **Rendering check**: Placeholder text remaining (`Lorem ipsum`, `TODO`, `[TBD]`), broken image links.
- **Durable-doc scan**: If the document is a review report, scorecard, or diagnostic snapshot, flag dated claims, stale line references, private paths, repo-specific commands, and current-score framing. Recommend extracting stable rules instead of preserving the snapshot as evergreen guidance.

Output format: same as prose rewrite, but append `privacy: clear / N issues found` after the reviewed text.

## Paragraph Coherence Mode

Activate when: "coherence", "flow check", "readability"

Do not rewrite. Instead, work through each paragraph in sequence:
1. Flag transitions that abruptly shift topic without a signal.
2. Flag paragraphs where the opening sentence does not follow from the previous paragraph's close.
3. Flag rhythm issues: monotone sentence length (all short or all long across a whole paragraph).
4. Suggest the minimal fix for each: one word, one reordered clause, one bridging sentence.

Output: a numbered list of issues, each with the paragraph location and a one-line fix suggestion. Then ask if the user wants any applied.

## Gotchas

| What happened | Rule |
|---------------|------|
| Reorganized headings without being asked | Do not restructure; edit in place unless structure changes are explicitly requested |
| Appended a "changes made" list after the rewrite | Output is the edited text only. No changelog, no commentary. |
| Used formal register for a blog draft | Match the target audience's register. Blog is conversational, not academic. |
| Polished the user's voice into generic launch copy | Preserve the author's cadence and stance. Use real product artifacts to sharpen facts, not to replace the voice. |
| Drafted release copy from memory or a handoff | Read the current release page, changelog, issue/PR, runnable artifact, product page, or supplied source before making factual claims. |
| Polished a review report until it sounded timeless | Keep snapshots labeled as snapshots, or distill them into stable rules. Do not make dated claims sound evergreen |
| User flagged one word as "not my voice"; only that instance was fixed | A flagged word marks a smell class, not a typo. Sweep the whole text for the same class (same register, same template shape) before returning |

## Output

Return only the edited prose. If the text was truncated or if multiple versions were possible, note that in one sentence after the body. Otherwise, no wrapper, no preamble, no postscript.
