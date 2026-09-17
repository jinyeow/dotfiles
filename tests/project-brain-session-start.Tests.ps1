#Requires -Version 7
# Behavioural tests for ai-agents/skills/project-brain/scripts/session-start.ps1 — the SessionStart
# hook that injects an initiative's core.md + STATUS.md as additionalContext. Pins the fail-safe
# over-cap warning line (spec: adhoc-02-project-brain-initiative-log-spec.md section 3 D3) appended
# when STATUS.md exceeds the ~60 line soft cap. Drives the real script as a child process with
# SessionStart-shaped JSON on stdin, against the in-repo self-contained brain path
# (session-start.ps1:52-65: an ancestor .claude/brain/core.md wins with no brains.json/$HOME
# involved), asserting on the emitted hookSpecificOutput.additionalContext JSON since that is the
# contract.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Script = Join-Path $script:RepoRoot 'ai-agents/skills/project-brain/scripts/session-start.ps1'

    function Invoke-SessionStart {
        param([string] $Payload, [string] $Cwd)
        if (-not $Payload) { $Payload = @{ cwd = $Cwd } | ConvertTo-Json -Compress }
        $out = ($Payload | & pwsh -NoProfile -File $script:Script 2>&1 | Out-String).Trim()
        $script:LastExitCode = $LASTEXITCODE
        return $out
    }

    function New-Workspace {
        param([string[]] $StatusLines, [string] $StatusRaw, [switch] $NoStatus)
        $ws = Join-Path ([IO.Path]::GetTempPath()) ('pb-session-start-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $ws '.claude/brain') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $ws '.claude/brain/core.md') -Value '# core' -Encoding utf8
        if ($StatusRaw) {
            Set-Content -LiteralPath (Join-Path $ws '.claude/brain/STATUS.md') -Value $StatusRaw -NoNewline -Encoding utf8
        } elseif (-not $NoStatus) {
            Set-Content -LiteralPath (Join-Path $ws '.claude/brain/STATUS.md') -Value ($StatusLines -join "`n") -Encoding utf8
        }
        return $ws
    }
}

Describe 'ai-agents/skills/project-brain/scripts/session-start.ps1' {
    It 'emits no warning line when STATUS.md is under the cap' {
        $lines = 1..5 | ForEach-Object { "line$_" }
        $ws = New-Workspace -StatusLines $lines
        try {
            $out = Invoke-SessionStart -Cwd $ws
            $json = $out | ConvertFrom-Json
            $ctx = $json.hookSpecificOutput.additionalContext
            $ctx | Should -Not -Match '\[project-brain\] STATUS\.md is \d+ lines'
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'appends exactly one warning line carrying the real count when STATUS.md exceeds the cap' {
        $lines = 1..61 | ForEach-Object { "line$_" }
        $ws = New-Workspace -StatusLines $lines
        try {
            $out = Invoke-SessionStart -Cwd $ws
            $json = $out | ConvertFrom-Json
            $ctx = $json.hookSpecificOutput.additionalContext
            $warningMatches = [regex]::Matches($ctx, '\[project-brain\] STATUS\.md is \d+ lines')
            $warningMatches.Count | Should -Be 1
            $ctx | Should -Match ([regex]::Escape('[project-brain] STATUS.md is 61 lines; the contract caps it at about 60. Move history to log.md in this initiative at the next status update.'))
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'keeps the missing-STATUS.md line and emits no warning when STATUS.md is absent' {
        $ws = New-Workspace -NoStatus
        try {
            $out = Invoke-SessionStart -Cwd $ws
            $json = $out | ConvertFrom-Json
            $ctx = $json.hookSpecificOutput.additionalContext
            $ctx | Should -Match ([regex]::Escape('(No STATUS.md yet - this initiative may be newly scaffolded.)'))
            $ctx | Should -Not -Match '\[project-brain\] STATUS\.md is \d+ lines'
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'exits 0 with no output on malformed stdin' {
        $out = Invoke-SessionStart -Payload 'not valid json {'
        $out | Should -BeNullOrEmpty
        $script:LastExitCode | Should -Be 0
    }

    It 'emits no warning line when STATUS.md is exactly at the cap' {
        $lines = 1..60 | ForEach-Object { "line$_" }
        $ws = New-Workspace -StatusLines $lines
        try {
            $out = Invoke-SessionStart -Cwd $ws
            $json = $out | ConvertFrom-Json
            $ctx = $json.hookSpecificOutput.additionalContext
            $ctx | Should -Not -Match '\[project-brain\] STATUS\.md is \d+ lines'
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'counts a trailing blank line as real content, not as the terminator' {
        $raw = (1..61 | ForEach-Object { "line$_" }) -join "`n"
        $raw += "`n`n"
        $ws = New-Workspace -StatusRaw $raw
        try {
            $out = Invoke-SessionStart -Cwd $ws
            $json = $out | ConvertFrom-Json
            $ctx = $json.hookSpecificOutput.additionalContext
            $ctx | Should -Match ([regex]::Escape('[project-brain] STATUS.md is 62 lines'))
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
