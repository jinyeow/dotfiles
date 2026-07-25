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
    # `git status --porcelain=v2` emits a copy as a `2` record with X=C, but it is
    # impractical to force copy-detection deterministically from real git, so shadow
    # `git` with a function that returns canned v2 output including a `2 C.` row.
    # Cross-platform: a PowerShell function shadows the native executable in command
    # resolution. The canned output matches the NEW single `status --porcelain=v2
    # --branch` command (branch + ahead/behind + records all in one stream).
    It 'increments Staged for a C (copied) index entry' {
        function global:git {
            $a = $args -join ' '
            $global:LASTEXITCODE = 0
            if ($a -like 'rev-parse*')          { return @('/repo', '/repo/.git', '/repo/.git') }
            if ($a -like 'status --porcelain=v2*') {
                return @(
                    '# branch.oid 0000000000000000000000000000000000000000',
                    '# branch.head main',
                    # `2` record, XY = C. (index copy, worktree unchanged): X=C -> Staged++
                    "2 C. N... 100644 100644 100644 1111111111111111111111111111111111111111 1111111111111111111111111111111111111111 C100 copied.txt`tsrc.txt",
                    # `1` record, XY = A. (index add, worktree unchanged): X=A -> Staged++
                    '1 A. N... 000000 100644 100644 0000000000000000000000000000000000000000 2222222222222222222222222222222222222222 added.txt'
                )
            }
            return
        }
        # `Remove-Item function:global:git` silently no-ops (the global: qualifier is
        # not honoured on the function: drive), leaking the shadow into later suites in
        # the same Pester process. `function:git` removes it for real.
        try { $info = Get-GitPromptInfo } finally { Remove-Item function:git -ErrorAction Ignore }
        $info.Staged | Should -Be 2   # both the C (copied) and the A (added)
    }
}

Describe 'Get-GitPromptInfo — porcelain v2 branch + ahead/behind parse' {
    It 'reports the branch name and ahead/behind from a single status --porcelain=v2 --branch stream' {
        # `# branch.ab +A -B`: + is ahead, - is behind (opposite operand order from the
        # old `rev-list --left-right --count @{upstream}...HEAD`, which printed behind ahead).
        function global:git {
            $a = $args -join ' '
            $global:LASTEXITCODE = 0
            if ($a -like 'rev-parse*')          { return @('/repo', '/repo/.git', '/repo/.git') }
            if ($a -like 'status --porcelain=v2*') {
                return @(
                    '# branch.oid 0000000000000000000000000000000000000000',
                    '# branch.head feature/x',
                    '# branch.upstream origin/feature/x',
                    '# branch.ab +2 -3'
                )
            }
            return
        }
        try { $info = Get-GitPromptInfo } finally { Remove-Item function:git -ErrorAction Ignore }
        $info.Branch | Should -Be 'feature/x'
        $info.Ahead  | Should -Be 2
        $info.Behind | Should -Be 3
    }

    It 'renders a detached HEAD as an empty branch' {
        function global:git {
            $a = $args -join ' '
            $global:LASTEXITCODE = 0
            if ($a -like 'rev-parse*')          { return @('/repo', '/repo/.git', '/repo/.git') }
            if ($a -like 'status --porcelain=v2*') {
                return @(
                    '# branch.oid abcdef0000000000000000000000000000000000',
                    '# branch.head (detached)'
                )
            }
            return
        }
        try { $info = Get-GitPromptInfo } finally { Remove-Item function:git -ErrorAction Ignore }
        # Detached: Branch stays empty/null so the prompt's `elseif ($git.Branch)` skips it.
        $info.Branch | Should -BeNullOrEmpty
    }
}

Describe 'Get-GitPromptInfo — renamed (R) index status counts as renamed' {
    It 'increments Renamed for a real git mv after a commit' {
        $repo = New-TempGitRepo
        Push-Location $repo
        try {
            Set-Content -LiteralPath (Join-Path $repo 'orig.txt') -Value "l1`nl2`nl3`nl4"
            git add orig.txt 2>$null; git commit -q -m base 2>$null
            git mv orig.txt renamed.txt 2>$null   # -> "2 R. ... renamed.txt<TAB>orig.txt"
            $info = Get-GitPromptInfo
        } finally { Pop-Location }
        $info.Renamed | Should -Be 1
        $info.Staged  | Should -Be 0   # a rename is NOT double-counted as staged
    }
}

Describe 'Get-GitPromptInfo — git invocation count' {
    It 'spawns at most 2 git processes for a normal (non-bare) prompt-info call' {
        # The rewrite collapsed 4 spawns (rev-parse + branch + rev-list + status) to 2
        # (rev-parse gate/top-level/worktree + one status --porcelain=v2 --branch).
        $global:gitCallCount = 0
        function global:git {
            $global:gitCallCount++
            $a = $args -join ' '
            $global:LASTEXITCODE = 0
            if ($a -like 'rev-parse*')          { return @('/repo', '/repo/.git', '/repo/.git') }
            if ($a -like 'status --porcelain=v2*') {
                return @(
                    '# branch.oid 0000000000000000000000000000000000000000',
                    '# branch.head main',
                    '# branch.ab +0 -0',
                    '1 .M N... 100644 100644 100644 3333333333333333333333333333333333333333 3333333333333333333333333333333333333333 f.txt'
                )
            }
            return
        }
        try { $info = Get-GitPromptInfo } finally { Remove-Item function:git -ErrorAction Ignore }
        $global:gitCallCount | Should -BeLessOrEqual 2
        $info.Modified       | Should -Be 1   # proves the status stream was actually parsed
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

Describe 'Get-AzCliAccountSegment — az CLI account tag' {
    BeforeEach { $script:origAzDir = $env:AZURE_CONFIG_DIR }
    AfterEach {
        if ($null -eq $script:origAzDir) { Remove-Item Env:AZURE_CONFIG_DIR -ErrorAction Ignore }
        else { $env:AZURE_CONFIG_DIR = $script:origAzDir }
    }

    It 'renders az:personal when AZURE_CONFIG_DIR is set (personal account active)' {
        $env:AZURE_CONFIG_DIR = Join-Path $HOME '.azure-personal'
        Get-AzCliAccountSegment | Should -Match 'az:.*personal'
    }

    It 'renders az:work when AZURE_CONFIG_DIR is unset (default work account)' {
        Remove-Item Env:AZURE_CONFIG_DIR -ErrorAction Ignore
        Get-AzCliAccountSegment | Should -Match 'az:.*work'
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
