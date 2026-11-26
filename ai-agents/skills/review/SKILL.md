---
name: review
description: Review whatever the user points at by routing it to the right reviewer. A diff, branch, commit range or PR goes to code-review; a plan, spec, ADR, design, proposal or other document goes to council; a spec and its tickets checked against the domain model go to critique-plan. Use when the user asks for a review without naming a review skill.
disable-model-invocation: true
---

Route the review to one skill and pass the user's arguments through unchanged. Do not review anything yourself.

1. Work out what the target is, from the arguments first and the conversation second:
   - **Code**: a diff, a branch, a commit or commit range, a fixed point such as `main`, or a pull request. Run `code-review`.
   - **An Azure DevOps pull request** (a `dev.azure.com` link or an ADO PR id): run `review-ado-pr`.
   - **A spec with its tickets**, when the question is whether they fit the domain model: run `critique-plan`.
   - **Any other document or idea**: a plan, roadmap, spec on its own, ADR, design, proposal or presentation. Run `council`.
2. If the target fits more than one row, or none, ask one question: "Is this a code review or a review of a document?" Then route.
3. Say in one line which skill you are running and why, then run it.
