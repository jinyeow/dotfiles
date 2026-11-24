#Requires -Version 7

<#
.SYNOPSIS
    Copy Claude Code, Codex and Pi session transcripts into a local, compressed archive.

.DESCRIPTION
    Copies new and changed files only, and never deletes from the archive, so a transcript
    stays archived after an agent prunes it (Claude Code's cleanupPeriodDays) or after the
    profile is lost. Sources:
      - ~/.claude/projects (transcripts, subagent logs, tool output)
      - ~/.claude/history.jsonl (prompt history)
      - ~/.codex/sessions
      - ~/.pi/agent/sessions
    A missing source is skipped with a warning.

    Claude projects whose folder name matches -WorkProjectPattern go to <ArchiveRoot>\work\claude;
    everything else goes under <ArchiveRoot>\personal\<agent>. The archive root is NTFS-compressed.

    Transcripts hold tool output, file contents and sometimes secrets. Keep the archive on a
    local disk, outside synced folders and git.

.PARAMETER ArchiveRoot
    Archive folder. Defaults to E:\AgentArchive.

.PARAMETER SourceHome
    Home folder that holds .claude, .codex and .pi. Defaults to $HOME.

.PARAMETER WorkProjectPattern
    Regex matched against Claude project folder names (for example '^E--Contoso') to route
    those projects to the work archive. Pass it from the scheduled task so the pattern stays
    out of this repository. Without it, every project is archived as personal.

.EXAMPLE
    ./Save-AgentTranscript.ps1 -WorkProjectPattern '^E--Contoso'

.NOTES
    Windows-only: uses robocopy and compact.exe.
#>
[CmdletBinding()]
param(
    [string]$ArchiveRoot = 'E:\AgentArchive',
    [string]$SourceHome = $HOME,
    [string]$WorkProjectPattern = ''
)
$ErrorActionPreference = 'Stop'

function Copy-NewerTree {
    # Copy new and newer files from Source into Destination; never delete from Destination.
    # A source file older than its archived copy is skipped (/XO).
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Destination)

    robocopy $Source $Destination /E /XO /COPY:DAT /DCOPY:T /R:1 /W:1 /NP /NJH /NJS /NFL /NDL | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw [System.IO.IOException]::new("robocopy exit code $LASTEXITCODE copying '$Source' to '$Destination'")
    }
}

function Copy-NewerFile {
    # Copy one file into DestinationFolder when it is new or newer than the archived copy.
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$DestinationFolder)

    robocopy (Split-Path $Source) $DestinationFolder (Split-Path $Source -Leaf) /XO /COPY:DAT /R:1 /W:1 /NP /NJH /NJS /NFL /NDL | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw [System.IO.IOException]::new("robocopy exit code $LASTEXITCODE copying '$Source' to '$DestinationFolder'")
    }
}

[System.Collections.Generic.List[string]]$failures = [System.Collections.Generic.List[string]]::new()

function Invoke-ArchiveStep {
    # Run one copy. A missing source warns and is skipped. An I/O failure (for example a file
    # locked by a running agent) warns and is recorded, so the remaining sources still run.
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][scriptblock]$Copy)

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Warning "Source not found, skipped: $Source"
        return
    }
    try {
        & $Copy
    } catch [System.IO.IOException] {
        Write-Warning $_.Exception.Message
        $failures.Add($_.Exception.Message)
    }
}

if (-not (Test-Path -LiteralPath $ArchiveRoot)) {
    New-Item -ItemType Directory -Path $ArchiveRoot | Out-Null
}

[string]$projects = Join-Path $SourceHome '.claude' 'projects'
if (Test-Path -LiteralPath $projects) {
    foreach ($project in Get-ChildItem -LiteralPath $projects -Directory -Force) {
        [string]$scope = if ($WorkProjectPattern -and $project.Name -match $WorkProjectPattern) { 'work' } else { 'personal' }
        [string]$projectDest = Join-Path $ArchiveRoot $scope 'claude' 'projects' $project.Name
        Invoke-ArchiveStep -Source $project.FullName -Copy { Copy-NewerTree -Source $project.FullName -Destination $projectDest }
    }
} else {
    Write-Warning "Source not found, skipped: $projects"
}

[string]$history = Join-Path $SourceHome '.claude' 'history.jsonl'
Invoke-ArchiveStep -Source $history -Copy { Copy-NewerFile -Source $history -DestinationFolder (Join-Path $ArchiveRoot 'personal' 'claude') }

[string]$codexSessions = Join-Path $SourceHome '.codex' 'sessions'
Invoke-ArchiveStep -Source $codexSessions -Copy { Copy-NewerTree -Source $codexSessions -Destination (Join-Path $ArchiveRoot 'personal' 'codex' 'sessions') }

[string]$piSessions = Join-Path $SourceHome '.pi' 'agent' 'sessions'
Invoke-ArchiveStep -Source $piSessions -Copy { Copy-NewerTree -Source $piSessions -Destination (Join-Path $ArchiveRoot 'personal' 'pi' 'sessions') }

# Compress anything not yet compressed (/I continues past files in use, /Q keeps output short).
compact.exe /C /S:"$ArchiveRoot" /I /Q | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "compact.exe failed with exit code $LASTEXITCODE on '$ArchiveRoot'"
}

if ($failures.Count) {
    throw [System.IO.IOException]::new("Archive incomplete: $($failures.Count) source(s) failed. $($failures -join ' | ')")
}
