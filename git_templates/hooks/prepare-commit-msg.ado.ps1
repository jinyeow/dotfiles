#!/usr/bin/env pwsh

param (
    [string] $CommitMessageFilePath,
    [string] $CommitSource,
    [string] $CommitSha1
)

$commitMessage = Get-Content -Path $CommitMessageFilePath

if ($CommitSource -eq 'message') {
    $branchName = $(git symbolic-ref --short HEAD)
    if ($branchName -match '[a-z]+/(?<Id>[0-9]+)-') {
        $id = $Matches.Id
        if ($commitMessage -notmatch "#${id}") {
            Set-Content -Path $CommitMessageFilePath -Value "[#${id}]-${commitMessage}"
        }
    }
}

