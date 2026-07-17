#Requires -Version 7
# Behavioural tests for the [hook "work-policy"] stanza in git/gitconfig-work.
#
# Config-based hooks need git >= 2.54; below that the stanza is ignored entirely, so the
# suite skips rather than false-green. Each test builds a throwaway repo with an isolated
# HOME and includes the REAL gitconfig-work, so it exercises the shipped stanza rather
# than a copy that could drift from it.

# Runs at DISCOVERY time — Describe's -Skip: is evaluated then, so this cannot live in
# BeforeAll (which runs later, leaving the flag unset and silently skipping every test).
$script:HasConfigHooks = $false
$gitRaw = (& git --version) -replace '^git version\s*', ''
if ($gitRaw -match '^(\d+)\.(\d+)') {
    $script:HasConfigHooks = [version]::new([int]$Matches[1], [int]$Matches[2]) -ge [version]'2.54'
}

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:WorkConfig = Join-Path $script:RepoRoot 'git/gitconfig-work'

    # Build a repo whose gitconfig includes the real gitconfig-work unconditionally (the
    # [includeIf] scoping is git's own, already covered by git's tests; what matters here is
    # what the stanza does once included).
    function New-WorkRepo {
        param([string] $Root)

        $home_ = Join-Path $Root 'home'
        $repo = Join-Path $Root 'repo'
        New-Item -ItemType Directory -Path $home_, $repo -Force | Out-Null

        $inc = ($script:WorkConfig -replace '\\', '/')
        Set-Content -Path (Join-Path $home_ '.gitconfig') -Value "[include]`n`tpath = $inc" -Encoding ASCII

        & git -C $repo init -q .
        & git -C $repo config user.email 'test@example.invalid'
        & git -C $repo config user.name 'Test'
        return $repo
    }
}

