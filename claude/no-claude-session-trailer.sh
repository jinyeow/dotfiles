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
#   4. Azure Pipelines: `az pipelines ...` (pipeline descriptions and settings).
#
# Independently of the wordlist, any git command using `--no-verify` (or `git commit` using the
# `-n` short form) is denied outright: that flag bypasses this repo's git hooks (layer 2), and
# this hook is the backstop against that bypass. `git push -n` is deliberately NOT included in
# that short-form check: push's own `-n` means `--dry-run`, not `--no-verify` — there is no `-n`
# short form for push's no-verify, so `git push -n` is a legitimate, harmless command.
#
# The `git ... commit` matcher allows each leading global flag to carry an argument (git -C
# <path> commit, git -c k=v commit): a unit is `-flag` optionally followed by one argument
# token — a bare non-flag token, or a quoted (possibly multi-word) token such as
# `-C "C:/Work Repo"` — so a flag WITH an argument can't slip between `git` and `commit`
# and evade the check.
#
# Scoped to work repos only, mirroring git/templates/hooks/pre-commit's own scoping:
# `git config --type=bool --get work.aiReferenceScan`, run against the command's actual git
# target, must print `true`. git/gitconfig-work sets that key, and the [includeIf] blocks in
# the untracked ~/.gitconfig.local load that file for the work repos, with or without a remote.
# If the key is unset, false or not a boolean, or the target isn't a repo at all (GitHub repos
# such as dotfiles, wiki and brain legitimately say "Claude"/"Codex" in their own subject
# matter), every check below is skipped: the wordlist scan, the --no-verify/-n denies, and the
# SKIP_*-env-var denies alike.
#
# The command's actual git target is not always this hook's inherited cwd: `git -C <path> ...`,
# `--git-dir` and `--work-tree` retarget git at a different repo, so the key lookup must follow
# them there rather than reading cwd's config. The target comes from the first `git` invocation
# whose subcommand is `commit` or `push`; with neither present, from the first `git` invocation
# whose own shell segment carries `--no-verify` (denied below for any git subcommand). That
# invocation's leading global options are walked up to the subcommand: `-C`, `-c`, `--git-dir`,
# `--work-tree` and `--namespace` consume the next token as their value, and every other
# `-x`/`--x=y` option is one token. An unquoted `&&`, `||`, `;`, `|` or `&` ends a token and the
# walk even with no surrounding spaces (`git status&&git commit`); inside quotes it does not.
# Every `-C`, `--git-dir` and `--work-tree` in that run (both the `--opt value` and
# `--opt=value` forms) is passed on to the lookup in its original order, so git resolves them
# exactly as for the real command (each `-C` relative to the previous one). Options that belong
# to another command in the same line are ignored. With none of them on that invocation, or no
# such invocation, cwd's config is used.
# `cd <path> && git ...` shell-state tracking is a known, separate, accepted limitation — not
# attempted here.
cmd=$(jq -r '.tool_input.command // ""')

c_path_token_re='(("([^"\\]|\\.)*"|'"'"'[^'"'"']*'"'"'|[^[:space:];&|"'"'"'])+|[;&|]+)'
no_verify_segment_re=$'^[^;&|\n]*--no-verify'

# `git -C <path>` accepts a shell-quoted path (e.g. `-C "."`), but the captured token still
# carries its literal quotes — remove them the way a shell would, so the key lookup below
# targets the real path instead of a literal `".\"`-shaped string that always fails and (via
# the `|| exit 0` fallback) lets the whole guarded command through. The token can join several
# quoted and bare fragments (`"/tmp/scoped"repo` is `/tmp/scopedrepo` to git), so each fragment
# is unquoted and the results are concatenated. Inside double quotes `\"` and `\\` are escapes;
# inside single quotes nothing escapes; bare fragments stay as they are. An unbalanced quote is
# kept literally. `$VAR`, `~` and globs are not expanded, the same accepted limitation as the
# `cd <path> &&` case noted above. Mirrors codex/ai-reference-guard.sh's equivalent unquoting.
c_unquote() {
  local rest="$1" out="" fragment
  local dq_re='^"(([^"\\]|\\.)*)"(.*)$' sq_re="^'([^']*)'(.*)$" bare_re='^([^"'"'"']+)(.*)$'
  while [[ -n "$rest" ]]; do
    if [[ "$rest" =~ $dq_re ]]; then
      fragment="${BASH_REMATCH[1]}"
      rest="${BASH_REMATCH[3]}"
      fragment="${fragment//\\\\/$'\x01'}"
      fragment="${fragment//\\\"/\"}"
      out+="${fragment//$'\x01'/\\}"
    elif [[ "$rest" =~ $sq_re ]]; then
      out+="${BASH_REMATCH[1]}"
      rest="${BASH_REMATCH[2]}"
    elif [[ "$rest" =~ $bare_re ]]; then
      out+="${BASH_REMATCH[1]}"
      rest="${BASH_REMATCH[2]}"
    else
      out+="$rest"
      break
    fi
  done
  printf '%s' "$out"
}

