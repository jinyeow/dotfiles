#Requires -Version 7
# Pester test for the Az-context async runspace in powershell/Profile/Set-Prompt.ps1.
# Dot-sourcing the file only defines functions (it starts no timer/eventing at load),
# so with Az.Accounts mocked as available we can drive Start-AzContextRefresh directly
# and assert it reuses one long-lived runspace instead of creating a new one per tick.

BeforeAll {
    $global:ProfileModules = @{ 'Az.Accounts' = $true }
    $global:PromptCache = $null   # force the guarded init to build a clean cache
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'powershell' 'Profile' 'Set-Prompt.ps1')

    # --- Hermetic git env so the git-backed tests below never touch the user's
    # --- global/system config, identity, or hooks (gitleaks/prepare-commit-msg).
    $script:gitEnvKeys = @(
        'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_SYSTEM', 'GIT_CONFIG_NOSYSTEM',
        'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL'
    )
    $script:gitEnvSaved = @{}
    foreach ($k in $script:gitEnvKeys) { $script:gitEnvSaved[$k] = [Environment]::GetEnvironmentVariable($k) }
    $script:emptyGitConfig = Join-Path ([System.IO.Path]::GetTempPath()) ("promptgit_empty_" + [guid]::NewGuid().ToString('N') + '.cfg')
    Set-Content -LiteralPath $script:emptyGitConfig -Value ''
    $env:GIT_CONFIG_GLOBAL   = $script:emptyGitConfig
    $env:GIT_CONFIG_SYSTEM   = $script:emptyGitConfig
    $env:GIT_CONFIG_NOSYSTEM = '1'
    $env:GIT_AUTHOR_NAME     = 'Test';            $env:GIT_COMMITTER_NAME  = 'Test'
    $env:GIT_AUTHOR_EMAIL    = 'test@example.com'; $env:GIT_COMMITTER_EMAIL = 'test@example.com'

    $script:tempRepos = [System.Collections.Generic.List[string]]::new()
    function script:New-TempGitRepo {
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("promptgit_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir | Out-Null
        git init -q -b main $dir 2>$null
        $script:tempRepos.Add($dir)
        return $dir
    }
}

Describe 'Start-AzContextRefresh persistent runspace' {
    # The priming invocation imports Az.Accounts for real; if that import fails the
    # runspace is intentionally dropped (so a broken session re-primes), which would
    # defeat the reuse assertion. Skip where the module isn't installed to test.
    It 'reuses one long-lived runspace across successive refreshes' -Skip:(-not (Get-Module -ListAvailable Az.Accounts)) {
        Start-AzContextRefresh
        $first = $global:PromptCache.AzRunspace.InstanceId
        $first | Should -Not -BeNullOrEmpty

        # Reap the first (priming) invocation so the concurrency guard doesn't
        # short-circuit the second call — otherwise call #2 is a no-op and the
        # reuse branch is never exercised.
        while (-not $global:PromptCache.AzInvocation.Handle.IsCompleted) {
            Start-Sleep -Milliseconds 50
        }
        $null = Get-AzAsyncResult

        Start-AzContextRefresh
        $global:PromptCache.AzRunspace.InstanceId | Should -Be $first
    }
}

Describe 'prompt column-0 hardening against a dirty fzf console' {
    # fzf's Windows renderer can leave DISABLE_NEWLINE_AUTO_RETURN set with the
    # cursor mid-row on abort, staircasing the multi-line prompt. The prompt must
    # render from column 0 regardless: a leading ESC[G before the first visible
    # segment, and CR+LF+ESC[K (not a bare LF) at every internal line break.
    BeforeAll {
        $script:ESC = [char]27
        $script:rendered = prompt
    }

    It 'starts its visible content with a cursor-to-column-0 (ESC[G)' {
        # Strip the non-visible OSC 9;9 / OSC 7 control sequences (ESC ] ... ESC \)
        $visible = $script:rendered -replace "$ESC\][^$ESC]*$ESC\\", ''
        $visible | Should -Match "^$([regex]::Escape($ESC))\[G"
    }

    It 'breaks internal lines with CR+LF+ESC[K, not a bare LF' {
        $script:rendered | Should -Match "\r\n$([regex]::Escape($ESC))\[K"
        # No LF that is not preceded by CR (would staircase on a stuck console)
        $script:rendered | Should -Not -Match "(?<!\r)\n"
    }
}

Describe 'Get-GitPromptInfo — unborn (commitless) repo' {
    # A freshly `git init`ed repo has an unborn branch; `rev-parse --abbrev-ref HEAD`
    # exits 128 there, which used to wipe the whole git segment. The gate must instead
    # rely on `rev-parse --git-dir` (succeeds on unborn) + `branch --show-current`.
    It 'returns repo info with the branch name before the first commit' {
        $repo = New-TempGitRepo
        Push-Location $repo
        try { $info = Get-GitPromptInfo } finally { Pop-Location }
        $info | Should -Not -BeNullOrEmpty          # IsRepo signal: non-null == in a repo
        $info.Branch | Should -Be 'main'
    }
}