Describe 'git/gitconfig-work work-policy hook' -Skip:(-not $script:HasConfigHooks) {
    It 'allows a commit when the dispatcher is not installed' {
        # ~/.gitconfig-work [include]s into the C: clone, so the stanza goes live the moment
        # that clone pulls — but ~/.git_work_hooks only exists once setup.ps1 -Module git
        # re-runs. Git does NOT fail open on a missing command: it errors "cannot spawn" and
        # blocks the commit, so every work-repo commit would fail in that window.
        $root = Join-Path ([IO.Path]::GetTempPath()) ('workhook-' + [guid]::NewGuid())
        $repo = New-WorkRepo -Root $root

        $origHome, $origProfile = $env:HOME, $env:USERPROFILE
        $origNoSystem, $origXdgConfig = $env:GIT_CONFIG_NOSYSTEM, $env:XDG_CONFIG_HOME
        try {
            $env:HOME = $env:USERPROFILE = (Join-Path $root 'home')
            $env:GIT_CONFIG_NOSYSTEM = '1'
            $env:XDG_CONFIG_HOME = ''
            # No ~/.git_work_hooks here: this is the not-yet-installed state.
            Set-Content -Path (Join-Path $repo 'f.txt') -Value 'x'
            & git -C $repo add f.txt
            $out = (& git -C $repo commit -m 'test' 2>&1 | Out-String)

            $out | Should -Not -Match 'cannot spawn'
            (& git -C $repo log --oneline 2>$null | Measure-Object).Count | Should -Be 1 -Because 'a missing dispatcher must fail open, not block the commit'
        } finally {
            $env:HOME, $env:USERPROFILE = $origHome, $origProfile
            $env:GIT_CONFIG_NOSYSTEM, $env:XDG_CONFIG_HOME = $origNoSystem, $origXdgConfig
            Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'still blocks a commit when the installed dispatcher fails' {
        # The guard must not turn the hook into a no-op: an installed policy that exits
        # non-zero has to keep blocking. Asserting only on the commit count is not enough —
        # a commit blocked by a config parse error, a spawn failure, or a non-executable
        # dispatcher (exit 126) would pass for the wrong reason. The output assertions are
        # what prove the policy itself ran and did the blocking.
        $root = Join-Path ([IO.Path]::GetTempPath()) ('workhook-' + [guid]::NewGuid())
        $repo = New-WorkRepo -Root $root
        $hookDir = Join-Path $root 'home/.git_work_hooks'
        New-Item -ItemType Directory -Path $hookDir -Force | Out-Null
        $policy = Join-Path $hookDir 'policy'
        Set-Content -Path $policy -Value "#!/bin/sh`necho 'POLICY VIOLATION'`nexit 1" -Encoding ASCII -NoNewline
        # Needed on Linux, where the exec bit is real; a no-op on Windows (MSYS reports
        # every file executable). If chmod is unavailable the output assertion below fails
        # loudly rather than passing on a 126.
        if (Get-Command chmod -ErrorAction SilentlyContinue) { & chmod +x $policy }

        $origHome, $origProfile = $env:HOME, $env:USERPROFILE
        $origNoSystem, $origXdgConfig = $env:GIT_CONFIG_NOSYSTEM, $env:XDG_CONFIG_HOME
        try {
            $env:HOME = $env:USERPROFILE = (Join-Path $root 'home')
            $env:GIT_CONFIG_NOSYSTEM = '1'
            $env:XDG_CONFIG_HOME = ''
            Set-Content -Path (Join-Path $repo 'f.txt') -Value 'x'
            & git -C $repo add f.txt
            $out = (& git -C $repo commit -m 'test' 2>&1 | Out-String)

            (& git -C $repo log --oneline 2>$null | Measure-Object).Count | Should -Be 0 -Because 'a failing policy must still block the commit'
            $out | Should -Match 'POLICY VIOLATION' -Because 'the policy must be what blocked it, not a spawn or parse error'
            $out | Should -Not -Match 'cannot spawn'
        } finally {
            $env:HOME, $env:USERPROFILE = $origHome, $origProfile
            $env:GIT_CONFIG_NOSYSTEM, $env:XDG_CONFIG_HOME = $origNoSystem, $origXdgConfig
            Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'blocks loudly when the dispatcher is present but not executable' {
        # Fail-open covers "not installed yet", never "installed but broken". The guard is
        # `-f` (exists) rather than `-x` (executable) precisely so a half-broken install
        # reaches exec and fails (126) instead of silently skipping the policy. Only Linux
        # can observe this: on Windows MSYS reports every file executable and chmod is a
        # no-op, so the case is unreachable there and the test self-skips.
        if (-not (Get-Command chmod -ErrorAction SilentlyContinue)) { Set-ItResult -Skipped -Because 'chmod unavailable'; return }

        $root = Join-Path ([IO.Path]::GetTempPath()) ('workhook-' + [guid]::NewGuid())
        $repo = New-WorkRepo -Root $root
        $hookDir = Join-Path $root 'home/.git_work_hooks'
        New-Item -ItemType Directory -Path $hookDir -Force | Out-Null
        $policy = Join-Path $hookDir 'policy'
        Set-Content -Path $policy -Value "#!/bin/sh`nexit 1" -Encoding ASCII -NoNewline
        & chmod -x $policy
        if ((& sh -c "test -x '$($policy -replace '\\', '/')' && echo x") -eq 'x') {
            Set-ItResult -Skipped -Because 'filesystem does not honour the exec bit (NTFS/MSYS)'
            return
        }

        $origHome, $origProfile = $env:HOME, $env:USERPROFILE
        $origNoSystem, $origXdgConfig = $env:GIT_CONFIG_NOSYSTEM, $env:XDG_CONFIG_HOME
        try {
            $env:HOME = $env:USERPROFILE = (Join-Path $root 'home')
            $env:GIT_CONFIG_NOSYSTEM = '1'
            $env:XDG_CONFIG_HOME = ''
            Set-Content -Path (Join-Path $repo 'f.txt') -Value 'x'
            & git -C $repo add f.txt
            & git -C $repo commit -m 'test' 2>&1 | Out-Null

            (& git -C $repo log --oneline 2>$null | Measure-Object).Count | Should -Be 0 -Because 'a broken install must fail closed, not skip the policy silently'
        } finally {
            $env:HOME, $env:USERPROFILE = $origHome, $origProfile
            $env:GIT_CONFIG_NOSYSTEM, $env:XDG_CONFIG_HOME = $origNoSystem, $origXdgConfig
            Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
