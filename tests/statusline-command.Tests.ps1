#Requires -Version 7
# Behavioural tests for claude/statusline-command.sh — the bash statusline. Focus: the git
# file-count classifier must count worktree deletions/type-changes (M, D, T) and staged
# type-changes (T), so a repo whose only change is a deleted (or retyped) file renders as
# DIRTY (red branch + a file-count glyph), not clean.
#
# Drives the real script through bash with the statusline JSON on stdin over a throwaway
# git repo. Needs bash + jq + git + awk (as the script does); skips rather than false-green.
. (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')
$script:HasDeps = [bool](Resolve-TestBash) -and
[bool](Get-Command jq -ErrorAction SilentlyContinue) -and
[bool](Get-Command git -ErrorAction SilentlyContinue)

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    . (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')
    $script:TestBash = Resolve-TestBash
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Script = Join-Path $script:RepoRoot 'claude/statusline-command.sh'
    $script:RED = "$([char]27)[91m"
    $script:YELLOW = "$([char]27)[93m"

    # Build a temp git repo with one committed file. Returns the repo path.
    function New-GitRepo
    {
        $repo = Join-Path ([IO.Path]::GetTempPath()) ('slrepo-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init -q
        & git -C $repo symbolic-ref HEAD refs/heads/master
        & git -C $repo config user.email 't@t.invalid'
        & git -C $repo config user.name 'T'
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'x' -Encoding ASCII
        & git -C $repo add a.txt
        & git -C $repo commit -qm init
        return $repo
    }

    # Run the statusline over $Repo (as its cwd). Returns the raw output (ANSI intact).
    function Invoke-Statusline
    {
        param([string] $Repo)
        $json = @{ cwd = $Repo } | ConvertTo-Json -Compress
        return ($json | & $script:TestBash $script:Script 2>&1 | Out-String)
    }
}

Describe 'claude/statusline-command.sh git file counts' -Skip:(-not $script:HasDeps) {
    It 'renders a clean repo with a yellow (not red) branch' {
        $repo = New-GitRepo
        try
        {
            $out = Invoke-Statusline -Repo $repo
            $out | Should -Match ([regex]::Escape($script:YELLOW) + '.*master')
            $out | Should -Not -Match '\*1|\+1'
        }
        finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'counts an unstaged deletion as a worktree change (dirty, not clean)' {
        # ` D a.txt`: x=space, y=D. The old classifier only matched y=M, so a deleted-only
        # repo rendered clean. Now y in [MDT] -> counted -> red branch + `*1`.
        $repo = New-GitRepo
        try
        {
            Remove-Item -LiteralPath (Join-Path $repo 'a.txt')
            $out = Invoke-Statusline -Repo $repo
            $out | Should -Match ([regex]::Escape($script:RED) + '.*master')
            $out | Should -Match '\*1'
        }
        finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'counts a staged type-change as a staged change (dirty, not clean)' {
        # `T  a.txt`: x=T, y=space. The old staged class [MADRC] omitted T, so a staged
        # type-change rendered clean. Now x in [MADRCT] -> counted -> red branch + `+1`.
        # The symlink is staged straight into the index, so no filesystem symlink is needed.
        # Do not use `ln -s` here: without native symlinks, Git for Windows' ln copies the
        # target instead, and copying a Temp folder into itself took over 8 minutes in CI.
        # The worktree still holds the regular file, so y is T or M; only x matters here.
        $repo = New-GitRepo
        try
        {
            $blob = 'target' | & git -C $repo hash-object -w --stdin
            & git -C $repo update-index --cacheinfo "120000,$blob,a.txt"
            $porcelain = (& git -C $repo status --porcelain) -join "`n"
            $porcelain | Should -Match '^T'

            $out = Invoke-Statusline -Repo $repo
            $out | Should -Match ([regex]::Escape($script:RED) + '.*master')
            $out | Should -Match '\+1'
        }
        finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
