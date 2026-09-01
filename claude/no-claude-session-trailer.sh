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
#
# Scoped to Hollard/Azure DevOps repos only, mirroring git/templates/hooks/pre-commit's own
# scoping: `git remote get-url origin`, run from this hook's inherited cwd, must succeed AND
# contain both dev.azure.com and HollardInsuranceRetail (case-insensitive). If the repo has no
# origin, isn't a repo at all, or the origin is a GitHub URL (dotfiles, wiki, brain — repos that
# legitimately say "Claude"/"Codex" in their own subject matter), every check below is skipped:
# the wordlist scan, the --no-verify/-n denies, and the SKIP_*-env-var denies alike.
origin_url=$(git remote get-url origin 2>/dev/null) || exit 0
if ! { printf '%s' "$origin_url" | grep -qi 'dev\.azure\.com' &&
       printf '%s' "$origin_url" | grep -qi 'HollardInsuranceRetail'; }; then
  exit 0
fi

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

# `-n`/SKIP-var bound: `[^;&|]*` between the guarded subcommand and the flag/assignment keeps
# the match scoped to one shell segment, mirroring codex/ai-reference-guard.sh's equivalent
# `[^;&|]*` gap — so `git commit -m "fix" && git log -n 1` (or `&& git push -n origin main`)
# isn't treated as `git commit -n`, and `SKIP_GITLEAKS=1 rg foo && git log -n 1` (SKIP_GITLEAKS
# assigned in an unrelated earlier segment) isn't treated as a bypass of a git commit that
# never appears in that same segment.
commit_dashn_re="${commit_re}[^;&|]*[[:space:]]-n([[:space:]]|\$)"
# SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS=1 assignment shape: at the start of the command or a
# shell segment, or after `export `/`env `, matching either an unquoted `1` or a single-/
# double-quoted `'1'`/`"1"` (the git hooks' own `[ "$SKIP_GITLEAKS" = "1" ]` check treats both
# the same way, since the shell strips the quotes) — not a bare substring match, so a command
# that merely mentions the literal string in unrelated prose (e.g. `rg 'SKIP_GITLEAKS=1'
# README.md`) doesn't match this shape at all.
skip_assign_re="(^|[;&|][[:space:]]*|export[[:space:]]+|env[[:space:]]+)SKIP_(AI_REFERENCE_SCAN|GITLEAKS)=['\"]?1\\b"
skip_commit_re="${skip_assign_re}[^;&|]*${commit_re}"

matches() {
  printf '%s' "$cmd" | grep -Eq -- "$1"
}

# --no-verify hard block (git hook bypass), independent of the wordlist.
if matches '\bgit\b'; then
  if matches '--no-verify\b'; then
    deny "git --no-verify bypasses this repo's git hooks (layer 2) — not allowed."
  fi
  if matches "$commit_dashn_re"; then
    deny "git commit -n (--no-verify) bypasses this repo's git hooks (layer 2) — not allowed."
  fi
  # SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS=1 (as an env-var prefix, export, or env(1) arg, in the
  # same shell segment as the guarded `git ... commit`) is git/templates/hooks/{commit-msg,
  # pre-commit}'s own human bypass hatch — matching the SKIP_GITLEAKS convention those hooks
  # already ship. An agent invoking Bash directly can set either var just as easily as a human,
  # silently defeating layer 2's scan, so this hook denies it outright the same way it denies
  # --no-verify.
  if matches "$skip_commit_re"; then
    deny "SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS bypasses this repo's git hooks (layer 2) — not allowed from an agent."
  fi
fi

# Message content the wordlist is matched against: the value of every recognized message-
# bearing flag (-am/-m/--message/--title/--body/--description/--fields/--route-parameters/
# --discussion/--text/--query-parameters), quoted or unquoted — not a blanket scan of every
# quoted span in the command, and not the whole raw command string. A banned term always
# arrives via one of these flags; scanning every quoted span would also catch quoted content
# attached to an unrelated flag (e.g. `git -C "claude-project" commit -m "fix"`), and matching
# the whole raw command would false-positive on this repo's own path segments (e.g.
# `claude/settings.json`, `codex/ai-reference-guard.sh`), which contain the bare words
# "claude"/"codex" outside any message. An optional `key=` prefix before the value handles the
# key=value shape some of these flags use (`--query-parameters text="thanks Claude"`), matching
# --fields/--route-parameters' own convention. The quoted-value alternatives are escape-aware
# (`(?:[^"\\]|\\.)*`, requiring PCRE via `grep -P`) so an escaped inner quote (`-m "say \"Claude
# \" less please"`) doesn't truncate the match at the first literal `"` — the naive `[^"]*` grep
# -E form used to stop there and never see the banned term. Real newlines inside a quoted `-m`
# value (the actual trailer shape: `git commit -m "feat: x\n\nCo-Authored-By: Claude"`) are
# flattened to spaces first, since a quoted span can't otherwise pair across lines under a
# single-line grep match.
flat_cmd=$(printf '%s' "$cmd" | tr '\n' ' ')
message_flag_re='(?:^|[[:space:]])(?:-am|-m|--message|--title|--body|--description|--fields|--route-parameters|--discussion|--text|--query-parameters)(?:[[:space:]]+|=)\K(?:[A-Za-z0-9_.-]+=)?("(?:[^"\\]|\\.)*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)'
message_content=$(printf '%s' "$flat_cmd" | grep -oP -- "$message_flag_re")
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
