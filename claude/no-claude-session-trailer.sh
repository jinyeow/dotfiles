#!/usr/bin/env bash
# PreToolUse(Bash|PowerShell) hook: hard-block layer against AI/Claude/Codex/Copilot/
# co-authored-by references leaking into a commit, a PR, or an Azure Boards item (issue #219,
# layer 3). Reads the tool-call JSON on stdin (jq-based, same as before) and denies when the
# command BOTH matches one of the guarded command shapes AND contains a banned term from the
# shared wordlist (ai-agents/_shared/banned-ai-terms.txt, read as a sibling file next to this
# script at its installed runtime path, ~/.claude/banned-ai-terms.txt — resolved from this
# script's own path). That resolution makes the installed sibling path work; run straight from
# this repo (`claude/` has no wordlist sibling here) it fails closed instead, per the missing-
# wordlist check below. Mere prose mentioning a term in an unrelated command stays silent
# (exit 0 = allow) — this is not a blanket "any command mentioning Claude" denier, and nor is
# it a scan of the whole raw command line: see the message-content extraction below for why.
#
# Guarded command shapes:
#   1. `git ... commit` — the original trailer check, generalized to the full wordlist.
#   2. PR create/update: `gh pr create`/`gh pr edit`, `az repos pr create`/`az repos pr update`.
#   3. Azure Boards: `az boards ...` (subcommands vary, matched broadly), `az devops invoke`
#      (the generic Boards REST passthrough) — the exact case that leaked for real.
#
# Independently of the wordlist, any git command using `--no-verify` (or `git commit` using the
# `-n` short form) is denied outright: that flag bypasses this repo's git hooks (layer 2), and
# this hook is the backstop against that bypass. `git push -n` is deliberately NOT included in
# that short-form check: push's own `-n` means `--dry-run`, not `--no-verify` — there is no `-n`
# short form for push's no-verify, so `git push -n` is a legitimate, harmless command.
#
# The `git ... commit` matcher allows each leading global flag to carry an argument (git -C
# <path> commit, git -c k=v commit): a unit is `-flag` optionally followed by one non-flag
# argument token, so a flag WITH an argument can't slip between `git` and `commit` and evade
# the check.
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
pr_re='\bgh\b[[:space:]]+pr[[:space:]]+(create|edit)\b|\baz\b[[:space:]]+repos[[:space:]]+pr[[:space:]]+(create|update)\b'
boards_re='\baz\b[[:space:]]+boards\b|\baz\b[[:space:]]+devops[[:space:]]+invoke\b'

matches() {
  printf '%s' "$cmd" | grep -Eq -- "$1"
}

# --no-verify hard block (git hook bypass), independent of the wordlist.
if matches '\bgit\b'; then
  if matches '--no-verify\b'; then
    deny "git --no-verify bypasses this repo's git hooks (layer 2) — not allowed."
  fi
  if matches "$commit_re" && matches '(^|[[:space:]])-n([[:space:]]|$)'; then
    deny "git commit -n (--no-verify) bypasses this repo's git hooks (layer 2) — not allowed."
  fi
  # SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS=1 (as an env-var prefix, export, or env(1) arg) is
  # git/templates/hooks/{commit-msg,pre-commit}'s own human bypass hatch — matching the
  # SKIP_GITLEAKS convention those hooks already ship. An agent invoking Bash directly can set
  # either var just as easily as a human, silently defeating layer 2's scan, so this hook
  # denies it outright the same way it denies --no-verify.
  if matches '\bSKIP_AI_REFERENCE_SCAN=1\b' || matches '\bSKIP_GITLEAKS=1\b'; then
    deny "SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS bypasses this repo's git hooks (layer 2) — not allowed from an agent."
  fi
fi

# Message content the wordlist is matched against: every quoted (single- or double-quoted)
# span in the raw command, PLUS the value of every recognized message-bearing flag even when
# unquoted (-m/--message/--title/--body/--description/--fields/--route-parameters) — not the
# whole raw command string. A banned term belongs in one of those VALUES; matching the whole
# raw command would false-positive on this repo's own path segments (e.g.
# `claude/settings.json`, `codex/ai-reference-guard.sh`), which contain the bare words
# "claude"/"codex" outside any message. Same approach as pi/extensions/ai-reference-guard.ts's
# collectQuotedContent, extended to unquoted flag values the same way that file's own
# value-flag extraction is. Real newlines inside a quoted `-m` value (the actual trailer
# shape: `git commit -m "feat: x\n\nCo-Authored-By: Claude"`) are flattened to spaces first,
# since a quoted span can't otherwise pair across lines under a single-line grep match.
flat_cmd=$(printf '%s' "$cmd" | tr '\n' ' ')
quoted_content=$(printf '%s' "$flat_cmd" | grep -oE '"[^"]*"|'"'"'[^'"'"']*'"'"'' | sed -e 's/^.//' -e 's/.$//')
message_flag_re='(-m|--message|--title|--body|--description|--fields|--route-parameters)(=|[[:space:]]+)("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)'
flag_value_content=$(printf '%s' "$flat_cmd" | grep -oE -- "$message_flag_re" | sed -E 's/^(-m|--message|--title|--body|--description|--fields|--route-parameters)(=|[[:space:]]+)//' | sed -e "s/^\"//" -e "s/\"\$//" -e "s/^'//" -e "s/'\$//")
message_content=$(printf '%s\n%s' "$quoted_content" "$flag_value_content")
matches_message_ci() {
  printf '%s' "$message_content" | grep -Eqi -- "$1"
}

# Guarded command shapes, gated on a banned-term match against message content only.
if matches "$commit_re" && matches_message_ci "$wordlist_pattern"; then
  deny "Commit message contains a banned AI/attribution term (no-AI-references rule)."
fi

if matches "$pr_re" && matches_message_ci "$wordlist_pattern"; then
  deny "PR create/update contains a banned AI/attribution term (no-AI-references rule)."
fi

if matches "$boards_re" && matches_message_ci "$wordlist_pattern"; then
  deny "Azure Boards update contains a banned AI/attribution term (no-AI-references rule)."
fi
