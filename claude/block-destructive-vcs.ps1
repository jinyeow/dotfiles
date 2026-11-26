#Requires -Version 7
# PreToolUse(Bash|PowerShell) hook: deterministically block destructive git commands.
# Covers history/working-tree loss that git cannot trivially undo:
#   - git push --force / +<refspec>  (clobbers a remote; --force-with-lease is allowed)
#   - git reset --hard               (discards uncommitted work)
#   - git clean -f / -fd / -fdx      (deletes untracked files)
#   - git branch -D                  (force-deletes an unmerged branch)
#   - git checkout -- . / git restore .  (discards every unstaged change)
# Scoped to git only: jj's operation log makes jj history-rewrites recoverable, so they are
# intentionally not gated here. Reads the tool-call JSON on stdin; allows silently (exit 0,
# no output) unless a destructive pattern matches, in which case it emits a deny decision.
#
# The rules live in ai-agents/_shared/destructive-git-rules.json, shared with the Codex
# (codex/block-dangerous-git.sh) and Pi (pi/extensions/git-guardrails.ts) guards so the three
# runtimes cannot drift. Only rules whose `runtimes` list includes "claude" apply here.
# Lookup order: a sibling destructive-git-rules.json (the installed ~/.claude layout), then the
# repository copy next to this script's symlink target, then the repository copy relative to
# this script (running from the repo), then $env:DOTFILES. Payload problems (empty, malformed,
# no command) fail open. A missing, unreadable or invalid rules file fails CLOSED, but only
# for commands that mention git, so a broken install cannot silently disable the guard.
#
# Bash calls also run claude/block-pwsh-in-bash.ps1 in this same process (a sibling script,
# fed the same payload), so a Bash call spawns one pwsh hook process instead of two. A
# destructive-git deny is reported first; the pwsh-in-bash check runs only when this hook
# allows. That check keeps its own fail-open behaviour and is skipped if the sibling is absent.
$ErrorActionPreference = 'Stop'

$payload = [Console]::In.ReadToEnd()
if (-not $payload) { exit 0 }

try { $call = $payload | ConvertFrom-Json } catch { exit 0 }

$cmd = $call.tool_input.command
if (-not $cmd) { exit 0 }

function Write-Deny([string] $Reason)
{
    @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'deny'
            permissionDecisionReason = $Reason
        }
    } | ConvertTo-Json -Depth 5 -Compress
}

# Path work uses .NET calls, not Join-Path/Test-Path/Get-Content: those cmdlets autoload the
# Microsoft.PowerShell.Management module, which measurably adds to every hook invocation.
$rulesName = 'destructive-git-rules.json'
$sharedRel = [System.IO.Path]::Combine('..', 'ai-agents', '_shared', $rulesName)
$candidates = [System.Collections.Generic.List[string]]::new()
$candidates.Add([System.IO.Path]::Combine($PSScriptRoot, $rulesName))
try
{
    $linkTarget = ([System.IO.FileInfo]::new($PSCommandPath)).ResolveLinkTarget($true)
    if ($linkTarget)
    {
        $candidates.Add([System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($linkTarget.FullName), $sharedRel))
    }
}
catch { $null = $_ }
$candidates.Add([System.IO.Path]::Combine($PSScriptRoot, $sharedRel))
if ($env:DOTFILES) { $candidates.Add([System.IO.Path]::Combine($env:DOTFILES, 'ai-agents', '_shared', $rulesName)) }

$rulesPath = $null
foreach ($candidate in $candidates)
{
    if ([System.IO.File]::Exists($candidate)) { $rulesPath = $candidate; break }
}
$keep = $null
$rules = $null
if ($rulesPath)
{
    try
    {
        $data = [System.IO.File]::ReadAllText($rulesPath) | ConvertFrom-Json
        # A null, missing, empty or non-array rules list is invalid, so it takes the fail-closed path.
        if (-not ($data.rules -is [array] -and $data.rules.Count -gt 0))
        {
            throw [System.IO.InvalidDataException]::new("'rules' must be a non-empty array in $rulesPath")
        }
        $keep = [regex]::new([string]$data.keepQuoted)
        $rules = @(foreach ($rule in @($data.rules))
            {
                if (@($rule.runtimes) -contains 'claude')
                {
                    [pscustomobject]@{ Regex = [regex]::new([string]$rule.pattern); Reason = [string]$rule.reason }
                }
            })
    }
    catch
    {
        $rules = $null
    }
}

if ($null -eq $rules -or $null -eq $keep)
{
    if ($cmd -cmatch '\bgit\b')
    {
        $tried = if ($rulesPath) { "$rulesPath (unreadable or invalid)" } else { $candidates -join ', ' }
        Write-Deny ("Blocked: the destructive-git guard cannot load its shared rules file " +
            "($rulesName; tried $tried), so git commands are refused until it is restored. " +
            "Re-run setup for the claude module. If you want to run it yourself, type: ! $cmd")
    }
    exit 0
}

# Scrub quoted substrings before matching. Two goals at once:
#   - a destructive phrase quoted in a message (git commit -m "reset --hard") must not
#     false-match, and a quoted arg before the subcommand (git -C "a b" reset --hard) must
#     not hide it -> quoted content is DELETED.
#   - a quoted token the shell expands identically to the bare form (a flag like "--force",
#     a "+main" refspec, a "." pathspec) must NOT bypass the deny -> content matching the
#     shared keepQuoted pattern is UNQUOTED IN PLACE, not deleted.
# Double- and single-quoted spans are matched in one alternation so the two quote kinds can't
# pair across each other. The double-quote branch is escape-aware ("(?:\\.|[^"\\])*") so an
# escaped quote inside a message does not terminate the match early and get mangled into a
# bare `reset --hard`. Single quotes need no escape form (bash forbids \').
$scrubbed = [regex]::Replace($cmd, '"((?:\\.|[^"\\])*)"|''([^'']*)''', {
        param($m)
        $inner = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
        if ($keep.IsMatch($inner)) { $inner } else { '' }
    })

# Rules match case-sensitively (.NET regex default): `git branch -d` (safe) vs `-D` (force)
# differ only by case.
foreach ($rule in $rules)
{
    if ($rule.Regex.IsMatch($scrubbed))
    {
        # Surface the raw command so the assistant can hand it back for the user to copy and
        # run themselves (e.g. via Claude Code's `! <command>` shell passthrough) instead of
        # only naming the rule that fired.
        Write-Deny "$($rule.Reason) If you want to run it yourself, type: ! $cmd"
        exit 0
    }
}

if ($call.tool_name -eq 'Bash')
{
    $pwshInBash = [System.IO.Path]::Combine($PSScriptRoot, 'block-pwsh-in-bash.ps1')
    if ([System.IO.File]::Exists($pwshInBash))
    {
        [Console]::SetIn([System.IO.StringReader]::new($payload))
        try { & $pwshInBash } catch { $null = $_ }
    }
}
exit 0
