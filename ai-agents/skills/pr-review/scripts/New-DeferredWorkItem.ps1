<#
.SYNOPSIS
    Creates one Azure DevOps work item per deferred review finding, as a child of a parent work item.

.DESCRIPTION
    Reads a JSON array of items:
        [{ "key": "c3", "title": "...", "descriptionHtml": "<p>...</p>" }]
    The key is a local identifier for the result file. It is never posted.

    Reads the parent's project, area path, iteration path and child work items. Creates each item
    as WorkItemType in the parent's project, with the parent's area and iteration and a parent
    link. It adds no tags, no assignee and no other relation: a PR artifact link would complete the
    work item when the PR merges, so the PR is cross-referenced by URL elsewhere.

    An item whose title matches an existing child of the parent is skipped, so a re-run does not
    create duplicates. Each request retries a 429 or 5xx response with backoff.

    The result file is written after each item:
        [{ key, workItemId, workItemUrl, skipped, error }]
    The script fails when any item failed. -DryRun needs no token and makes no network calls.

.EXAMPLE
    pwsh -NoProfile -File New-DeferredWorkItem.ps1 -OrganizationUrl https://dev.azure.com/example-org -ParentId 1000 -WorkItemType Task -InputFile items.json -ResultFile result.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OrganizationUrl,
    [Parameter(Mandatory)][int]$ParentId,
    [Parameter(Mandatory)][string]$WorkItemType,
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
foreach ($candidate in $items)
{
    if (-not $candidate.title)
    {
        throw [System.ArgumentException]::new("[$($candidate.key)] has no title. Nothing was created.")
    }
}

$results = [System.Collections.Generic.List[pscustomobject]]::new()
Save-AdoResult -Results $results -Path $ResultFile

$org = $OrganizationUrl.TrimEnd('/')
$headers = @{}
[string]$project = ''
[string]$areaPath = ''
[string]$iterationPath = ''
[string]$parentApiUrl = ''
$existingChildren = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)

if (-not $DryRun)
{
    $headers = @{ Authorization = "Bearer $(Get-AdoAccessToken)" }
    $parentUri = "$org/_apis/wit/workitems/$($ParentId)?`$expand=relations&api-version=7.1"
    try
    {
        $parent = Invoke-AdoRequest -Method GET -Uri $parentUri -Headers $headers
    }
    catch
    {
        throw [System.InvalidOperationException]::new("Could not read parent work item $ParentId from $parentUri. Nothing was created. $(Get-AdoErrorText -ErrorRecord $_)")
    }
    $project = $parent.fields.'System.TeamProject'
    $areaPath = $parent.fields.'System.AreaPath'
    $iterationPath = $parent.fields.'System.IterationPath'
    $parentApiUrl = $parent.url
    if (-not ($project -and $areaPath -and $iterationPath -and $parentApiUrl))
    {
        throw [System.InvalidOperationException]::new("Parent work item $ParentId has no project, area path, iteration path or url. Response: $(ConvertTo-Json -InputObject $parent -Depth 5 -Compress)")
    }

    $childIds = [System.Collections.Generic.List[int]]::new()
    foreach ($relation in $parent.relations)
    {
        if ($relation.rel -eq 'System.LinkTypes.Hierarchy-Forward')
        {
            $childIds.Add([int](($relation.url -split '/')[-1]))
        }
    }
    # The work items batch read takes at most 200 ids per call.
    for ([int]$offset = 0; $offset -lt $childIds.Count; $offset += 200)
    {
        [string]$idList = $childIds.GetRange($offset, [math]::Min(200, $childIds.Count - $offset)) -join ','
        $children = Invoke-AdoRequest -Method GET -Uri "$org/_apis/wit/workitems?ids=$idList&fields=System.Title&api-version=7.1" -Headers $headers
        foreach ($child in $children.value)
        {
            $existingChildren[[string]$child.fields.'System.Title'] = [int]$child.id
        }
    }
}

$projectSegment = [uri]::EscapeDataString($project)
# '$' + the type is the create route segment, for example $Task or $Product%20Backlog%20Item.
$createUri = "$org/$projectSegment/_apis/wit/workitems/" + '$' + [uri]::EscapeDataString($WorkItemType) + '?api-version=7.1'

foreach ($item in $items)
{
    [string]$title = $item.title
    $entry = [ordered]@{ key = $item.key; workItemId = $null; workItemUrl = $null; skipped = $false; error = $null }
    if ($existingChildren.ContainsKey($title))
    {
        $entry.workItemId = $existingChildren[$title]
        $entry.workItemUrl = "$org/$projectSegment/_workitems/edit/$($entry.workItemId)"
        $entry.skipped = $true
        Write-Host "[$($item.key)] '$title' already exists as work item $($entry.workItemId); skipped"
    }
    elseif ($DryRun)
    {
        $entry.workItemId = 'dry-run'
        Write-Host "[DRY RUN] [$($item.key)] would create $WorkItemType '$title' under work item $ParentId"
    }
    else
    {
        [object[]]$patch = @(
            @{ op = 'add'; path = '/fields/System.Title'; value = $title }
            @{ op = 'add'; path = '/fields/System.Description'; value = [string]$item.descriptionHtml }
            @{ op = 'add'; path = '/fields/System.AreaPath'; value = $areaPath }
            @{ op = 'add'; path = '/fields/System.IterationPath'; value = $iterationPath }
            @{ op = 'add'; path = '/relations/-'; value = @{ rel = 'System.LinkTypes.Hierarchy-Reverse'; url = $parentApiUrl } }
        )
        try
        {
            $response = Invoke-AdoRequest -Method POST -Uri $createUri -Headers $headers -Body $patch -ContentType 'application/json-patch+json; charset=utf-8'
            $entry.workItemId = $response.id
            $entry.workItemUrl = "$org/$projectSegment/_workitems/edit/$($response.id)"
            $existingChildren[$title] = [int]$response.id
            Write-Host "[$($item.key)] created work item $($response.id)"
        }
        catch
        {
            $entry.error = Get-AdoErrorText -ErrorRecord $_
            Write-Warning "[$($item.key)] failed: $($entry.error)"
        }
    }
    $results.Add([pscustomobject]$entry)
    Save-AdoResult -Results $results -Path $ResultFile
}

[int]$failed = @($results | Where-Object { $_.error }).Count
Write-Host "Done: $($results.Count - $failed) of $($results.Count) work item(s) created or already present. Results: $ResultFile"
if ($failed -gt 0)
{
    throw [System.InvalidOperationException]::new("$failed of $($results.Count) work item(s) failed. Results: $ResultFile")
}
