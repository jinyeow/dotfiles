#Requires -Version 7
# Behavioural tests for claude/block-pwsh-in-bash.ps1 — the PreToolUse(Bash) deny hook that
# blocks PowerShell sent to the Bash tool. Drives the real hook with tool-call JSON on stdin.
#
# Documented properties pinned here:
#   - a capitalized Verb-Noun cmdlet at command position is denied
#   - lowercase executables (start-stop-daemon) are NOT caught
#   - a cmdlet after a lone `&` separator is denied (the new separator)
#   - a new-verb cmdlet (Install-Module) is denied
#   - a cmdlet merely quoted as a search string is allowed
#   - malformed/empty stdin fails open

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $script:RepoRoot 'claude/block-pwsh-in-bash.ps1'

    function Invoke-Hook {
        param([string] $Payload)
        return ($Payload | & pwsh -NoProfile -File $script:Hook 2>&1 | Out-String)
    }
    function Invoke-HookCmd {
        param([string] $Command)
        $json = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        return (Invoke-Hook -Payload $json)
    }
}

Describe 'claude/block-pwsh-in-bash.ps1' {
    Context 'denies PowerShell' {
        It 'denies <Command>' -TestCases @(
            @{ Command = 'Get-ChildItem -Path .' }
            @{ Command = 'Remove-Item foo' }
            @{ Command = 'pwsh -c "echo hi"' }
            @{ Command = 'sleep 1 & Get-Job' }              # cmdlet after a lone & separator
            @{ Command = 'Install-Module Foo' }             # new verb: Install
            @{ Command = 'Update-Help' }                    # new verb: Update
            @{ Command = 'Publish-Module -Name Foo' }       # new verb: Publish
        ) {
            param($Command)
            $out = Invoke-HookCmd -Command $Command
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'allows non-PowerShell' {
        It 'allows <Command>' -TestCases @(
            @{ Command = 'start-stop-daemon --start' }      # lowercase, not a cmdlet
            @{ Command = 'rg "Get-Content" .' }             # cmdlet only as a quoted search string
            @{ Command = 'grep -R "Install-Module" src' }
            @{ Command = 'ls -la && cat file' }
            @{ Command = 'git status' }
        ) {
            param($Command)
            $out = Invoke-HookCmd -Command $Command
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'escape-aware quote scrub' {
        It 'allows a cmdlet inside an escaped-quote search string' {
            # The scrub must be escape-aware so \" does not terminate the quoted string early
            # and re-expose a cmdlet at (apparent) command position.
            $out = Invoke-HookCmd -Command 'rg "say \"Get-Content\" now" .'
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'fails open' {
        It 'allows on empty stdin' {
            (Invoke-Hook -Payload '').Trim() | Should -BeNullOrEmpty
        }
        It 'allows on malformed JSON' {
            (Invoke-Hook -Payload 'garbage{').Trim() | Should -BeNullOrEmpty
        }
    }
}
