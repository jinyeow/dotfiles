#!/bin/bash
# ai-reference-guard.sh
# Codex CLI PreToolUse hook — blocks AI/Claude/Codex/Copilot/co-authored-by references
# from being written into a commit, PR, or Azure Boards item, and blocks git-hook
# bypass via --no-verify. Layer 4 of issue #219 (jinyeow/dotfiles): a hard-block that
# cannot be skipped by a prompt-level rule.
#
# Ported in structure from codex/block-dangerous-git.sh (stdin JSON extraction tiers
# and BLOCKED:/Reason: stderr format are unchanged); the wordlist scan is new.
#
# Install:
#   Copied to ~/.codex/ai-reference-guard.sh by `setup.ps1 -Module codex` (sibling to
#   ~/.codex/banned-ai-terms.txt, which is copied alongside it — same directory, so it
#   is resolved relative to this script's own location at runtime, not hardcoded).
#
# Wired up in ~/.codex/hooks.json:
#   {
#     "hooks": {
#       "PreToolUse": [
#         {
#           "matcher": "Bash",
#           "hooks": [{ "type": "command", "command": "bash ~/.codex/ai-reference-guard.sh" }]
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

# Resolve the wordlist path relative to this script's own directory, since this whole
# directory is copied (not symlinked) to ~/.codex — see codex/README.md's "copy, not
# symlink" rationale.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORDLIST_PATH="$SCRIPT_DIR/banned-ai-terms.txt"

# Fail CLOSED only for a missing/unreadable wordlist — without it we cannot tell a
# banned reference from a clean command, so refuse to run rather than silently allow.
if [[ ! -f "$WORDLIST_PATH" ]] || [[ ! -r "$WORDLIST_PATH" ]]; then
  echo "BLOCKED: ai-reference-guard.sh cannot read its required wordlist." >&2
  echo "Reason: missing or unreadable file: $WORDLIST_PATH" >&2
  exit 2
fi

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

# ── Layer 4a: --no-verify / -n bypass of layer 2's git hooks ───────────────────────
# Unconditional — no wordlist match required, since bypassing the commit-msg/pre-commit
# hooks that already carry the banned-term scan is itself the risk, regardless of content.
# The `[^;&|]*` gap between the subcommand and the flag keeps the match scoped to the
# same shell segment, so a chained `git commit -m "msg" && git log -n 1` is not treated
# as a commit --no-verify/-n bypass. This does not parse quoting, so a flag-shaped
# substring inside a quoted message (e.g. `-m "fix -n bug"`) can still false-positive —
# an accepted over-block for a bypass guard (a missed bypass defeats the layer).
if echo "$COMMAND" | grep -qE 'git[[:space:]]+(.*[[:space:]]+)?commit[^;&|]*(--no-verify|[[:space:]]-n([[:space:]]|$))'; then
  echo "BLOCKED: Codex does not have authority to run: $COMMAND" >&2
  echo "Reason: git commit --no-verify/-n bypasses the banned-AI-reference git hooks." >&2
  echo "If you want to run this command, do it yourself in a terminal." >&2
  exit 2
fi

if echo "$COMMAND" | grep -qE 'git[[:space:]]+(.*[[:space:]]+)?push[^;&|]*--no-verify'; then
  echo "BLOCKED: Codex does not have authority to run: $COMMAND" >&2
  echo "Reason: git push --no-verify bypasses the banned-AI-reference git hooks." >&2
  echo "If you want to run this command, do it yourself in a terminal." >&2
  exit 2
fi

# ── Layer 4b: commit/PR/board commands carrying a banned AI reference ──────────────
# Only these command shapes are scanned — mere prose mentioning a banned term in an
# unrelated command (e.g. `echo "ask claude about this"`) must pass through silently.
RISKY_COMMAND_PATTERNS=(
  "git[[:space:]]+(.*[[:space:]]+)?commit([[:space:]]|$)"
  "gh[[:space:]]+pr[[:space:]]+create"
  "gh[[:space:]]+pr[[:space:]]+edit"
  "az[[:space:]]+repos[[:space:]]+pr[[:space:]]+create"
  "az[[:space:]]+repos[[:space:]]+pr[[:space:]]+update"
  "az[[:space:]]+boards"
  "az[[:space:]]+devops[[:space:]]+invoke"
)

IS_RISKY=false
for pattern in "${RISKY_COMMAND_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    IS_RISKY=true
    break
  fi
done

if $IS_RISKY; then
  # Strip comment/blank lines before using the wordlist as a grep -f pattern file —
  # grep -f treats every line as a pattern, so a raw blank line would match everything.
  if echo "$COMMAND" | grep -qEi -f <(grep -vE '^[[:space:]]*(#|$)' "$WORDLIST_PATH"); then
    echo "BLOCKED: Codex does not have authority to run: $COMMAND" >&2
    echo "Reason: this command carries a commit/PR/board reference and matches the banned AI-reference wordlist ($WORDLIST_PATH)." >&2
    echo "If you want to run this command, do it yourself in a terminal." >&2
    exit 2
  fi
fi

# Command is safe — allow it through.
exit 0
