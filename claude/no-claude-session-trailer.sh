#!/usr/bin/env bash
# PreToolUse(Bash|PowerShell) hook: block git commits carrying the AI session-URL
# trailer, enforcing the no-AI-references-in-commits rule. Reads the tool-call JSON
# on stdin; denies only when the command BOTH invokes `git commit` as a command
# (word-boundary git ... commit, optionally with leading flags) AND embeds the real
# trailer line `Claude-Session:` (with the colon). Mere prose mentioning the words
# stays silent (exit 0 = allow).
cmd=$(jq -r '.tool_input.command // ""')
if printf '%s' "$cmd" | grep -Eq '\bgit\b[[:space:]]+(-[^[:space:]]+[[:space:]]+)*commit\b' \
   && printf '%s' "$cmd" | grep -q 'Claude-Session:'; then
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Remove the Claude-Session trailer from the commit message (your no-AI-references-in-commits rule)."}}'
fi
