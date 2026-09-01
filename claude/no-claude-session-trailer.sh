#!/usr/bin/env bash
# PreToolUse(Bash|PowerShell) hook: hard-block layer against AI/Claude/Codex/Copilot/
# co-authored-by references leaking into a commit, a PR, or an Azure Boards item (issue #219,
# layer 3). Reads the tool-call JSON on stdin (jq-based, same as before) and denies when the
# command BOTH matches one of the guarded command shapes AND contains a banned term from the
# shared wordlist (ai-agents/_shared/banned-ai-terms.txt, read as a sibling file next to this
# script at its installed runtime path, ~/.claude/banned-ai-terms.txt — resolved from this
# script's own path so it also works run straight from the repo). Mere prose mentioning a term
# in an unrelated command stays silent (exit 0 = allow) — this is not a blanket "any command
# mentioning Claude" denier.
#
# Guarded command shapes:
#   1. `git ... commit` — the original trailer check, generalized to the full wordlist.
#   2. PR create/update: `gh pr create`/`gh pr edit`, `az repos pr create`/`az repos pr update`.
#   3. Azure Boards: `az boards ...` (subcommands vary, matched broadly), `az devops invoke`
#      (the generic Boards REST passthrough) — the exact case that leaked for real.
#
# Independently of the wordlist, any git command using `--no-verify` (or `git commit`/`git
# push` using the `-n` short form) is denied outright: that flag bypasses this repo's git
# hooks (layer 2), and this hook is the backstop against that bypass.
#
# The `git ... commit` / `git ... push` matcher allows each leading global flag to carry an
# argument (git -C <path> commit, git -c k=v commit): a unit is `-flag` optionally followed by
# one non-flag argument token, so a flag WITH an argument can't slip between `git` and the
# subcommand and evade the check.
cmd=$(jq -r '.tool_input.command // ""')

script_dir=$(cd -- "$(dirname -- "$0")" &>/dev/null && pwd)
wordlist="$script_dir/banned-ai-terms.txt"

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$1"
  exit 0
}

if [[ ! -r "$wordlist" ]]; then
  deny "AI-reference hard-block wordlist is missing or unreadable at $wordlist — failing closed."
fi

wordlist_pattern=$(grep -Ev '^[[:space:]]*(#|$)' "$wordlist" | paste -sd'|' -)

flag_group='([[:space:]]+-[^[:space:]]+([[:space:]]+[^-][^[:space:]]*)?)*'
commit_re="\\bgit\\b${flag_group}[[:space:]]+commit\\b"
push_re="\\bgit\\b${flag_group}[[:space:]]+push\\b"
pr_re='\bgh\b[[:space:]]+pr[[:space:]]+(create|edit)\b|\baz\b[[:space:]]+repos[[:space:]]+pr[[:space:]]+(create|update)\b'
boards_re='\baz\b[[:space:]]+boards\b|\baz\b[[:space:]]+devops[[:space:]]+invoke\b'

matches() {
  printf '%s' "$cmd" | grep -Eq -- "$1"
}
matches_ci() {
  printf '%s' "$cmd" | grep -Eqi -- "$1"
}

# --no-verify hard block (git hook bypass), independent of the wordlist.
if matches '\bgit\b'; then
  if matches '--no-verify\b'; then
    deny "git --no-verify bypasses this repo's git hooks (layer 2) — not allowed."
  fi
  if matches "$commit_re" && matches '(^|[[:space:]])-n([[:space:]]|$)'; then
    deny "git commit -n (--no-verify) bypasses this repo's git hooks (layer 2) — not allowed."
  fi
  if matches "$push_re" && matches '(^|[[:space:]])-n([[:space:]]|$)'; then
    deny "git push -n (--no-verify) bypasses this repo's git hooks (layer 2) — not allowed."
  fi
fi

# Guarded command shapes, gated on a banned-term match.
if matches "$commit_re" && matches_ci "$wordlist_pattern"; then
  deny "Commit message contains a banned AI/attribution term (no-AI-references rule)."
fi

if matches "$pr_re" && matches_ci "$wordlist_pattern"; then
  deny "PR create/update contains a banned AI/attribution term (no-AI-references rule)."
fi

if matches "$boards_re" && matches_ci "$wordlist_pattern"; then
  deny "Azure Boards update contains a banned AI/attribution term (no-AI-references rule)."
fi
