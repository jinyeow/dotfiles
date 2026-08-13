---
name: refactor-agents-md
description: Refactor an AGENTS.md file to follow progressive disclosure — split it into a minimal root file plus linked category files.
disable-model-invocation: true
---

# Refactor AGENTS.md

Restructure a repo's AGENTS.md instructions to follow progressive disclosure: a minimal root
file covering only what every task needs, with everything else split into linked category
files loaded on demand. Done when every original instruction is placed, grouped, or flagged
for deletion — none silently dropped — and the user has approved the proposed structure.

A bad AGENTS.md file can confuse the agent, become a maintenance nightmare, and cost tokens on
every request. It typically mixes two scopes:
* **Personal scope**: commit style preferences, coding patterns the user prefers
* **Project scope**: what the project does, package manager/toolchain, architecture decisions

As a rough heuristic, frontier thinking models follow ~150-200 instructions with reasonable
consistency; smaller and non-thinking models follow fewer. This is not a hard limit — treat it
as a reason to keep the root file lean, not a target to hit exactly.

## Process

### 0. **Locate the target file(s)**
A repo may have more than one AGENTS.md in play (root file, per-tool adapters, nested
per-directory files). Find them and confirm with the user which file(s) are in scope before
proceeding — don't assume "AGENTS.md" means a single file.

### 1. **Find contradictions**
Identify any instructions that conflict with each other. For each contradiction, ask the user
which version to keep.

### 2. **Identify the essentials**
Extract only what belongs in the root AGENTS.md:
   - One-sentence project description
   - Package manager / toolchain (if non-default for the ecosystem)
   - Non-standard build/typecheck commands
   - Anything truly relevant to every single task

### 3. **Group the rest**
Organize remaining instructions into logical categories (e.g., language conventions, testing
patterns, API design, Git workflow). Plan one separate markdown file per group.

### 4. **Propose, then apply**
Present the proposed structure to the user before writing anything:
   - The minimal root AGENTS.md with markdown links to the separate files
   - Each separate file's contents and its target path
   - The suggested docs/ folder structure
   Only write the files after the user approves the proposal.

### 5. **Flag for deletion**
Identify any instructions that are:
   - Redundant (the agent already knows this)
   - Too vague to be actionable
   - Overly obvious (like "write clean code")
   Flag these for the user to confirm before dropping them — don't delete unilaterally.
