#Requires -Version 7
# Behavioural test for claude/lint-powershell.ps1's fail-open contract: a malformed /
# unparseable PSScriptAnalyzerSettings.psd1 must make the hook go SILENT (exit 0, no
# output), not surface an analyzer error — the hook is an advisory nudge, never a gate.
#
# The throw this pins happens INSIDE Invoke-ScriptAnalyzer, which needs PSScriptAnalyzer;
# without it the hook already no-ops earlier (the module-absent guard), so the malformed
# path is unreachable and there is nothing to prove. So the suite skips rather than
# false-green — computed at DISCOVERY time (Describe -Skip: is evaluated then, and this
# cannot live in BeforeAll). Same pattern as lint-powershell.Tests.ps1.
$script:HasPSSA = [bool](Get-Module -ListAvailable -Name PSScriptAnalyzer)

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $script:RepoRoot 'claude/lint-powershell.ps1'

    function Invoke-LintHook {
        param([string] $FilePath)
        $json = @{ tool_input = @{ file_path = $FilePath } } | ConvertTo-Json -Compress
        return ($json | & pwsh -NoProfile -File $script:Hook 2>&1 | Out-String)
    }
    function New-TempRoot {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('lintfailopen-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        return $root
    }
}

Describe 'claude/lint-powershell.ps1 fail-open' -Skip:(-not $script:HasPSSA) {
    It 'exits silently when the ruleset file is malformed' {
        $root = New-TempRoot
        try {
            $edited = Join-Path $root 'edited.ps1'
            Set-Content -LiteralPath $edited -Value "Write-Host 'hi'" -Encoding UTF8
            # Project boundary so the walk-up stops here and finds this ruleset.
            New-Item -ItemType Directory -Path (Join-Path $root '.git') -Force | Out-Null
            # A ruleset that is NOT valid PowerShell data - Invoke-ScriptAnalyzer throws on it.
            Set-Content -LiteralPath (Join-Path $root 'PSScriptAnalyzerSettings.psd1') `
                -Value '@{ Severity = @( this is not valid psd1 ' -Encoding UTF8

            $out = Invoke-LintHook -FilePath $edited

            $out.Trim() | Should -BeNullOrEmpty -Because 'a malformed ruleset must fail open silently, not surface an error'
        } finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
