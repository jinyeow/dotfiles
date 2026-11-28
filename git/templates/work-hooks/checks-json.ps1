#!/usr/bin/env pwsh
# JSON check for the work-checks pre-commit dispatcher (see `checks`): every staged
# .json file (added, copied, modified or renamed) must parse. Reads the index blob,
# not the worktree copy, and checks all files in this one pwsh process.
#
# pwsh 7 ConvertFrom-Json accepts // and /* */ comments and trailing commas, so JSONC
# files such as .vscode/settings.json pass without an exclusion list. -AsHashtable
# accepts keys that differ only by case ("a" and "A"), which plain ConvertFrom-Json
# rejects. A leading BOM is stripped, and an empty file counts as invalid.
# Exits 1 when any file fails, after listing each one on stderr.

Set-StrictMode -Version Latest

# Decode git's output as UTF-8 regardless of the console code page.
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

[string] $list = (& git -c core.quotePath=false diff --cached --name-only -z --diff-filter=ACMR -- '*.json') -join "`n"
if ($LASTEXITCODE -ne 0)
{
    throw "git diff --cached failed with exit code $LASTEXITCODE"
}
[string[]] $names = @($list -split "`0" | Where-Object { $_ })

[int] $bad = 0
foreach ($name in $names)
{
    [string] $text = (& git cat-file blob ":$name") -join "`n"
    if ($LASTEXITCODE -ne 0)
    {
        throw "git cat-file blob ':$name' failed with exit code $LASTEXITCODE"
    }
    $text = $text.TrimStart([char] 0xFEFF)
    [string] $reason = ''
    if (-not $text.Trim())
    {
        $reason = 'file is empty'
    }
    else
    {
        try
        {
            ConvertFrom-Json -InputObject $text -AsHashtable -ErrorAction Stop | Out-Null
        }
        catch
        {
            $reason = $_.Exception.Message
        }
    }
    if ($reason)
    {
        [Console]::Error.WriteLine("  ${name}: $reason")
        $bad++
    }
}
exit ([int] ($bad -gt 0))
