#!/usr/bin/env pwsh
param(
    [string]$CommitMsgFile,
    [string]$CommitSource,
    [string]$CommitSha
)

# Skip auto-generated commit messages (merge, squash)
if ($CommitSource -eq 'merge' -or $CommitSource -eq 'squash') { exit 0 }

$branchName = git symbolic-ref --short HEAD 2>$null
if (-not $branchName) { exit 0 }

# Branch skip list. Override per-repo with:
#   git config hooks.skipBranches "main,release/*,hotfix/*"
$configSkip = git config --get hooks.skipBranches 2>$null
$skipList   = if ($configSkip) {
    $configSkip -split ',' | ForEach-Object { $_.Trim() }
} else {
    @('main', 'master', 'develop', 'staging', 'test', 'deploy/*')
}

foreach ($pattern in $skipList) {
    if ($branchName -like $pattern) { exit 0 }
}

# Detect ticket ID from branch name:
#   JIRA: feature/PROJ-123-description  →  Refs: PROJ-123
#   ADO:  feature/1234-description      →  Refs: AB#1234
$trailer = $null
if ($branchName -cmatch '.*/(?<ticket>[A-Z][A-Z]+-\d+)') {
    $trailer = "Refs: $($Matches.ticket)"
} elseif ($branchName -cmatch '.*/(?<id>\d+)-') {
    $trailer = "Refs: AB#$($Matches.id)"
} else {
    exit 0
}

$content = Get-Content -Path $CommitMsgFile -Raw
# Skip if trailer already present (e.g. amending an already-tagged commit)
if ($content -match [regex]::Escape($trailer)) { exit 0 }

# Append as a git trailer — blank line separates body from footer
$newContent = $content.TrimEnd() + "`n`n$trailer`n"
Set-Content -Path $CommitMsgFile -Value $newContent -NoNewline
