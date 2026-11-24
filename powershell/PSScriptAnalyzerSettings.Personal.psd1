# Brace and whitespace rules for personal PowerShell projects (Allman statement braces).
# Statement blocks (function, if, else, try, catch, class) open on their own line.
# Scriptblock arguments (ForEach-Object {, -ScriptBlock {), hashtables and one-line
# blocks stay as written.
#
# To use it, copy this file into the project root as PSScriptAnalyzerSettings.psd1, or
# pass it directly:
#   Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
#   Invoke-Formatter -ScriptDefinition $code -Settings ./PSScriptAnalyzerSettings.psd1
@{
    Rules = @{
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $false
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore = $false
        }

        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = 'space'
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckSeparator = $true
            CheckInnerBrace = $true
            CheckPipe = $true
            CheckParameter = $false
        }
    }
}
