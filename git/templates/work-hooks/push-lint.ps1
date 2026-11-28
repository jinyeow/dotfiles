#!/usr/bin/env pwsh
# PSScriptAnalyzer step of the work-push-lint pre-push dispatcher (see push-lint).
# Lints each file in -Files (paths relative to -Root) with the repo's -Settings file.
# It reads the working tree copy, which can differ from the pushed commits; a file
# missing from the working tree is skipped with a warning.
# Exits 1 and prints the findings when there are any, or when the analyzer itself
# errors; warns and exits 0 when the PSScriptAnalyzer module is not installed.
param(
    [Parameter(Mandatory)] [string] $Root,
    [Parameter(Mandatory)] [string] $Settings,
    [Parameter(ValueFromRemainingArguments)] [string[]] $Files
)

Set-StrictMode -Version Latest

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer))
{
    [Console]::Error.WriteLine('work-push-lint: warning: the PSScriptAnalyzer module is not installed; skipping PowerShell lint.')
    exit 0
}

# Relative paths in the settings file (e.g. CustomRulePath) resolve against the current
# directory, so run from the repo root as CI does.
Set-Location -LiteralPath $Root

# An analyzer error (e.g. a missing custom rule module) is non-terminating and returns
# no findings, which would read as a clean lint. -ErrorAction Stop makes it block.
# Invoke-ScriptAnalyzer sets no exit code, so the findings are counted here.
$findings = [System.Collections.Generic.List[object]]::new()
try
{
    foreach ($file in @($Files))
    {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf))
        {
            [Console]::Error.WriteLine("work-push-lint: warning: '$file' is not in the working tree; not linted.")
            continue
        }
        # -Path takes wildcards; escape them so br[1].ps1 means that file.
        $params = @{
            Path = [WildcardPattern]::Escape($file)
            Settings = $Settings
            ErrorAction = 'Stop'
        }
        foreach ($finding in @(Invoke-ScriptAnalyzer @params))
        {
            $findings.Add($finding)
        }
    }
}
catch
{
    [Console]::Error.WriteLine("work-push-lint: PSScriptAnalyzer failed: $($_.Exception.Message)")
    exit 1
}
if ($findings.Count -eq 0)
{
    exit 0
}

[Console]::Error.WriteLine(($findings | Format-Table -AutoSize -Wrap -Property RuleName, Severity, ScriptName, Line, Message | Out-String -Width 200))
exit 1
