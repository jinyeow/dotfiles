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

AfterAll {
    if ($global:PromptCache.AzInvocation) {
        try { $global:PromptCache.AzInvocation.PowerShell.Dispose() } catch {}
    }
    if ($global:PromptCache.AzRunspace) {
        try { $global:PromptCache.AzRunspace.Dispose() } catch {}
    }
}
