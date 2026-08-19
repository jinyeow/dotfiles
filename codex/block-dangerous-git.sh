#!/bin/bash
# block-dangerous-git.sh
# Codex CLI PreToolUse hook — blocks dangerous git commands before execution.
# Ported from claude/skills/git-guardrails-claude-code/scripts/block-dangerous-git.sh;
# the blocklist/matching logic is unchanged, only the install/wiring comments differ.
#
# Install:
#   Copied to ~/.codex/block-dangerous-git.sh by `setup.ps1 -Module codex`.
#
# Wired up in ~/.codex/hooks.json:
#   {
#     "hooks": {
#       "PreToolUse": [
#         {
#           "matcher": "Bash",
#           "hooks": [{ "type": "command", "command": "bash ~/.codex/block-dangerous-git.sh" }]
#         }
#       ]
#     }
#   }
#
# The hook reads a JSON object from stdin. Codex passes:
#   { "tool_input": { "command": "<the bash command>" }, ... }
# Exit 0  → allow the command through.
# Exit 2  → block the command (Codex sees the stderr message).

set -euo pipefail

# Read stdin (the hook payload)
INPUT=$(cat)

# Extract the command string from the JSON payload.
# Use python if available (most reliable); fall back to basic sed.
#
# `command -v` only proves an executable exists on PATH — on Windows this is also
# true for the WindowsApps python3/python "app execution alias" stubs that exist on
# PATH but exit non-zero without Python actually installed. Gate each tier on the
# pipeline itself succeeding (not just presence) so a broken stub falls through to
# the next tier instead of silently producing an empty COMMAND (which would make
# every blocked pattern below fail to match, disabling the guardrail).
PYTHON_EXTRACT="import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))"
if command -v python3 &>/dev/null && COMMAND=$(echo "$INPUT" | python3 -c "$PYTHON_EXTRACT" 2>/dev/null); then
  :
elif command -v python &>/dev/null && COMMAND=$(echo "$INPUT" | python -c "$PYTHON_EXTRACT" 2>/dev/null); then
  :
else
  # Naive extraction — good enough for single-line commands. `|| echo ""` keeps
  # this non-fatal under `set -euo pipefail` when no "command" key matches
  # (malformed JSON or a command-less payload), so the hook falls through to
  # allow rather than crashing.
  COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/' || echo "")
fi

# ── Blocked patterns ──────────────────────────────────────────────────────────
# Add or remove patterns here. Each pattern is a grep extended-regex fragment
# matched against the full command string.

BLOCKED_PATTERNS=(
  # Push (all variants)
  "git[[:space:]]+(.*[[:space:]]+)?push([[:space:]]|$)"

  # Hard reset
  "git[[:space:]]+(.*[[:space:]]+)?reset[[:space:]].*--hard"

  # Clean (force)
  "git[[:space:]]+(.*[[:space:]]+)?clean[[:space:]].*-[a-zA-Z]*f"

  # Delete branch (force)
  "git[[:space:]]+(.*[[:space:]]+)?branch[[:space:]].*-D"

  # Checkout / restore all (wipes working tree)
  "git[[:space:]]+(.*[[:space:]]+)?checkout[[:space:]]+\."
  "git[[:space:]]+(.*[[:space:]]+)?restore[[:space:]]+\."
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: Codex does not have authority to run: $COMMAND" >&2
    echo "Reason: this command matches a dangerous-git-operations blocklist." >&2
    echo "If you want to run this command, do it yourself in a terminal." >&2
    exit 2
  fi
done

# Command is safe — allow it through.
exit 0
