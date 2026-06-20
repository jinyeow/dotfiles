#!/usr/bin/env bash
# PreToolUse(Bash|PowerShell) hook: block git commits carrying the Claude-Session
# AI trailer, enforcing the no-AI-references-in-commits rule. Reads the tool-call
# JSON on stdin; emits a deny decision only when the command is a git commit that
# contains the trailer, otherwise stays silent (exit 0 = allow).
cmd=$(jq -r '.tool_input.command // ""')
if printf '%s' "$cmd" | grep -q 'git commit' && printf '%s' "$cmd" | grep -q 'Claude-Session'; then
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Remove the Claude-Session trailer from the commit message (your no-AI-references-in-commits rule)."}}'
fi