c_args=()
c_have_fallback=false
c_rest="$cmd"
while [[ "$c_rest" =~ (^|[^[:alnum:]_.-])git([[:space:]].*)$ ]]; do
  c_rest="${BASH_REMATCH[2]}"
  c_run_args=()
  c_subcommand=""
  while [[ "$c_rest" =~ ^[[:space:]]*${c_path_token_re}(.*)$ ]]; do
    c_option="${BASH_REMATCH[1]}"
    c_rest="${BASH_REMATCH[4]}"
    case "$c_option" in
      [\;\&\|]*) break ;;
      -C|-c|--git-dir|--work-tree|--namespace)
        [[ "$c_rest" =~ ^[[:space:]]*${c_path_token_re}(.*)$ ]] || break
        c_value="${BASH_REMATCH[1]}"
        c_rest="${BASH_REMATCH[4]}"
        [[ "$c_value" == [\;\&\|]* ]] && break
        case "$c_option" in
          -C|--git-dir|--work-tree) c_run_args+=("$c_option" "$(c_unquote "$c_value")") ;;
        esac
        ;;
      --git-dir=*|--work-tree=*) c_run_args+=("${c_option%%=*}=$(c_unquote "${c_option#*=}")") ;;
      -*) ;;
      *)
        c_subcommand="$c_option"
        break
        ;;
    esac
  done
  if [[ "$c_subcommand" == "commit" || "$c_subcommand" == "push" ]]; then
    c_args=("${c_run_args[@]}")
    break
  fi
  if ! $c_have_fallback && [[ -n "$c_subcommand" && "$c_rest" =~ $no_verify_segment_re ]]; then
    c_args=("${c_run_args[@]}")
    c_have_fallback=true
  fi
done

