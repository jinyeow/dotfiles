#Requires -Version 7
# Pester tests for setup.ps1 argument handling. Runs the installer as a child pwsh
# in -DryRun so it never mutates the machine.

BeforeAll {
    $script:SetupScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'setup.ps1'
}

Describe 'setup.ps1 argument validation' {
    It 'shows usage guidance and exits 1 when no -Module and no -CleanBackups are given' {
        # Regression: `$Module | Select-Object -Unique` collapsed the empty-array default to
        # $null, so the `$Module.Count` guard threw under StrictMode instead of printing usage.
        $output = & pwsh -NoProfile -File $script:SetupScript -DryRun 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $output | Should -Match 'Specify -Module'
        $output | Should -Not -Match "property 'Count' cannot be found"
    }
}
