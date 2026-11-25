#Requires -Version 7
<#
.SYNOPSIS
Runs one CI shard of the Pester suite in tests/.

.DESCRIPTION
Every shard except the last runs the test files listed for it below. The last shard runs
every other tests/*.Tests.ps1, so a new test file is never left out. The lists are balanced
on recent CI run times for each platform; rebalance them when one shard grows much slower.

Fails if a listed file does not exist, or if -Count does not match the number of lists for
the platform, so the lists and the workflow matrix cannot drift apart silently.

.EXAMPLE
./.github/scripts/Invoke-PesterShard.ps1 -Platform Windows -Shard 2 -Count 4
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Windows', 'Linux')]
    [string] $Platform,

    [Parameter(Mandatory)]
    [ValidateRange(1, 32)]
    [int] $Shard,

    [Parameter(Mandatory)]
    [ValidateRange(1, 32)]
    [int] $Count
)

$ErrorActionPreference = 'Stop'

# Test file names without .Tests.ps1, for every shard but the last.
$lists = @{
    Windows = @(
        , @('no-claude-session-trailer', 'git-templates-ai-reference-hook', 'pi-project-brain-autoload',
            'codex-git-guardrails')
        , @('setup', 'pi-ai-reference-guard', 'project-brain-session-start', 'block-destructive-vcs')
        , @('codex-ai-reference-guard', 'warn-legacy-files', 'prepare-commit-msg', 'block-pwsh-in-bash',
            'psmux', 'nvim-statusline')
    )
    Linux = @(
        , @('setup-sh', 'convert-to-okf', 'project-brain-session-start', 'block-destructive-vcs')
    )
}

$listed = $lists[$Platform]
if ($listed.Count -ne $Count - 1)
{
    throw "$Platform has $($listed.Count + 1) shards in this script, but the workflow runs $Count."
}
if ($Shard -gt $Count)
{
    throw "Shard $Shard is out of range for $Count shards."
}

$testsDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'tests'
$all = Get-ChildItem -Path $testsDir -Filter '*.Tests.ps1' -File |
    ForEach-Object { $_.Name -replace '\.Tests\.ps1$', '' }
$allListed = $listed | ForEach-Object { $_ }

$missing = $allListed | Where-Object { $_ -cnotin $all }
if ($missing)
{
    throw "Shard lists name test files that do not exist: $($missing -join ', ')"
}
$duplicates = $allListed | Group-Object | Where-Object Count -GT 1 | ForEach-Object Name
if ($duplicates)
{
    throw "Shard lists name test files more than once: $($duplicates -join ', ')"
}

if ($Shard -lt $Count)
{
    $names = $listed[$Shard - 1]
}
else
{
    $names = $all | Where-Object { $_ -cnotin $allListed }
}
$paths = [string[]]($names | ForEach-Object { Join-Path $testsDir "$_.Tests.ps1" })

Write-Host "$Platform shard $Shard of $Count runs $($paths.Count) file(s):"
$paths | ForEach-Object { Write-Host "  $_" }

$config = New-PesterConfiguration
$config.Run.Path = $paths
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
