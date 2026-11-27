#!/bin/bash
# block-dangerous-git.sh
# Codex CLI PreToolUse hook — blocks dangerous git commands before execution.
# The rules now live in ai-agents/_shared/destructive-git-rules.json, shared with the Claude
# (claude/block-destructive-vcs.ps1) and Pi (pi/extensions/git-guardrails.ts) guards so the
# three runtimes cannot drift. Only rules whose `runtimes` list includes "codex" apply here.
#
# Install:
#   Copied to ~/.codex/block-dangerous-git.sh by `setup.ps1 -Module codex`. The rules file
#   must be copied alongside it as ~/.codex/destructive-git-rules.json.
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
#
# Failure modes: payload problems (unparseable, no command) fail open. A missing, unreadable
# or invalid rules file, or no perl to evaluate it, fails CLOSED, but only for commands that
# mention git, so a broken install cannot silently disable the guardrail. Perl is used for
# matching because the shared rules use lookaround (outside POSIX ERE); it ships with Git for
# Windows (the bash that runs this hook) and with standard Linux installs.

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

if [ -z "$COMMAND" ]; then
  exit 0
fi

block() {
  echo "BLOCKED: Codex does not have authority to run: $COMMAND" >&2
  echo "Reason: $1" >&2
  echo "If you want to run this command, do it yourself in a terminal." >&2
  exit 2
}

# ── Rules file ────────────────────────────────────────────────────────────────
# Installed sibling first, then the repository copy (running from the repo), then $DOTFILES.
RULES_NAME="destructive-git-rules.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_CANDIDATES=("$SCRIPT_DIR/$RULES_NAME" "$SCRIPT_DIR/../ai-agents/_shared/$RULES_NAME")
if [ -n "${DOTFILES:-}" ]; then
  RULES_CANDIDATES+=("$DOTFILES/ai-agents/_shared/$RULES_NAME")
fi
RULES_PATH=""
for candidate in "${RULES_CANDIDATES[@]}"; do
  if [ -f "$candidate" ]; then
    RULES_PATH="$candidate"
    break
  fi
done

# Quote scrubbing and matching, mirroring claude/block-destructive-vcs.ps1: each double-quoted
# (escape-aware) or single-quoted span, in one alternation, is deleted unless it matches the
# shared keepQuoted pattern, in which case it is unquoted in place. Rules then match in order,
# case-sensitively. Exit 0 = allow, 3 = blocked (reason on stdout), 4 = rules unusable.
# shellcheck disable=SC2016 # Perl source, not shell expansions.
PERL_MATCH='
use strict; use warnings; use JSON::PP;
my ($path, $runtime) = @ARGV;
my $cmd = $ENV{GUARD_COMMAND};
open(my $fh, "<", $path) or exit 4;
my $raw = do { local $/; <$fh> };
close $fh;
my $data = eval { JSON::PP->new->decode($raw) };
exit 4 unless ref $data eq "HASH" && ref $data->{rules} eq "ARRAY" && defined $data->{keepQuoted};
my $keep = eval { qr/$data->{keepQuoted}/ } or exit 4;
my @rules;
for my $rule (@{ $data->{rules} }) {
  next unless ref $rule->{runtimes} eq "ARRAY" && grep { $_ eq $runtime } @{ $rule->{runtimes} };
  my $re = eval { qr/$rule->{pattern}/ } or exit 4;
  push @rules, [$re, $rule->{reason}];
}
(my $scrubbed = $cmd) =~ s{"((?:\\.|[^"\\])*)"|\x27([^\x27]*)\x27}{
  my $inner = defined $1 ? $1 : $2;
  $inner =~ $keep ? $inner : "";
}ge;
for my $rule (@rules) {
  if ($scrubbed =~ $rule->[0]) { print $rule->[1]; exit 3; }
}
exit 0;
'

mentions_git() {
  echo "$COMMAND" | grep -qE '(^|[^[:alnum:]_])git([^[:alnum:]_]|$)'
}

if [ -z "$RULES_PATH" ] || ! command -v perl &>/dev/null; then
  if mentions_git; then
    block "the dangerous-git guardrail cannot load its rules ($RULES_NAME not found in: ${RULES_CANDIDATES[*]}, or perl is missing), so git commands are refused until it is restored."
  fi
  exit 0
fi

status=0
REASON=$(GUARD_COMMAND="$COMMAND" perl -e "$PERL_MATCH" "$RULES_PATH" codex 2>/dev/null) || status=$?
case "$status" in
  0) exit 0 ;;
  3) block "$REASON" ;;
  *)
    if mentions_git; then
      block "the dangerous-git guardrail cannot read $RULES_PATH (unreadable or invalid), so git commands are refused until it is restored."
    fi
    exit 0
    ;;
esac
