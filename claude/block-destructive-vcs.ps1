#Requires -Version 7
# PreToolUse(Bash|PowerShell) hook: deterministically block destructive git commands that
# the advisory git-guardrails skill only *discourages*. Covers history/working-tree loss
# that git cannot trivially undo:
#   - git push --force            (clobbers a remote; --force-with-lease is allowed)
#   - git reset --hard            (discards uncommitted work)
#   - git clean -f / -fd / -fdx   (deletes untracked files)
#   - git branch -D               (force-deletes an unmerged branch)
# Scoped to git only: jj's operation log makes jj history-rewrites recoverable, so they are
# intentionally not gated here. Reads the tool-call JSON on stdin; allows silently (exit 0,
# no output) unless a destructive pattern matches, in which case it emits a deny decision.
$ErrorActionPreference = 'Stop'

$payload = [Console]::In.ReadToEnd()
if (-not $payload) { exit 0 }

try { $call = $payload | ConvertFrom-Json } catch { exit 0 }

$cmd = $call.tool_input.command
if (-not $cmd) { exit 0 }

# Drop quoted substrings before matching: a destructive phrase quoted in a message
# (git commit -m "reset --hard") must not false-match, and a quoted arg before the
# subcommand (git -C "a b" reset --hard) must not hide it. Both fall out of this scrub.
$scrubbed = $cmd -replace '"[^"]*"', '' -replace "'[^']*'", ''

# Pattern -> reason, matched case-sensitively. Each catches both short (-f / -D) and long
# (--force / --delete --force) destructive forms. Case-sensitive is required: `git branch -d`
# (safe) vs `-D` (force) differ only by case, so a case-insensitive match would deny the safe
# form too. (`git` is lowercase by universal convention, so a capitalized `Git` is not gated.)
$rules = [ordered]@{
  '\bgit\b[^\n;|&]*\bpush\b[^\n;|&]*(--force(?!-with-lease)\b|(?<![\w-])-[a-z]*f)' =
    'Blocked `git push --force` - it can clobber the remote. Use `--force-with-lease` instead.'
  '\bgit\b[^\n;|&]*\breset\b[^\n;|&]*--hard\b' =
    'Blocked `git reset --hard` - it discards uncommitted work. Stash or commit first.'
  '\bgit\b[^\n;|&]*\bclean\b[^\n;|&]*(--force\b|(?<![\w-])-[a-z]*f)' =
    'Blocked `git clean -f` - it permanently deletes untracked files. Run `git clean -n` to preview first.'
  '\bgit\b[^\n;|&]*\bbranch\b[^\n;|&]*((?<![\w-])-[a-z]*D|--delete\b[^\n;|&]*--force\b|--force\b[^\n;|&]*--delete\b)' =
    'Blocked `git branch -D` - it force-deletes an unmerged branch. Use `-d` (safe) or confirm the branch is merged.'
}

foreach ($pattern in $rules.Keys) {
  if ($scrubbed -cmatch $pattern) {
    @{
      hookSpecificOutput = @{
        hookEventName            = 'PreToolUse'
        permissionDecision       = 'deny'
        permissionDecisionReason = $rules[$pattern]
      }
    } | ConvertTo-Json -Depth 5 -Compress
    exit 0
  }
}
exit 0
