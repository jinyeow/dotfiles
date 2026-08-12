#Requires -Version 7
# Behavioural tests for claude/memory-review-nudge.ps1 — the SessionStart hook that nudges when
# the CURRENT project's auto-memory store is due for review (>= 14 days since the last review, or
# since the oldest memory when never reviewed). Resolves the memory dir from the transcript_path's
# parent, ignores the MEMORY.md index, and stays silent unless a genuinely fresh session
# (source startup/clear) has stale memories. Drives the real hook with hook JSON on stdin.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $script:RepoRoot 'claude/memory-review-nudge.ps1'

    function New-MemoryProject {
        param(
            [int] $Count = 2,
            [int] $AgeDays = 30,
            [Nullable[int]] $ReviewedDaysAgo = $null,
            [switch] $NoMemories
        )
        $proj = Join-Path ([IO.Path]::GetTempPath()) ('memproj-' + [guid]::NewGuid())
        $mem = Join-Path $proj 'memory'
        New-Item -ItemType Directory -Path $mem -Force | Out-Null
        # The MEMORY.md index is always present and must be ignored by the review count.
        Set-Content -LiteralPath (Join-Path $mem 'MEMORY.md') -Value '- index line' -Encoding UTF8
        if (-not $NoMemories) {
            for ($i = 0; $i -lt $Count; $i++) {
                $f = Join-Path $mem "mem-$i.md"
                Set-Content -LiteralPath $f -Value "memory body $i" -Encoding UTF8
                (Get-Item -LiteralPath $f).LastWriteTime = (Get-Date).AddDays(-$AgeDays)
            }
        }
        if ($null -ne $ReviewedDaysAgo) {
            $stamp = (Get-Date).AddDays(-$ReviewedDaysAgo).ToUniversalTime().ToString('o')
            Set-Content -LiteralPath (Join-Path $mem '.last-reviewed') -Value $stamp -Encoding UTF8
        }
        # The transcript file is a sibling of memory/ inside the project dir, mirroring
        # ~/.claude/projects/<slug>/<session>.jsonl.
        $transcript = Join-Path $proj 'session.jsonl'
        Set-Content -LiteralPath $transcript -Value '{}' -Encoding UTF8
        return $transcript
    }

    function Invoke-Hook {
        param([string] $Source = 'startup', [string] $TranscriptPath)
        $json = @{ source = $Source; transcript_path = $TranscriptPath } | ConvertTo-Json -Compress
        return ($json | & pwsh -NoProfile -File $script:Hook 2>&1 | Out-String)
    }
}

Describe 'claude/memory-review-nudge.ps1' {
    It 'nudges on a fresh startup when memories are stale and never reviewed' {
        $t = New-MemoryProject -Count 3 -AgeDays 30
        $out = Invoke-Hook -Source 'startup' -TranscriptPath $t
        $out | Should -Match 'Memory review due'
        $out | Should -Match '"hookEventName":"SessionStart"'
        $out | Should -Match '3 memories'
    }

    It 'ignores the MEMORY.md index in the count' {
        # One real memory + the always-present MEMORY.md index -> count is 1, not 2.
        $t = New-MemoryProject -Count 1 -AgeDays 30
        (Invoke-Hook -TranscriptPath $t) | Should -Match '1 memory,'
    }

    It 'is silent when the project has no memories beyond the index' {
        $t = New-MemoryProject -NoMemories
        (Invoke-Hook -TranscriptPath $t).Trim() | Should -BeNullOrEmpty
    }

    It 'nudges on a cleared session (source clear)' {
        $t = New-MemoryProject -Count 2 -AgeDays 30
        (Invoke-Hook -Source 'clear' -TranscriptPath $t) | Should -Match 'Memory review due'
    }

    It 'is silent for a non-fresh source (resume) even when memories are stale' {
        $t = New-MemoryProject -Count 3 -AgeDays 30
        (Invoke-Hook -Source 'resume' -TranscriptPath $t).Trim() | Should -BeNullOrEmpty
    }

    It 'is silent when the memories are newer than the review interval' {
        $t = New-MemoryProject -Count 2 -AgeDays 5
        (Invoke-Hook -TranscriptPath $t).Trim() | Should -BeNullOrEmpty
    }

    It 'is silent when reviewed within the interval' {
        $t = New-MemoryProject -Count 2 -AgeDays 30 -ReviewedDaysAgo 5
        (Invoke-Hook -TranscriptPath $t).Trim() | Should -BeNullOrEmpty
    }

    It 'nudges again once the last review is older than the interval' {
        $t = New-MemoryProject -Count 2 -AgeDays 60 -ReviewedDaysAgo 30
        (Invoke-Hook -TranscriptPath $t) | Should -Match 'Memory review due'
    }

    It 'is silent when the transcript path has no memory dir' {
        $proj = Join-Path ([IO.Path]::GetTempPath()) ('memproj-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $proj -Force | Out-Null
        $t = Join-Path $proj 'session.jsonl'
        Set-Content -LiteralPath $t -Value '{}' -Encoding UTF8
        (Invoke-Hook -TranscriptPath $t).Trim() | Should -BeNullOrEmpty
    }
}
