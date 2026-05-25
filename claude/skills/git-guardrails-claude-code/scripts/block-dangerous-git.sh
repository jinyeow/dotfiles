#!/bin/bash
# block-dangerous-git.sh
# Claude Code PreToolUse hook — blocks dangerous git commands before execution.
#
# Install:
#   cp block-dangerous-git.sh .claude/hooks/block-dangerous-git.sh
#   chmod +x .claude/hooks/block-dangerous-git.sh
#
# Wire up in .claude/settings.json:
#   {
#     "hooks": {
#       "PreToolUse": [
#         {
#           "matcher": "Bash",
#           "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-dangerous-git.sh" }]
#         }
#       ]
#     }
#   }
#
# The hook reads a JSON object from stdin. Claude Code passes:
#   { "tool_input": { "command": "<the bash command>" } }
# Exit 0  → allow the command through.
# Exit 2  → block the command (Claude sees the stderr message).

set -euo pipefail

# Read stdin (the hook payload)
INPUT=$(cat)

# Extract the command string from the JSON payload.
# Use python if available (most reliable); fall back to basic sed.
if command -v python3 &>/dev/null; then
  COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
elif command -v python &>/dev/null; then
  COMMAND=$(echo "$INPUT" | python -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
else
  # Naive extraction — good enough for single-line commands
  COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
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
    echo "BLOCKED: Claude does not have authority to run: $COMMAND" >&2
    echo "Reason: this command matches a dangerous-git-operations blocklist." >&2
    echo "If you want to run this command, do it yourself in a terminal." >&2
    exit 2
  fi
done

# Command is safe — allow it through.
exit 0
