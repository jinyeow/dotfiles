#Requires -Version 7
# Pester test for the Az-context async runspace in powershell/Profile/Set-Prompt.ps1.
# Dot-sourcing the file only defines functions (it starts no timer/eventing at load),
# so with Az.Accounts mocked as available we can drive Start-AzContextRefresh directly
# and assert it reuses one long-lived runspace instead of creating a new one per tick.

BeforeAll {
    $global:ProfileModules = @{ 'Az.Accounts' = $true }
    $global:PromptCache = $null   # force the guarded init to build a clean cache
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'powershell' 'Profile' 'Set-Prompt.ps1')
}

Describe 'Start-AzContextRefresh persistent runspace' {
    # The priming invocation imports Az.Accounts for real; if that import fails the
    # runspace is intentionally dropped (so a broken session re-primes), which would
    # defeat the reuse assertion. Skip where the module isn't installed to test.
    It 'reuses one long-lived runspace across successive refreshes' -Skip:(-not (Get-Module -ListAvailable Az.Accounts)) {
        Start-AzContextRefresh
        $first = $global:PromptCache.AzRunspace.InstanceId
        $first | Should -Not -BeNullOrEmpty

        # Reap the first (priming) invocation so the concurrency guard doesn't
        # short-circuit the second call — otherwise call #2 is a no-op and the
        # reuse branch is never exercised.
        while (-not $global:PromptCache.AzInvocation.Handle.IsCompleted) {
            Start-Sleep -Milliseconds 50
        }
        $null = Get-AzAsyncResult

        Start-AzContextRefresh
        $global:PromptCache.AzRunspace.InstanceId | Should -Be $first
    }
}

Describe 'prompt column-0 hardening against a dirty fzf console' {
    # fzf's Windows renderer can leave DISABLE_NEWLINE_AUTO_RETURN set with the
    # cursor mid-row on abort, staircasing the multi-line prompt. The prompt must
    # render from column 0 regardless: a leading ESC[G before the first visible
    # segment, and CR+LF+ESC[K (not a bare LF) at every internal line break.
    BeforeAll {
        $script:ESC = [char]27
        $script:rendered = prompt
    }

    It 'starts its visible content with a cursor-to-column-0 (ESC[G)' {
        # Strip the non-visible OSC 9;9 / OSC 7 control sequences (ESC ] ... ESC \)
        $visible = $script:rendered -replace "$ESC\][^$ESC]*$ESC\\", ''
        $visible | Should -Match "^$([regex]::Escape($ESC))\[G"
    }

    It 'breaks internal lines with CR+LF+ESC[K, not a bare LF' {
        $script:rendered | Should -Match "\r\n$([regex]::Escape($ESC))\[K"
        # No LF that is not preceded by CR (would staircase on a stuck console)
        $script:rendered | Should -Not -Match "(?<!\r)\n"
    }
}

AfterAll {
    if ($global:PromptCache.AzInvocation) {
        try { $global:PromptCache.AzInvocation.PowerShell.Dispose() } catch {}
    }
    if ($global:PromptCache.AzRunspace) {
        try { $global:PromptCache.AzRunspace.Dispose() } catch {}
    }
}
