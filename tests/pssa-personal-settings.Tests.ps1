#Requires -Version 7
# Tests for powershell/PSScriptAnalyzerSettings.Personal.psd1, the brace and whitespace
# template for personal projects. The template must flag OTBS statement braces, pass the
# Allman form, and let Invoke-Formatter turn one into the other while leaving scriptblock
# arguments such as `ForEach-Object {` on the same line.
#
# Needs PSScriptAnalyzer, so the suite skips rather than false-green. Computed at
# discovery time because Describe's -Skip: is evaluated before BeforeAll runs.
$script:HasPSSA = [bool](Get-Module -ListAvailable -Name PSScriptAnalyzer)

BeforeAll {
    $script:Settings = Join-Path (Split-Path $PSScriptRoot -Parent) 'powershell/PSScriptAnalyzerSettings.Personal.psd1'
    $script:BraceRules = @('PSPlaceOpenBrace', 'PSPlaceCloseBrace')

    $script:Otbs = @'
function Get-Thing {
    param([string]$Name)
    if ($Name) {
        $Name | ForEach-Object { $_.ToUpper() }
    } else {
        try {
            Get-Item -Path $Name
        } catch {
            throw
        }
    }
}
'@

    $script:Allman = @'
function Get-Thing
{
    param([string]$Name)
    if ($Name)
    {
        $Name | ForEach-Object { $_.ToUpper() }
    }
    else
    {
        try
        {
            Get-Item -Path $Name
        }
        catch
        {
            throw
        }
    }
}
'@
}

Describe 'PSScriptAnalyzerSettings.Personal.psd1' -Skip:(-not $script:HasPSSA) {
    It 'exists' {
        $script:Settings | Should -Exist
    }

    It 'flags OTBS statement braces' {
        $findings = Invoke-ScriptAnalyzer -ScriptDefinition $script:Otbs -Settings $script:Settings
        $braceFindings = @($findings | Where-Object RuleName -In $script:BraceRules)
        $braceFindings.Count | Should -BeGreaterThan 0
    }

    It 'passes the Allman form' {
        $findings = Invoke-ScriptAnalyzer -ScriptDefinition $script:Allman -Settings $script:Settings
        $findings | Should -BeNullOrEmpty
    }

    It 'formats the OTBS sample into the Allman sample' {
        $formatted = Invoke-Formatter -ScriptDefinition $script:Otbs -Settings $script:Settings
        $formatted.TrimEnd() | Should -BeExactly $script:Allman.TrimEnd()
    }

    It 'keeps a scriptblock argument on the same line' {
        $formatted = Invoke-Formatter -ScriptDefinition $script:Otbs -Settings $script:Settings
        $formatted | Should -Match ([regex]::Escape('ForEach-Object { $_.ToUpper() }'))
    }

    # A native command receives `a,b` as one argument and `a, b` as two, so neither the
    # linter nor the formatter may add a space after the comma.
    It 'leaves a comma list passed to a native command unchanged' {
        $native = "& ./setup.sh -m lazygit,windowsterminal`n"

        $findings = Invoke-ScriptAnalyzer -ScriptDefinition $native -Settings $script:Settings
        $formatted = Invoke-Formatter -ScriptDefinition $native -Settings $script:Settings

        $findings | Should -BeNullOrEmpty
        $formatted | Should -BeExactly $native
    }
}
