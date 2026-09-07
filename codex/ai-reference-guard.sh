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

# Read stdin (the hook payload) and extract COMMAND before the repo-scoping check below
# — repo scoping needs to inspect the command for a `-C <path>` global flag (see below),
# so the extraction has to happen first.
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

# Flattened copy for message-VALUE extraction and command-SHAPE detection, which
# genuinely need a multiline -m value (the real Claude-Session trailer shape:
# `git commit -m "feat: x\n\nCo-Authored-By: Claude"`) to pair across lines — a quoted
# span can't otherwise pair across lines under a single-line grep match. COMMAND itself
# is kept with its real embedded newlines intact for the segment-scoped checks below
# (layer 4a and the SKIP-var check), which need a newline to still act as a genuine
# segment boundary — see those checks' own comments.
COMMAND_FLAT=$(printf '%s' "$COMMAND" | tr '\n' ' ')

# ── Repo scoping: Hollard/Azure-DevOps remotes only ─────────────────────────────────
# Mirrors git/templates/hooks/pre-commit's own scoping (see its lines ~59-61): read the
# origin remote from the git command's own target, not just the hook's inherited cwd —
# `git -C <path> ...` retargets git at a different repo than cwd, and the hook must
# scope against THAT repo's origin, or a `-C`-qualified command against an in-scope repo
# run from an unrelated cwd would silently bypass every check below. When no `-C <path>`
# global flag is present, fall back to cwd's origin (the common case). If the origin
# lookup fails (not a repo, no origin) or the URL isn't both dev.azure.com AND
# HollardInsuranceRetail (case-insensitive), this is a GitHub repo (dotfiles, wiki,
# brain, ...) that legitimately says "Claude"/"Codex" in its own subject matter — ALLOW
# everything, before any check, including the fail-closed missing-wordlist check below.
# Deliberately does not track `cd <path> && ...` shell state — out of scope; only an
# explicit `-C <path>` global flag on the git invocation itself is honored.
CGIT_TOKEN='(?:"[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)'
CGIT_RAW=$(printf '%s' "$COMMAND_FLAT" | grep -oP -- 'git[[:space:]]+-C[[:space:]]+\K'"$CGIT_TOKEN" | head -1 || echo "")
CGIT_PATH="$CGIT_RAW"
if [[ "$CGIT_PATH" == \"*\" && "$CGIT_PATH" == *\" ]] || [[ "$CGIT_PATH" == \'*\' && "$CGIT_PATH" == *\' ]]; then
  CGIT_PATH="${CGIT_PATH:1:${#CGIT_PATH}-2}"
fi

if [[ -n "$CGIT_PATH" ]]; then
  origin_url=$(git -C "$CGIT_PATH" remote get-url origin 2>/dev/null) || exit 0
else
  origin_url=$(git remote get-url origin 2>/dev/null) || exit 0
fi
if ! { printf '%s' "$origin_url" | grep -qi 'dev\.azure\.com' && \
       printf '%s' "$origin_url" | grep -qi 'HollardInsuranceRetail'; }; then
  exit 0
fi

# Fail CLOSED only for a missing/unreadable wordlist — without it we cannot tell a
# banned reference from a clean command, so refuse to run rather than silently allow.
if [[ ! -f "$WORDLIST_PATH" ]] || [[ ! -r "$WORDLIST_PATH" ]]; then
  echo "BLOCKED: ai-reference-guard.sh cannot read its required wordlist." >&2
  echo "Reason: missing or unreadable file: $WORDLIST_PATH" >&2
  exit 2
fi

# ── Layer 4a: --no-verify / -n bypass of layer 2's git hooks ───────────────────────
# Unconditional — no wordlist match required, since bypassing the commit-msg/pre-commit
# hooks that already carry the banned-term scan is itself the risk, regardless of content.
# The `[^;&|\n]*` gap between the subcommand and the flag keeps the match scoped to the
# same shell segment, so a chained `git commit -m "msg" && git log -n 1` (or the same
# shape newline-chained, the shape Codex actually emits for sequential commands) is not
# treated as a commit --no-verify/-n bypass — newline is excluded from the gap alongside
# `;`/`&`/`|` so a `commit` on one line can't reach across into an unrelated `-n` on the
# next line. This does not parse quoting, so a flag-shaped substring inside a quoted
# message (e.g. `-m "fix -n bug"`) can still false-positive — an accepted over-block for
# a bypass guard (a missed bypass defeats the layer).
#
# `-n` is detected as part of ANY dash-prefixed short-flag cluster containing the letter
# `n` (e.g. `-nm`, clustering --no-verify's short form with -m's), not just an isolated
# `-n` token — `git commit -nm "msg"` is valid git and must be caught the same as
# `git commit -n -m "msg"`. Run against COMMAND (real embedded newlines, not flattened)
# via `grep -Pzq`, which treats the whole (NUL-free) input as one buffer instead of
# splitting on newlines, so the `\n` in the gap/anchor patterns below can do real work.
if printf '%s' "$COMMAND" | grep -Pzq -- 'git[[:space:]]+(.*[[:space:]]+)?commit[^;&|\n]*(--no-verify|[[:space:]]-[a-zA-Z]*n[a-zA-Z]*([[:space:]]|$))'; then
  echo "BLOCKED: Codex does not have authority to run: $COMMAND_FLAT" >&2
  echo "Reason: git commit --no-verify/-n bypasses the banned-AI-reference git hooks." >&2
  echo "If you want to run this command, do it yourself in a terminal." >&2
  exit 2
fi

if printf '%s' "$COMMAND" | grep -Pzq -- 'git[[:space:]]+(.*[[:space:]]+)?push[^;&|\n]*--no-verify'; then
  echo "BLOCKED: Codex does not have authority to run: $COMMAND_FLAT" >&2
  echo "Reason: git push --no-verify bypasses the banned-AI-reference git hooks." >&2
  echo "If you want to run this command, do it yourself in a terminal." >&2
  exit 2
fi

# SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS=1 is git/templates/hooks/{commit-msg,pre-commit}'s own
# human bypass hatch (matching the existing SKIP_GITLEAKS convention). Codex invoking a Bash
# command can set either var just as easily as a human, silently defeating layer 2's scan.
# Anchored to an actual shell-assignment shape (command start, right after a `;`/`&&`/`|`
# separator, right after a newline (a newline-chained command, e.g. Codex emitting
# `true\nSKIP_AI_REFERENCE_SCAN=1 git commit ...` as two lines), or `export `/`env `),
# value `1` unquoted or quoted with `'1'`/`"1"` — not a bare substring match anywhere in
# the command, which would both miss a quoted value (the real git hooks'
# `[ "$SKIP_GITLEAKS" = "1" ]` shell check strips the quotes) and over-match unrelated
# prose that merely mentions the variable. Run via `grep -Pzq` against COMMAND (real
# embedded newlines) for the same reason as the no-verify checks above.
SKIP_VAR_RE='(^|[;&|]+[[:space:]]*|export[[:space:]]+|env[[:space:]]+|\n[[:space:]]*)SKIP_(AI_REFERENCE_SCAN|GITLEAKS)=(1|'\''1'\''|"1")([[:space:]]|$)'
if printf '%s' "$COMMAND" | grep -Pzq -- "$SKIP_VAR_RE"; then
  echo "BLOCKED: Codex does not have authority to run: $COMMAND_FLAT" >&2
  echo "Reason: SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS bypasses the banned-AI-reference git hooks." >&2
  echo "If you want to run this command, do it yourself in a terminal." >&2
  exit 2
fi

# ── Layer 4b: commit/PR/board commands carrying a banned AI reference ──────────────
# Only these command shapes are scanned — mere prose mentioning a banned term in an
# unrelated command (e.g. `echo "ask claude about this"`) must pass through silently.
# Matched against COMMAND_FLAT (flattened), not the newline-preserving COMMAND — shape
# detection isn't segment-sensitive the way layer 4a is, and flattening keeps a shape
# spanning a multiline -m value detectable.
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
  if echo "$COMMAND_FLAT" | grep -qE "$pattern"; then
    IS_RISKY=true
    break
  fi
done

if $IS_RISKY; then
  # Scope the wordlist scan to message-bearing ARGUMENT VALUES only — the content of
  # -m (and any clustered short flag ending in `m`, e.g. `-am`/`-nm`)/--message/
  # --title/--body/--description/--discussion/--text — instead of the whole $COMMAND
  # string. Matching against the whole command also matches a banned word inside an
  # unrelated file path (e.g. `\bCodex\b` inside `codex/ai-reference-guard.sh`, or
  # `\bClaude\b` inside `claude/settings.json`), which would self-block routine commits
  # in this very repo. Both double- and single-quoted values are captured (handling an
  # internal escaped `"`), as well as a bare unquoted token; `\K` drops the
  # flag+separator from the match so only the value text is scanned. `|| echo ""` keeps
  # this non-fatal under `set -euo pipefail` when none of the flags are present in a
  # risky command. Matched against COMMAND_FLAT (flattened) so a multiline -m value
  # still pairs across its original line break.
  #
  # VALUE_TOKEN matches one shell-word: a run of (quoted spans OR single non-space
  # chars). This handles a fully-quoted value ("thanks Claude"), a bare unquoted
  # token (id=1), AND a `key="quoted value with spaces"` shape (e.g. az's
  # `--query-parameters text="thanks Claude"`) where only PART of the token is
  # quoted — a plain `[^[:space:]]+` alone stops at the first real space, which is
  # inside the quotes for that last shape and would silently drop everything after it.
  VALUE_TOKEN='(?:"(?:[^"\\]|\\.)*"|'"'"'[^'"'"']*'"'"'|[^[:space:]])+'
  MESSAGE_VALUE_FLAGS='-[a-zA-Z]*m|--message|--title|--body|--description|--discussion|--text'
  MESSAGE_VALUES=$(echo "$COMMAND_FLAT" | grep -oP -- '(?:^|[[:space:]])(?:'"$MESSAGE_VALUE_FLAGS"')(?:[[:space:]]+|=)\K'"$VALUE_TOKEN" || echo "")

  # gh's short `-t`/`-b` forms mean "title"/"body" only for `gh pr create`/`gh pr edit`
  # — those same letters mean something else for other commands, so this extraction is
  # deliberately scoped to that command shape rather than added to the general list above.
  if echo "$COMMAND_FLAT" | grep -qE 'gh[[:space:]]+pr[[:space:]]+(create|edit)'; then
    GH_TITLE_BODY_VALUES=$(echo "$COMMAND_FLAT" | grep -oP -- '(?:^|[[:space:]])(?:-t|-b)(?:[[:space:]]+|=)\K'"$VALUE_TOKEN" || echo "")
    MESSAGE_VALUES=$(printf '%s\n%s' "$MESSAGE_VALUES" "$GH_TITLE_BODY_VALUES")
  fi

  # --fields/--route-parameters/--query-parameters carry a run of space-separated
  # key=value pairs, not a single value (e.g. az boards' `--fields A=x B=y`) — capture
  # the WHOLE run so a banned term in the second (or later) pair isn't missed. Each
  # pair is one VALUE_TOKEN (so a `key="quoted value"` pair still pairs correctly); the
  # run continues with `(?:[[:space:]]+VALUE_TOKEN)*` and stops at the next `-`-prefixed
  # flag, a shell separator, or end of command — VALUE_TOKEN's own single-non-space-char
  # alternative would otherwise happily also swallow a following flag like
  # `--http-method`, so each repeated pair is guarded by a `(?!-)` lookahead that
  # refuses to start a new pair on a literal `-`. Ported from the equivalent
  # multiValuePattern in pi/extensions/ai-reference-guard.ts.
  MULTI_VALUE_FLAGS='--fields|--route-parameters|--query-parameters'
  MULTI_VALUES=$(echo "$COMMAND_FLAT" | grep -oP -- '(?:^|[[:space:]])(?:'"$MULTI_VALUE_FLAGS"')(?:[[:space:]]+|=)\K'"$VALUE_TOKEN"'(?:[[:space:]]+(?!-)'"$VALUE_TOKEN"')*' || echo "")
  MESSAGE_VALUES=$(printf '%s\n%s' "$MESSAGE_VALUES" "$MULTI_VALUES")

  # Strip comment/blank lines before using the wordlist as a grep -f pattern file —
  # grep -f treats every line as a pattern, so a raw blank line would match everything.
  if [[ -n "$MESSAGE_VALUES" ]] && echo "$MESSAGE_VALUES" | grep -qEi -f <(grep -vE '^[[:space:]]*(#|$)' "$WORDLIST_PATH"); then
    echo "BLOCKED: Codex does not have authority to run: $COMMAND_FLAT" >&2
    echo "Reason: this command carries a commit/PR/board reference and matches the banned AI-reference wordlist ($WORDLIST_PATH)." >&2
    echo "If you want to run this command, do it yourself in a terminal." >&2
    exit 2
  fi
fi

# Command is safe — allow it through.
exit 0
