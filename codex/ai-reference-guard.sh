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
  # Naive extraction — good enough for single-line commands. The previous
  # `[^"]*`-based value pattern didn't understand JSON's own backslash escaping and
  # stopped at the FIRST literal `"` it saw — including a JSON-escaped `\"` that is
  # only the middle of an internally-quoted bash message (e.g. `-m "she said \"hi\""`).
  # That silently truncated COMMAND before any banned term appearing after the escaped
  # quote, so the scan below would pass even though the term was present. This PCRE
  # pattern instead consumes `\"`/`\\` escape pairs (`\\.`) as part of the string
  # content, so it only stops at the real closing quote; `\K` drops the `"command":"`
  # prefix from the extracted match so only the (still JSON-escaped) value is captured.
  # The sed pass then un-escapes `\"` -> `"` and `\\` -> `\`, matching what
  # `json.load` would have produced (other JSON escapes, e.g. `\n`, are left literal —
  # out of scope for a single-line shell command). `|| echo ""` keeps this non-fatal
  # under `set -euo pipefail` when no "command" key matches (malformed JSON or a
  # command-less payload), so the hook falls through to allow rather than crashing.
  RAW_COMMAND=$(echo "$INPUT" | grep -oP '"command"[[:space:]]*:[[:space:]]*"\K(?:[^"\\]|\\.)*' | head -1 || echo "")
  COMMAND=$(printf '%s' "$RAW_COMMAND" | sed 's/\\\\/\x01/g; s/\\"/"/g; s/\x01/\\/g')
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

# SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS=1 is git/templates/hooks/{commit-msg,pre-commit}'s own
# human bypass hatch (matching the existing SKIP_GITLEAKS convention). Codex invoking a Bash
# command can set either var just as easily as a human, silently defeating layer 2's scan.
if echo "$COMMAND" | grep -qE '\bSKIP_AI_REFERENCE_SCAN=1\b|\bSKIP_GITLEAKS=1\b'; then
  echo "BLOCKED: Codex does not have authority to run: $COMMAND" >&2
  echo "Reason: SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS bypasses the banned-AI-reference git hooks." >&2
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
  # Scope the wordlist scan to message-bearing ARGUMENT VALUES only — the content of
  # -m/--message/--title/--body/--description/--fields/--route-parameters — instead of
  # the whole $COMMAND string. Matching against the whole command also matches a banned
  # word inside an unrelated file path (e.g. `\bCodex\b` inside
  # `codex/ai-reference-guard.sh`, or `\bClaude\b` inside `claude/settings.json`), which
  # would self-block routine commits in this very repo. Both double- and single-quoted
  # values are captured (handling an internal escaped `"`), as well as a bare unquoted
  # token; `\K` drops the flag+separator from the match so only the value text is
  # scanned. `|| echo ""` keeps this non-fatal under `set -euo pipefail` when none of
  # the flags are present in a risky command.
  MESSAGE_VALUES=$(echo "$COMMAND" | grep -oP -- '(?:^|[[:space:]])(?:-m|--message|--title|--body|--description|--fields|--route-parameters)(?:[[:space:]]+|=)\K("(?:[^"\\]|\\.)*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)' || echo "")

  # Strip comment/blank lines before using the wordlist as a grep -f pattern file —
  # grep -f treats every line as a pattern, so a raw blank line would match everything.
  if [[ -n "$MESSAGE_VALUES" ]] && echo "$MESSAGE_VALUES" | grep -qEi -f <(grep -vE '^[[:space:]]*(#|$)' "$WORDLIST_PATH"); then
    echo "BLOCKED: Codex does not have authority to run: $COMMAND" >&2
    echo "Reason: this command carries a commit/PR/board reference and matches the banned AI-reference wordlist ($WORDLIST_PATH)." >&2
    echo "If you want to run this command, do it yourself in a terminal." >&2
    exit 2
  fi
fi

# Command is safe — allow it through.
exit 0