Describe 'Get-GitPromptInfo — unmerged/conflict counting' {
    It 'does not count an AD (staged add, deleted in worktree) pair as a conflict' {
        $repo = New-TempGitRepo
        Push-Location $repo
        try {
            Set-Content -LiteralPath (Join-Path $repo 'newfile') -Value 'hi'
            git add newfile 2>$null
            Remove-Item -LiteralPath (Join-Path $repo 'newfile')   # -> "AD newfile"
            $info = Get-GitPromptInfo
        } finally { Pop-Location }
        $info.Conflicts | Should -Be 0
        $info.Staged    | Should -Be 1   # the 'A' still counts as staged
        $info.Deleted   | Should -Be 1   # the worktree 'D' still counts as deleted
    }

    It 'counts a real merge conflict (UU) as a conflict' {
        $repo = New-TempGitRepo
        Push-Location $repo
        try {
            Set-Content -LiteralPath (Join-Path $repo 'f.txt') -Value 'base'
            git add f.txt 2>$null; git commit -q -m base 2>$null
            git checkout -q -b other 2>$null
            Set-Content -LiteralPath (Join-Path $repo 'f.txt') -Value 'other'
            git commit -q -am other 2>$null
            git checkout -q main 2>$null
            Set-Content -LiteralPath (Join-Path $repo 'f.txt') -Value 'main'
            git commit -q -am main 2>$null
            git merge -q other 2>$null   # fails -> "UU f.txt"
            $info = Get-GitPromptInfo
        } finally { Pop-Location }
        $info.Conflicts | Should -BeGreaterThan 0
    }
}

Describe 'Get-GitPromptInfo — copied (C) index status counts as staged' {
    # `git status --porcelain` v1 emits a C code for a copy-detected index entry, but
    # it is impractical to force deterministically from real git, so shadow `git` with
    # a function that returns a canned porcelain including a C row. Cross-platform:
    # a PowerShell function shadows the native executable in command resolution.
    It 'increments Staged for a C (copied) index entry' {
        function global:git {
            $a = $args -join ' '
            $global:LASTEXITCODE = 0
            if ($a -like 'rev-parse*')            { return @('/repo', '/repo/.git', '/repo/.git') }
            if ($a -like 'branch --show-current*') { return 'main' }
            if ($a -like 'rev-list*')             { $global:LASTEXITCODE = 1; return }
            if ($a -like 'status --porcelain*')   { return @('C  copied.txt', 'A  added.txt') }
            return
        }
        # `Remove-Item function:global:git` silently no-ops (the global: qualifier is
        # not honoured on the function: drive), leaking the shadow into later suites in
        # the same Pester process. `function:git` removes it for real.
        try { $info = Get-GitPromptInfo } finally { Remove-Item function:git -ErrorAction Ignore }
        $info.Staged | Should -Be 2   # both the C (copied) and the A (added)
    }
}

Describe 'prompt skips VCS helpers on non-FileSystem providers' {
    It 'does not invoke git/jj helpers under a non-FileSystem provider (Env:)' {
        Mock Get-GitPromptInfo { $null }
        Mock Get-JjPromptInfo  { $null }
        Push-Location Env:
        try { $null = prompt } finally { Pop-Location }
        Should -Invoke Get-GitPromptInfo -Times 0
        Should -Invoke Get-JjPromptInfo  -Times 0
    }

    It 'does invoke the VCS helpers under a FileSystem provider (positive control)' {
        Mock Get-GitPromptInfo { $null }
        Mock Get-JjPromptInfo  { $null }
        $repo = New-TempGitRepo
        Push-Location $repo
        try { $null = prompt } finally { Pop-Location }
        Should -Invoke Get-JjPromptInfo  -Times 1
        Should -Invoke Get-GitPromptInfo -Times 1
    }
}

AfterAll {
    if ($global:PromptCache.AzInvocation) {
        try { $global:PromptCache.AzInvocation.PowerShell.Dispose() } catch {}
    }
    if ($global:PromptCache.AzRunspace) {
        try { $global:PromptCache.AzRunspace.Dispose() } catch {}
    }
    # Restore git env and clean up temp repos.
    foreach ($k in $script:gitEnvKeys) {
        if ($null -eq $script:gitEnvSaved[$k]) { Remove-Item "Env:\$k" -ErrorAction Ignore }
        else { Set-Item "Env:\$k" $script:gitEnvSaved[$k] }
    }
    if (Test-Path -LiteralPath $script:emptyGitConfig) { Remove-Item -LiteralPath $script:emptyGitConfig -ErrorAction Ignore }
    foreach ($r in $script:tempRepos) {
        if (Test-Path -LiteralPath $r) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction Ignore }
    }
}
