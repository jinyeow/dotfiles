#Requires -Version 7
# Behavioural tests for claude/warn-legacy-files.ps1 — the PreToolUse(Edit|Write) hook that
# emits an `ask` decision before editing a legacy / Linux-snapshot dotfile, scoped to the
# dotfiles repo via $env:DOTFILES. Drives the real hook with tool-call JSON on stdin.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $script:RepoRoot 'claude/warn-legacy-files.ps1'

    # Invoke with a given $env:DOTFILES value ($null = unset) and file_path.
    function Invoke-Hook {
        param([string] $FilePath, [string] $Dotfiles)
        $json = @{ tool_input = @{ file_path = $FilePath } } | ConvertTo-Json -Compress
        $orig = $env:DOTFILES
        try {
            if ($null -eq $Dotfiles) { Remove-Item Env:DOTFILES -ErrorAction SilentlyContinue }
            else { $env:DOTFILES = $Dotfiles }
            return ($json | & pwsh -NoProfile -File $script:Hook 2>&1 | Out-String)
        } finally {
            if ($null -eq $orig) { Remove-Item Env:DOTFILES -ErrorAction SilentlyContinue }
            else { $env:DOTFILES = $orig }
        }
    }
    function New-Root {
        $r = Join-Path ([IO.Path]::GetTempPath()) ('legacy-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $r -Force | Out-Null
        return $r
    }
}

Describe 'claude/warn-legacy-files.ps1' {
    It 'asks before editing a legacy WM config file when $env:DOTFILES is set' {
        $root = New-Root
        try {
            $out = Invoke-Hook -FilePath (Join-Path $root 'config/bspwm/bspwmrc') -Dotfiles $root
            $out | Should -Match '"permissionDecision":"ask"'
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'no-ops when $env:DOTFILES is unset (avoids global false fires)' {
        $root = New-Root
        try {
            $out = Invoke-Hook -FilePath (Join-Path $root 'config/bspwm/bspwmrc') -Dotfiles $null
            $out.Trim() | Should -BeNullOrEmpty
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'no-ops for a non-legacy file inside the repo' {
        $root = New-Root
        try {
            $out = Invoke-Hook -FilePath (Join-Path $root 'powershell/Microsoft.PowerShell_profile.ps1') -Dotfiles $root
            $out.Trim() | Should -BeNullOrEmpty
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'no-ops for pwsh_profile.ps1, bootstrap.sh, and Makefile (no longer present at the repo root)' {
        $root = New-Root
        try {
            foreach ($name in 'pwsh_profile.ps1', 'bootstrap.sh', 'Makefile') {
                $out = Invoke-Hook -FilePath (Join-Path $root $name) -Dotfiles $root
                $out.Trim() | Should -BeNullOrEmpty -Because "$name is no longer a legacy path"
            }
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
