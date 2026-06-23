#Requires -Version 7
# PreToolUse(Bash) hook: block PowerShell that was sent to the Bash tool. On this pwsh-native
# machine, PowerShell cmdlets must run through the PowerShell tool, not Bash (a Verb-Noun
# cmdlet under bash/sh either errors or silently misbehaves). Reads the tool-call JSON on
# stdin; allows silently (exit 0, no output) unless a command segment *starts* with an
# unmistakable PowerShell token, in which case it emits a deny decision pointing at the
# PowerShell tool.
#
# Detection is command-position only (segment start) to stay high-precision: a cmdlet name
# merely quoted as a search string (e.g. `rg "Get-Content"`) is NOT at command position and
# is allowed through.
$ErrorActionPreference = 'Stop'

$payload = [Console]::In.ReadToEnd()
if (-not $payload) { exit 0 }

try { $call = $payload | ConvertFrom-Json } catch { exit 0 }

$cmd = $call.tool_input.command
if (-not $cmd) { exit 0 }

# Drop quoted substrings first so a `|`/`;` inside a quoted argument (e.g. rg "Get-Content|x")
# is not treated as a command separator, then split into segments on shell separators.
$scrubbed = $cmd -replace '"[^"]*"', '' -replace "'[^']*'", ''
$segments = $scrubbed -split '(\||;|&&|\|\||\n)'
$verbs = 'Get|Set|New|Remove|Test|Select|Where|ForEach|Out|Write|Read|Import|Export|' +
  'ConvertTo|ConvertFrom|Invoke|Start|Stop|Join|Split|Add|Clear|Copy|Move|Rename|' +
  'Push|Pop|Format|Measure|Sort|Group|Compare|Resolve|Wait|Enable|Disable|Register|Unregister'

foreach ($segment in $segments) {
  $head = $segment.TrimStart().TrimStart('(', '{', '$', '&').TrimStart()
  $head = $head -replace '^(\w+=\S*\s+)+', ''  # drop env-assignment prefixes: FOO=bar pwsh ...
  $hit = $null
  if ($head -cmatch '^(pwsh|powershell)(\.exe)?\b')      { $hit = 'a pwsh/powershell invocation' }
  elseif ($head -cmatch '^env:[A-Za-z_]')                { $hit = 'a $env: variable' }
  elseif ($head -cmatch "^($verbs)-[A-Z][A-Za-z]+\b")    { $hit = "the cmdlet `"$($Matches[0])`"" }

  if ($hit) {
    @{
      hookSpecificOutput = @{
        hookEventName            = 'PreToolUse'
        permissionDecision       = 'deny'
        permissionDecisionReason = "This Bash command looks like PowerShell ($hit). " +
          'Re-run it with the PowerShell tool, not the Bash tool (your pwsh-native rule).'
      }
    } | ConvertTo-Json -Depth 5 -Compress
    exit 0
  }
}
exit 0
