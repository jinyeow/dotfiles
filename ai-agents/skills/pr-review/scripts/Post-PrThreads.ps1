<#
.SYNOPSIS
    Posts review comments to an Azure DevOps pull request as threads.

.DESCRIPTION
    Reads a JSON array of comments:
        [{ "key": "c1", "filePath": "/src/app.ps1", "startLine": 10, "endLine": 12, "content": "markdown" }]
    The key is a local identifier for the result file. It is never posted.
    Optional fields per comment: status ("active", the default, or "closed") and properties (an
    object of string values, written to the thread's property bag, which the PR page does not show).

    A comment with filePath and startLine is anchored to those lines on the right side of the latest
    iteration. A comment with filePath and no startLine becomes a file-level thread. A comment
    without filePath becomes a general PR comment.

    Before it posts, the script reads the PR's existing threads. It skips a comment whose file, start
    line and first content line match an existing thread, so a re-run does not post twice.
    It waits DelaySeconds between posts, and retries a 429 or 5xx response with backoff.

    The result file is written after each comment, so a stopped run keeps the completed items:
        [{ key, anchor, status, threadId, skipped, error }]
    The script fails when any comment failed. -DryRun needs no token and makes no network calls.

.EXAMPLE
    pwsh -NoProfile -File Post-PrThreads.ps1 -OrganizationUrl https://dev.azure.com/example-org -Project 'Example Project' -RepositoryId <repo-guid> -PullRequestId 42 -CommentsFile comments.json -ResultFile result.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OrganizationUrl,
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$RepositoryId,
    [Parameter(Mandatory)][int]$PullRequestId,
    [Parameter(Mandatory)][string]$CommentsFile,
    [Parameter(Mandatory)][string]$ResultFile,
    [ValidateRange(0, 600)][int]$DelaySeconds = 2,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AdoRest.ps1')

# Repo-relative path with a leading slash, or '' for a general comment.
function ConvertTo-ThreadPath
{
    [OutputType([string])]
    param([string]$Path)

    if (-not $Path)
    {
        return ''
    }
    if ($Path.StartsWith('/'))
    {
        return $Path
    }
    return "/$Path"
}

# The identity a re-run compares: file, start line and the first line of the content.
function Get-ThreadIdentity
{
    [OutputType([string])]
    param([string]$Path, [int]$StartLine, [string]$Content)

    [string]$firstLine = ''
    if ($Content)
    {
        $firstLine = ($Content -split "`r?`n", 2)[0].Trim()
    }
    return '{0}|{1}|{2}' -f $Path.ToLowerInvariant(), $StartLine, $firstLine
}

if (-not (Test-Path -LiteralPath $CommentsFile -PathType Leaf))
{
    throw [System.IO.FileNotFoundException]::new("Comments file not found: $CommentsFile", $CommentsFile)
}
[object[]]$comments = @(Get-Content -Raw -LiteralPath $CommentsFile | ConvertFrom-Json)

# Azure DevOps CommentThreadStatus values for the statuses this script posts.
$threadStatusValues = @{ active = 1; closed = 4 }
foreach ($candidate in $comments)
{
    if (-not $candidate.content)
    {
        throw [System.ArgumentException]::new("[$($candidate.key)] has no content. Nothing was posted.")
    }
    if ($candidate.status -and -not $threadStatusValues.ContainsKey([string]$candidate.status))
    {
        throw [System.ArgumentException]::new("[$($candidate.key)] has unknown status '$($candidate.status)'. Allowed: active, closed. Nothing was posted.")
    }
}

$results = [System.Collections.Generic.List[pscustomobject]]::new()
Save-AdoResult -Results $results -Path $ResultFile

$org = $OrganizationUrl.TrimEnd('/')
$base = "$org/$([uri]::EscapeDataString($Project))/_apis/git/repositories/$RepositoryId/pullRequests/$PullRequestId"
$headers = @{}
[int]$latestIteration = 0
$changeTrackingIds = @{}
$existingThreads = @{}

if (-not $DryRun)
{
    try
    {
        $headers = @{ Authorization = "Bearer $(Get-AdoAccessToken)" }

        $iterations = (Invoke-AdoRequest -Method GET -Uri "$base/iterations?api-version=7.1" -Headers $headers).value
        # Measure-Object returns a Double, and Azure DevOps rejects "3.0" as an iteration id.
        $latestIteration = [int](($iterations | Measure-Object -Property id -Maximum).Maximum)

        [int]$skip = 0
        [bool]$morePages = $true
        while ($morePages)
        {
            $page = Invoke-AdoRequest -Method GET -Uri "$base/iterations/$latestIteration/changes?`$compareTo=0&`$top=2000&`$skip=$skip&api-version=7.1" -Headers $headers
            foreach ($change in $page.changeEntries)
            {
                $changePath = if ($change.item.path) { $change.item.path } else { $change.originalPath }
                if ($changePath)
                {
                    $changeTrackingIds[$changePath.ToLowerInvariant()] = $change.changeTrackingId
                }
            }
            $skip = [int]$page.nextSkip
            $morePages = $skip -gt 0
        }

        foreach ($thread in (Invoke-AdoRequest -Method GET -Uri "$base/threads?api-version=7.1" -Headers $headers).value)
        {
            if ($thread.isDeleted -or -not $thread.comments)
            {
                continue
            }
            $threadPath = ConvertTo-ThreadPath -Path $thread.threadContext.filePath
            [int]$threadLine = if ($thread.threadContext.rightFileStart) { $thread.threadContext.rightFileStart.line } else { 0 }
            $identity = Get-ThreadIdentity -Path $threadPath -StartLine $threadLine -Content $thread.comments[0].content
            $existingThreads[$identity] = $thread.id
        }
    }
    catch
    {
        [string]$setupError = "Could not read the PR's iterations, changes or threads. Nothing was posted. $(Get-AdoErrorText -ErrorRecord $_)"
        foreach ($pending in $comments)
        {
            $results.Add([pscustomobject][ordered]@{ key = $pending.key; anchor = $null; status = $null; threadId = $null; skipped = $false; error = $setupError })
        }
        Save-AdoResult -Results $results -Path $ResultFile
        throw
    }
}

[int]$attempted = 0
foreach ($comment in $comments)
{
    [string]$status = if ($comment.status) { ([string]$comment.status).ToLowerInvariant() } else { 'active' }
    [string]$filePath = ConvertTo-ThreadPath -Path $comment.filePath
    [int]$startLine = if ($comment.startLine) { [int]$comment.startLine } else { 0 }
    [int]$endLine = if ($comment.endLine) { [int]$comment.endLine } else { $startLine }

    $body = @{
        comments = @(@{ parentCommentId = 0; content = [string]$comment.content; commentType = 1 })
        status = $threadStatusValues[$status]
    }
    if ($comment.properties)
    {
        # Azure DevOps property-bag format: each property is { $type, $value }.
        $properties = @{}
        foreach ($property in $comment.properties.PSObject.Properties)
        {
            $properties[$property.Name] = @{ '$type' = 'System.String'; '$value' = [string]$property.Value }
        }
        $body.properties = $properties
    }

    [string]$anchor = 'general'
    if ($filePath)
    {
        $threadContext = @{ filePath = $filePath }
        $anchor = "$filePath (file)"
        if ($startLine -gt 0)
        {
            $threadContext.rightFileStart = @{ line = $startLine; offset = 1 }
            $threadContext.rightFileEnd = @{ line = $endLine; offset = 1 }
            $anchor = "$filePath R$startLine-$endLine"
        }
        $body.threadContext = $threadContext

        $prContext = @{ iterationContext = @{ firstComparingIteration = 1; secondComparingIteration = $latestIteration } }
        $changeTrackingId = $changeTrackingIds[$filePath.ToLowerInvariant()]
        if ($changeTrackingId)
        {
            $prContext.changeTrackingId = $changeTrackingId
        }
        elseif (-not $DryRun)
        {
            Write-Warning "[$($comment.key)] $filePath is not in the changes of iteration $latestIteration; anchoring without a change tracking id."
        }
        $body.pullRequestThreadContext = $prContext
    }

    $entry = [ordered]@{ key = $comment.key; anchor = $anchor; status = $status; threadId = $null; skipped = $false; error = $null }
    $identity = Get-ThreadIdentity -Path $filePath -StartLine $startLine -Content ([string]$comment.content)
    if ($existingThreads.ContainsKey($identity))
    {
        $entry.threadId = $existingThreads[$identity]
        $entry.skipped = $true
        Write-Host "[$($comment.key)] already posted as thread $($entry.threadId) at $anchor; skipped"
    }
    elseif ($DryRun)
    {
        $entry.threadId = 'dry-run'
        Write-Host "[DRY RUN] [$($comment.key)] would post a $status thread at $anchor"
    }
    else
    {
        if ($attempted -gt 0 -and $DelaySeconds -gt 0)
        {
            Start-Sleep -Seconds $DelaySeconds
        }
        $attempted++
        try
        {
            $response = Invoke-AdoRequest -Method POST -Uri "$base/threads?api-version=7.1" -Headers $headers -Body $body
            $entry.threadId = $response.id
            $existingThreads[$identity] = $response.id
            Write-Host "[$($comment.key)] posted thread $($response.id) at $anchor"
        }
        catch
        {
            $entry.error = Get-AdoErrorText -ErrorRecord $_
            Write-Warning "[$($comment.key)] failed: $($entry.error)"
        }
    }
    $results.Add([pscustomobject]$entry)
    Save-AdoResult -Results $results -Path $ResultFile
}

[int]$failed = @($results | Where-Object { $_.error }).Count
Write-Host "Done: $($results.Count - $failed) of $($results.Count) comment(s) posted or already present. Results: $ResultFile"
if ($failed -gt 0)
{
    throw [System.InvalidOperationException]::new("$failed of $($results.Count) comment(s) failed. Results: $ResultFile")
}
