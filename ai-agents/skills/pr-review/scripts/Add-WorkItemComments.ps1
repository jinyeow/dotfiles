<#
.SYNOPSIS
    Adds a discussion comment to each listed Azure DevOps work item.

.DESCRIPTION
    Reads a JSON array of items:
        [{ "key": "c3", "workItemId": 123, "text": "<p>html</p>" }]
    The key is a local identifier for the result file. It is never posted.

    Uses the work item comments API (version 7.1-preview.4). Before it posts, the script reads the
    work item's comments and skips an item whose text matches an existing comment, so a re-run does
    not post twice. Each request retries a 429 or 5xx response with backoff.

    The result file is written after each item:
        [{ key, workItemId, commentId, skipped, error }]
    The script fails when any item failed. -DryRun needs no token and makes no network calls.

.EXAMPLE
    pwsh -NoProfile -File Add-WorkItemComments.ps1 -OrganizationUrl https://dev.azure.com/example-org -Project 'Example Project' -InputFile comments.json -ResultFile result.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OrganizationUrl,
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$InputFile,
    [Parameter(Mandatory)][string]$ResultFile,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AdoRest.ps1')

if (-not (Test-Path -LiteralPath $InputFile -PathType Leaf))
{
    throw [System.IO.FileNotFoundException]::new("Input file not found: $InputFile", $InputFile)
}
[object[]]$items = @(Get-Content -Raw -LiteralPath $InputFile | ConvertFrom-Json)

$results = [System.Collections.Generic.List[pscustomobject]]::new()
Save-AdoResult -Results $results -Path $ResultFile

$projectBase = "$($OrganizationUrl.TrimEnd('/'))/$([uri]::EscapeDataString($Project))/_apis/wit/workItems"
$headers = @{}
if (-not $DryRun)
{
    $headers = @{ Authorization = "Bearer $(Get-AdoAccessToken)" }
}

foreach ($item in $items)
{
    $entry = [ordered]@{ key = $item.key; workItemId = $item.workItemId; commentId = $null; skipped = $false; error = $null }
    try
    {
        [int]$workItemId = 0
        if (-not [int]::TryParse([string]$item.workItemId, [ref]$workItemId))
        {
            throw [System.ArgumentException]::new("workItemId '$($item.workItemId)' is not an integer.")
        }
        $entry.workItemId = $workItemId
        [string]$text = ([string]$item.text).Trim()
        if (-not $text)
        {
            throw [System.ArgumentException]::new('text is empty.')
        }
        $commentsUri = "$projectBase/$workItemId/comments?api-version=7.1-preview.4"

        if ($DryRun)
        {
            $entry.commentId = 'dry-run'
            Write-Host "[DRY RUN] [$($item.key)] would comment on work item $workItemId"
        }
        else
        {
            $existing = (Invoke-AdoRequest -Method GET -Uri $commentsUri -Headers $headers).comments |
                Where-Object { ([string]$_.text).Trim() -eq $text } |
                Select-Object -First 1
            if ($existing)
            {
                $entry.commentId = $existing.id
                $entry.skipped = $true
                Write-Host "[$($item.key)] work item $workItemId already has this comment ($($existing.id)); skipped"
            }
            else
            {
                $response = Invoke-AdoRequest -Method POST -Uri $commentsUri -Headers $headers -Body @{ text = $text }
                $entry.commentId = $response.id
                Write-Host "[$($item.key)] added comment $($response.id) to work item $workItemId"
            }
        }
    }
    catch
    {
        $entry.error = Get-AdoErrorText -ErrorRecord $_
        Write-Warning "[$($item.key)] failed: $($entry.error)"
    }
    $results.Add([pscustomobject]$entry)
    Save-AdoResult -Results $results -Path $ResultFile
}

[int]$failed = @($results | Where-Object { $_.error }).Count
Write-Host "Done: $($results.Count - $failed) of $($results.Count) comment(s) added or already present. Results: $ResultFile"
if ($failed -gt 0)
{
    throw [System.InvalidOperationException]::new("$failed of $($results.Count) comment(s) failed. Results: $ResultFile")
}
