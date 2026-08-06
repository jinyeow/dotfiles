# ============================================================================
# Resolve-TestBash.ps1 — locate a real POSIX bash for tests that shell out
# ============================================================================
# On a WSL-equipped Windows machine a bare `bash` on PATH resolves to the WSL
# launcher (System32 or WindowsApps), not a real shell. This helper finds Git for
# Windows bash instead. Not a *.Tests.ps1 file on purpose, so Pester's default
# container filter skips it; it has zero consumers until #42-#45 land.
# ============================================================================

function Resolve-TestBash {
    <#
    .SYNOPSIS
    Full path to a usable, real bash, or $null if none is found. Never throws —
    each caller decides skip-vs-throw for itself.
    #>
    [OutputType([string])]
    param()

    if (-not $IsWindows) {
        try {
            $bashCmd = Get-Command -Name bash -CommandType Application -ErrorAction Ignore | Select-Object -First 1
            return $bashCmd.Source
        } catch {
            return $null
        }
    }

    # Each strategy is isolated in its own try/catch so a failure in one (e.g. an
    # unexpected Split-Path/Join-Path error) falls through to the next instead of
    # aborting the whole resolution chain.
    try {
        $gitCmd = Get-Command -Name git -CommandType Application -ErrorAction Ignore
        if ($gitCmd -and $gitCmd.Source) {
            [string]$gitRoot = Split-Path -Path (Split-Path -Path $gitCmd.Source -Parent) -Parent
            [string]$candidate = Join-Path $gitRoot 'bin' 'bash.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
    } catch {
        # fall through to the next strategy
    }

    try {
        if ($env:ProgramFiles) {
            [string]$fallback = Join-Path $env:ProgramFiles 'Git' 'bin' 'bash.exe'
            if (Test-Path -LiteralPath $fallback -PathType Leaf) {
                return $fallback
            }
        }
    } catch {
        # fall through to the next strategy
    }

    try {
        [array]$pathCandidates = Get-Command -Name bash -CommandType Application -All -ErrorAction Ignore
        foreach ($pathCandidate in $pathCandidates) {
            if (-not $pathCandidate.Source) {
                continue
            }
            if ($pathCandidate.Source -match '(?i)\\Windows\\System32\\|\\WindowsApps\\') {
                continue
            }
            if (Test-Path -LiteralPath $pathCandidate.Source -PathType Leaf) {
                return $pathCandidate.Source
            }
        }
    } catch {
        # every strategy has now been tried
    }

    return $null
}
