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

    try {
        if (-not $IsWindows) {
            $bashCmd = Get-Command -Name bash -CommandType Application -ErrorAction Ignore
            return $bashCmd.Source
        }

        $gitCmd = Get-Command -Name git -CommandType Application -ErrorAction Ignore
        if ($gitCmd -and $gitCmd.Source) {
            [string]$gitRoot = Split-Path -Path (Split-Path -Path $gitCmd.Source -Parent) -Parent
            [string]$candidate = Join-Path $gitRoot 'bin' 'bash.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }

        if ($env:ProgramFiles) {
            [string]$fallback = Join-Path $env:ProgramFiles 'Git' 'bin' 'bash.exe'
            if (Test-Path -LiteralPath $fallback -PathType Leaf) {
                return $fallback
            }
        }

        [array]$pathCandidates = Get-Command -Name bash -CommandType Application -All -ErrorAction Ignore
        foreach ($pathCandidate in $pathCandidates) {
            if (-not $pathCandidate.Source) {
                continue
            }
            if ($pathCandidate.Source -match '(?i)\\Windows\\System32\\|\\Microsoft\\WindowsApps\\') {
                continue
            }
            if (Test-Path -LiteralPath $pathCandidate.Source -PathType Leaf) {
                return $pathCandidate.Source
            }
        }

        return $null
    } catch {
        return $null
    }
}
