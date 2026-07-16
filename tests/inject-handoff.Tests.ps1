#Requires -Version 7
# Behavioural tests for claude/inject-handoff.ps1 — the SessionStart hook that injects a
# pending .claude/handoff.md into a fresh session (source startup/clear) as additionalContext,
# then archives the file. Drives the real hook with hook JSON on stdin.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $script:RepoRoot 'claude/inject-handoff.ps1'

    function Invoke-Hook {
        param([string] $Source, [string] $Cwd)
        $json = @{ source = $Source; cwd = $Cwd } | ConvertTo-Json -Compress
        return ($json | & pwsh -NoProfile -File $script:Hook 2>&1 | Out-String)
    }
    function New-Workspace {
        param([switch] $WithHandoff, [string] $Marker = 'HANDOFF-MARKER-XYZ')
        $ws = Join-Path ([IO.Path]::GetTempPath()) ('handoff-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $ws '.claude') -Force | Out-Null
        if ($WithHandoff) {
            Set-Content -LiteralPath (Join-Path $ws '.claude/handoff.md') -Value "# Handoff`n$Marker" -Encoding UTF8
        }
        return $ws
    }
}

Describe 'claude/inject-handoff.ps1' {
    It 'injects handoff content on a fresh startup session' {
        $ws = New-Workspace -WithHandoff
        try {
            $out = Invoke-Hook -Source 'startup' -Cwd $ws
            $out | Should -Match 'HANDOFF-MARKER-XYZ'
            $out | Should -Match '"hookEventName":"SessionStart"'
            # Consumed: original handoff.md is archived, not left in place.
            Test-Path -LiteralPath (Join-Path $ws '.claude/handoff.md') | Should -BeFalse
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'is silent when no handoff file exists' {
        $ws = New-Workspace
        try {
            (Invoke-Hook -Source 'startup' -Cwd $ws).Trim() | Should -BeNullOrEmpty
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'is silent for a non-fresh source (resume) even when a handoff exists' {
        $ws = New-Workspace -WithHandoff
        try {
            (Invoke-Hook -Source 'resume' -Cwd $ws).Trim() | Should -BeNullOrEmpty
            # Not consumed either — left for a genuinely fresh session.
            Test-Path -LiteralPath (Join-Path $ws '.claude/handoff.md') | Should -BeTrue
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