if (( ${#c_args[@]} )); then
  ai_reference_scan=$(git "${c_args[@]}" config --type=bool --get work.aiReferenceScan 2>/dev/null) || exit 0
else
  ai_reference_scan=$(git config --type=bool --get work.aiReferenceScan 2>/dev/null) || exit 0
fi
[[ "$ai_reference_scan" == "true" ]] || exit 0

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

# A leading global flag's optional argument token: a double- or single-quoted (possibly
# multi-word) value, or a bare non-flag token — mirrors c_path_token_re
# above so `git -C "C:/Work Repo" commit ...` doesn't stop matching mid-quote (a quoted
# multi-word -C value used to break commit_re/commit_dashn_re/skip_commit_re entirely, since
# the old `[^-][^[:space:]]*` alternative only consumed one non-whitespace token).
#
# The bare-token alternative excludes a leading `"`/`'` (not just `-`): without that exclusion
# it could match just the opening quote of an unbalanced-looking quoted value (e.g. the `"x` in
# `-c "x commit y"`), leaving the rest of the quoted value unconsumed and free for commit_re's
# trailing `commit\b` to match a literal "commit" that is actually INSIDE that flag's own value,
# not a real `git commit`. Excluding the quote characters forces such a token through one of the
# two full-quoted alternatives instead; if the quote is genuinely unbalanced, the match attempt
# simply fails there — never allowed to match, which is the safe direction.
#
# The token can also join quoted and bare fragments (`-C "/tmp/scoped"repo`, one word to the
# shell), so the first fragment may be followed by more quoted or bare fragments. A bare
# fragment never contains a quote character, which keeps the unbalanced-quote rule above.
flag_arg_token_re='(("[^"]*"|'"'"'[^'"'"']*'"'"'|[^-"'"'"'[:space:]][^[:space:]"'"'"']*)("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]"'"'"']+)*)'
flag_group="([[:space:]]+-[^[:space:]]+([[:space:]]+${flag_arg_token_re})?)*"
commit_re="\\bgit\\b${flag_group}[[:space:]]+commit\\b"
pr_re='\bgh\b[[:space:]]+pr[[:space:]]+(create|edit)\b|\baz\b[[:space:]]+repos[[:space:]]+pr[[:space:]]+(create|update)\b'
gh_pr_re='\bgh\b[[:space:]]+pr[[:space:]]+(create|edit)\b'
boards_re='\baz\b[[:space:]]+boards\b|\baz\b[[:space:]]+devops[[:space:]]+invoke\b|\baz\b[[:space:]]+pipelines\b'

# `-n`/SKIP-var bound: `[^;&|]*` between the guarded subcommand and the flag/assignment keeps
# the match scoped to one shell segment, mirroring codex/ai-reference-guard.sh's equivalent
# `[^;&|]*` gap — so `git commit -m "fix" && git log -n 1` (or `&& git push -n origin main`)
# isn't treated as `git commit -n`, and `SKIP_GITLEAKS=1 rg foo && git log -n 1` (SKIP_GITLEAKS
# assigned in an unrelated earlier segment) isn't treated as a bypass of a git commit that
# never appears in that same segment.
#
# The `-n` flag itself is matched as part of ANY dash-prefixed short-flag cluster containing
# the letter n (`-[a-zA-Z]*n[a-zA-Z]*`), not just an isolated `-n` token: `git commit -nm "..."`
# clusters `-n` with `-m`, which is valid git and was not previously caught by an isolated-`-n`
# match. Requiring the cluster to start with a single `-` (immediately followed by a letter or
# `n`, never another `-`) keeps this from matching `--no-verify`/`--dry-run`-shaped long options,
# which are handled by the separate `--no-verify` check above.
commit_dashn_re="${commit_re}[^;&|]*[[:space:]]-[a-zA-Z]*n[a-zA-Z]*([[:space:]]|\$)"
# SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS=1 assignment shape: at the start of the command or a
# shell segment, or after `export `/`env `, matching either an unquoted `1` or a single-/
# double-quoted `'1'`/`"1"` (the git hooks' own `[ "$SKIP_GITLEAKS" = "1" ]` check treats both
# the same way, since the shell strips the quotes) — not a bare substring match, so a command
# that merely mentions the literal string in unrelated prose (e.g. `rg 'SKIP_GITLEAKS=1'
# README.md`) doesn't match this shape at all.
#
# Split into two shapes with different segment-boundedness: a plain/prefix assignment
# (`SKIP_GITLEAKS=1 rg foo && ...`) only affects the single command it prefixes, so it stays
# segment-bound to the guarded `git ... commit` via `[^;&|]*` (unchanged from before). An
# `export`/`env`-prefixed assignment persists forward across `&&`/`;` for the rest of the SAME
# bash invocation, so `export SKIP_AI_REFERENCE_SCAN=1 && git commit ...` must still be caught
# even though the assignment and the guarded commit sit in different segments — that shape is
# matched anywhere in the whole command instead, still anchored to a real `export `/`env `
# assignment shape (not a bare substring) so unrelated prose still passes.
skip_plain_assign_re="(^|[;&|][[:space:]]*)SKIP_(AI_REFERENCE_SCAN|GITLEAKS)=['\"]?1\\b"
skip_export_assign_re="(export|env)[[:space:]]+SKIP_(AI_REFERENCE_SCAN|GITLEAKS)=['\"]?1\\b"
skip_commit_re="${skip_plain_assign_re}[^;&|]*${commit_re}"

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
  if matches "$skip_commit_re" || { matches "$skip_export_assign_re" && matches "$commit_re"; }; then
    deny "SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS bypasses this repo's git hooks (layer 2) — not allowed from an agent."
  fi
fi

# Message content the wordlist is matched against: the value of every recognized message-
# bearing flag (-m/-am/-nm/etc./--message/--title/--body/--description/--discussion/--text,
# plus --fields/--route-parameters/--query-parameters and (for `gh pr create`/`gh pr edit`
# only) -t/-b below), quoted or unquoted — not a blanket scan of every quoted span in the
# command, and not the whole raw command string. A banned term always arrives via one of these
# flags; scanning every quoted span would also catch quoted content attached to an unrelated
# flag (e.g. `git -C "claude-project" commit -m "fix"`), and matching the whole raw command
# would false-positive on this repo's own path segments (e.g. `claude/settings.json`,
# `codex/ai-reference-guard.sh`), which contain the bare words "claude"/"codex" outside any
# message. An optional `key=` prefix before the value handles the key=value shape some of these
# flags use. The quoted-value alternatives are escape-aware (`(?:[^"\\]|\\.)*`, requiring PCRE
# via `grep -P`) so an escaped inner quote (`-m "say \"Claude \" less please"`) doesn't truncate
# the match at the first literal `"` — the naive `[^"]*` grep -E form used to stop there and
# never see the banned term. Real newlines inside a quoted `-m` value (the actual trailer shape:
# `git commit -m "feat: x\n\nCo-Authored-By: Claude"`) are flattened to spaces first, since a
# quoted span can't otherwise pair across lines under a single-line grep match.
#
# `-m`'s short flag is matched as `-[A-Za-z]*m` (not a literal `-m`/`-am` alternation) so it is
# still found when clustered with other short flags in any order/combination, e.g. `-nm`/`-am`/
# `-sm` — mirroring codex/ai-reference-guard.sh and pi/extensions/ai-reference-guard.ts's own
# `-[A-Za-z]*m` handling — so the wordlist check still fires on a clustered `-m` even when the
# cluster also carries `-n`.
flat_cmd=$(printf '%s' "$cmd" | tr '\n' ' ')
message_flag_re='(?:^|[[:space:]])(?:-[A-Za-z]*m|--message|--title|--body|--description|--discussion|--text)(?:[[:space:]]+|=)\K(?:[A-Za-z0-9_.-]+=)?("(?:[^"\\]|\\.)*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)'
message_content=$(printf '%s' "$flat_cmd" | grep -oP -- "$message_flag_re")

# --fields/--route-parameters/--query-parameters take a run of space-separated `key=value`
# pairs (e.g. `az boards work-item update --fields System.Title=ok
# "System.Description=Thanks Claude"`), not just a single value — the whole run is captured,
# stopping at the next `-`-prefixed flag, a shell separator (`;`/`&`/`|`), or end of command, so
# a banned term in the SECOND (or later) pair isn't missed. Ported from
# pi/extensions/ai-reference-guard.ts's `multiValuePattern`.
value_token_re='(?:"(?:[^"\\]|\\.)*"|'"'"'[^'"'"']*'"'"'|[^[:space:]"'"'"';&|-]\S*)'
multi_value_flag_re="(?:^|[[:space:]])(?:--fields|--route-parameters|--query-parameters)(?=[=[:space:]])(?:=|[[:space:]]+)\\K${value_token_re}(?:[[:space:]]+${value_token_re})*"
multi_value_content=$(printf '%s' "$flat_cmd" | grep -oP -- "$multi_value_flag_re")
message_content=$(printf '%s\n%s' "$message_content" "$multi_value_content")

# `gh pr create`/`gh pr edit`'s short `-t`/`-b` forms mean "title"/"body" only for that command
# shape — those same letters mean something else for other commands (e.g. git commit's `-t
# <template-file>`), so this extraction is deliberately scoped to `gh pr create|edit` rather
# than added to the general message_flag_re above, mirroring codex/ai-reference-guard.sh and
# pi/extensions/ai-reference-guard.ts's own scoping.
if matches "$gh_pr_re"; then
  gh_title_body_re='(?:^|[[:space:]])(?:-t|-b)(?:[[:space:]]+|=)\K(?:[A-Za-z0-9_.-]+=)?("(?:[^"\\]|\\.)*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)'
  gh_title_body_content=$(printf '%s' "$flat_cmd" | grep -oP -- "$gh_title_body_re")
  message_content=$(printf '%s\n%s' "$message_content" "$gh_title_body_content")
fi

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
