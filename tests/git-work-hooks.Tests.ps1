#Requires -Version 7
# Behavioural tests for the work-only hooks in git/templates/work-hooks/, which the
# [hook "work-checks"] (pre-commit), [hook "work-push-warnings"] and
# [hook "work-push-lint"] (pre-push) stanzas in git/gitconfig-work run. The stanzas
# themselves are pinned by tests/git-config.Tests.ps1.
#
# The dispatchers are POSIX sh, so the suite runs the shipped scripts through sh from a
# real bash (skip, not false-green, when absent), in throwaway repos, with the pre-push
# input on stdin. This needs no config-based hooks, so it runs on any git version. Every
# git call sees an empty global config and no system config, so the developer's own
# hooks and settings cannot change the result.

. (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')
$script:HasBash = [bool](Resolve-TestBash)
# Runs at DISCOVERY time, because -Skip: is evaluated then. The JSON check and the
# PowerShell lint start `pwsh` from PATH; the lint also needs the PSScriptAnalyzer module.
$script:HasPwsh = [bool](Get-Command -Name pwsh -CommandType Application -ErrorAction Ignore)
$script:HasAnalyzer = $script:HasPwsh -and [bool](Get-Module -ListAvailable -Name PSScriptAnalyzer)

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    . (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')
    $script:TestBash = Resolve-TestBash
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:WorkHooksDir = Join-Path $script:RepoRoot 'git/templates/work-hooks'
    $script:ZeroSha = '0' * 40
    # A settings file that turns on one rule, so a Write-Host call is a finding.
    $script:WriteHostSettings = "@{ IncludeRules = @('PSAvoidUsingWriteHost') }`n"

    $script:Root = Join-Path ([IO.Path]::GetTempPath()) ('git-work-hooks-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:Root -Force | Out-Null
    $emptyGlobal = Join-Path $script:Root 'empty.gitconfig'
    Set-Content -Path $emptyGlobal -Value '' -NoNewline

    $script:SavedEnv = @{}
    foreach ($name in 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM')
    {
        $script:SavedEnv[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    $env:GIT_CONFIG_GLOBAL = $emptyGlobal
    $env:GIT_CONFIG_NOSYSTEM = '1'

    # Restores environment variables saved as a name -> value table. [NullString]::Value
    # unsets a variable that was unset before. A plain $null reaches .NET as ''.
    function Restore-TestEnv
    {
        param([hashtable] $Saved)

        foreach ($name in $Saved.Keys)
        {
            $value = if ($null -eq $Saved[$name]) { [NullString]::Value } else { $Saved[$name] }
            [Environment]::SetEnvironmentVariable($name, $value)
        }
    }

    # A throwaway repo with an origin remote, on a branch the protected-branch check
    # allows, so tests of the other checks are not blocked by it.
    function New-WorkRepo
    {
        param([string] $Branch = 'feature/x')

        $repo = Join-Path $script:Root ('repo-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init -q -b $Branch .
        & git -C $repo config user.email 'test@example.invalid'
        & git -C $repo config user.name 'Test'
        & git -C $repo config core.autocrlf false
        & git -C $repo remote add origin 'https://example.invalid/repo.git'
        return $repo
    }

    # A work repo with a local bare origin whose main holds one seed commit, checked out
    # on feature/x branched from it.
    function New-PushRepo
    {
        $repo = New-WorkRepo -Branch 'main'
        $origin = Join-Path $script:Root ('origin-' + [guid]::NewGuid().ToString('N') + '.git')
        & git init -q --bare $origin
        & git -C $repo remote set-url origin ($origin -replace '\\', '/')
        Add-StagedFile -Repo $repo -Path 'seed.txt' -Content "seed`n"
        & git -C $repo commit -q --no-verify -m 'seed' 2>&1 | Out-Null
        & git -C $repo push -q --no-verify origin main 2>&1 | Out-Null
        & git -C $repo switch -q -c 'feature/x' 2>&1 | Out-Null
        return $repo
    }

    # Writes $Content as raw bytes (no newline translation) and stages it.
    function Add-StagedFile
    {
        param([string] $Repo, [string] $Path, [string] $Content)

        $full = Join-Path $Repo $Path
        New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
        [IO.File]::WriteAllText($full, $Content)
        & git -C $Repo add -- $Path
    }

    # Commits everything staged, with no hooks.
    function Save-Commit
    {
        param([string] $Repo, [string] $Message = 'change')

        & git -C $Repo commit -q --no-verify -m $Message 2>&1 | Out-Null
    }

    # One pre-push stdin line for pushing $LocalRef to $RemoteRef as a new remote branch.
    function Get-PushLine
    {
        param(
            [string] $Repo,
            [string] $LocalRef = 'refs/heads/feature/x',
            [string] $RemoteRef = 'refs/heads/feature/x'
        )

        [string] $sha = & git -C $Repo rev-parse $LocalRef
        return "$LocalRef $($sha.Trim()) $RemoteRef $script:ZeroSha`n"
    }

    # Runs a shipped work hook through sh in $Repo, with $Stdin on its standard input and
    # each variable in $Env set for the run. Returns the exit code and the output.
    function Invoke-WorkHook
    {
        param(
            [string] $Repo,
            [string] $Hook,
            [string] $Stdin = '',
            [hashtable] $Env = @{}
        )

        $hookPath = (Join-Path $script:WorkHooksDir $Hook) -replace '\\', '/'
        $stdinPath = Join-Path $script:Root ('stdin-' + [guid]::NewGuid().ToString('N') + '.txt')
        [IO.File]::WriteAllText($stdinPath, $Stdin)

        $saved = @{}
        foreach ($name in $Env.Keys)
        {
            $saved[$name] = [Environment]::GetEnvironmentVariable($name)
            [Environment]::SetEnvironmentVariable($name, $Env[$name])
        }
        Push-Location $Repo
        try
        {
            $out = & $script:TestBash -c 'exec sh "$0" < "$1"' $hookPath ($stdinPath -replace '\\', '/') 2>&1 | Out-String
            $rc = $LASTEXITCODE
        }
        finally
        {
            Pop-Location
            Restore-TestEnv -Saved $saved
        }
        return [pscustomobject]@{ ExitCode = $rc; Output = $out }
    }

    # A directory holding a fake `bicep` that prints one finding for each lint call.
    function New-FakeBicep
    {
        $bin = Join-Path $script:Root ('bin-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $bin -Force | Out-Null
        $path = Join-Path $bin 'bicep'
        Set-Content -Path $path -Encoding ASCII -NoNewline -Value "#!/bin/sh`necho `"FAKE-BICEP `$1 `$2: Warning no-unused-params`"`nexit 0`n"
        if (Get-Command chmod -ErrorAction SilentlyContinue) { & chmod +x $path }
        return $bin
    }
}

AfterAll {
    Restore-TestEnv -Saved $script:SavedEnv
    Remove-Item -Path $script:Root -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'git/templates/work-hooks/checks' -Skip:(-not $script:HasBash) {
    It 'blocks a commit on protected branch <Branch>' -ForEach @(
        @{ Branch = 'main' }
        @{ Branch = 'master' }
        @{ Branch = 'wikiMaster' }
    ) {
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path 'a.txt' -Content "a`n"
        Save-Commit -Repo $repo -Message 'seed'
        & git -C $repo switch -q -c $Branch 2>&1 | Out-Null
        Add-StagedFile -Repo $repo -Path 'b.txt' -Content "b`n"

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks'

        $r.ExitCode | Should -Not -Be 0 -Because $r.Output
        $r.Output | Should -Match "protected branch '$Branch'"
        $r.Output | Should -Match 'SKIP_PROTECTED_BRANCH=1'
    }

    It 'allows a protected-branch commit with SKIP_PROTECTED_BRANCH=1' {
        $repo = New-WorkRepo -Branch 'main'
        Add-StagedFile -Repo $repo -Path 'a.txt' -Content "a`n"
        Save-Commit -Repo $repo -Message 'seed'
        Add-StagedFile -Repo $repo -Path 'b.txt' -Content "b`n"

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks' -Env @{ SKIP_PROTECTED_BRANCH = '1' }

        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'allows a commit on <Case>' -ForEach @(
        @{ Case = 'a feature branch'; Setup = 'none' }
        @{ Case = 'a detached HEAD'; Setup = 'detach' }
        @{ Case = 'an unborn main'; Setup = 'unborn' }
        @{ Case = 'main in a repo with no remote'; Setup = 'no-remote' }
    ) {
        $repo = New-WorkRepo
        if ($Setup -eq 'unborn')
        {
            & git -C $repo symbolic-ref HEAD refs/heads/main
        }
        else
        {
            Add-StagedFile -Repo $repo -Path 'a.txt' -Content "a`n"
            Save-Commit -Repo $repo -Message 'seed'
        }
        if ($Setup -eq 'detach')
        {
            & git -C $repo switch -q --detach 2>&1 | Out-Null
        }
        if ($Setup -eq 'no-remote')
        {
            & git -C $repo switch -q -c main 2>&1 | Out-Null
            & git -C $repo remote remove origin
        }
        Add-StagedFile -Repo $repo -Path 'b.txt' -Content "b`n"

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks'

        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'blocks a staged conflict marker: <Name>' -ForEach @(
        @{ Name = 'opening with a label'; Line = '<<<<<<< HEAD' }
        @{ Name = 'closing with a label'; Line = '>>>>>>> topic' }
        @{ Name = 'bare opening'; Line = '<<<<<<<' }
        @{ Name = 'bare closing with a CR'; Line = ">>>>>>>`r" }
    ) {
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path 'dir with space/c.txt' -Content "ok`n$Line`nok`n"

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks'

        $r.ExitCode | Should -Not -Be 0 -Because $r.Output
        $r.Output | Should -Match 'conflict marker'
        $r.Output | Should -Match 'dir with space/c\.txt'
        $r.Output | Should -Match 'SKIP_CONFLICT_MARKERS=1'
    }

    It 'allows a Markdown setext heading' {
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path 'README.md' -Content "Title`n=======`n"

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks'

        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'allows a conflict marker with SKIP_CONFLICT_MARKERS=1' {
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path 'c.txt' -Content "<<<<<<< HEAD`n"

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks' -Env @{ SKIP_CONFLICT_MARKERS = '1' }

        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'blocks a staged .sh file whose index content has CRLF' {
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path 'my scripts/run.sh' -Content "#!/bin/sh`r`necho hi`r`n"
        # Fix the worktree copy only: the check must read the staged blob.
        [IO.File]::WriteAllText((Join-Path $repo 'my scripts/run.sh'), "#!/bin/sh`necho hi`n")

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks'

        $r.ExitCode | Should -Not -Be 0 -Because $r.Output
        $r.Output | Should -Match 'CRLF'
        $r.Output | Should -Match 'my scripts/run\.sh'
        $r.Output | Should -Match 'SKIP_SH_CRLF=1'
    }

    It 'allows an LF .sh file staged over a CRLF worktree copy' {
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path 'run.sh' -Content "#!/bin/sh`necho hi`n"
        [IO.File]::WriteAllText((Join-Path $repo 'run.sh'), "#!/bin/sh`r`necho hi`r`n")

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks'

        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'allows a CRLF .sh file with SKIP_SH_CRLF=1' {
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path 'b.sh' -Content "echo b`r`n"

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks' -Env @{ SKIP_SH_CRLF = '1' }

        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'reports every failing check in one run' {
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path 'c.txt' -Content "<<<<<<< HEAD`n"
        Add-StagedFile -Repo $repo -Path 'b.sh' -Content "echo b`r`n"

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks'

        $r.ExitCode | Should -Not -Be 0 -Because $r.Output
        $r.Output | Should -Match 'SKIP_CONFLICT_MARKERS=1'
        $r.Output | Should -Match 'SKIP_SH_CRLF=1'
    }

    It 'blocks staged .json files that do not parse, read from the index' -Skip:(-not $script:HasPwsh) {
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path 'env/my env/params.json' -Content '{ "a": 1, '
        # Fix the worktree copy only: the check must read the staged blob.
        [IO.File]::WriteAllText((Join-Path $repo 'env/my env/params.json'), '{ "a": 1 }')
        Add-StagedFile -Repo $repo -Path 'empty.json' -Content ''
        Add-StagedFile -Repo $repo -Path 'ok.json' -Content '{ "a": 1 }'

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks'

        $r.ExitCode | Should -Not -Be 0 -Because $r.Output
        $r.Output | Should -Match 'env/my env/params\.json'
        $r.Output | Should -Match 'empty\.json'
        $r.Output | Should -Not -Match 'ok\.json'
        $r.Output | Should -Match 'SKIP_JSON_CHECK=1'
    }

    It 'allows JSONC comments, a BOM and keys that differ only by case' -Skip:(-not $script:HasPwsh) {
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path '.vscode/settings.json' -Content "{`n  // comment`n  `"a`": 1, /* b */`n}`n"
        [IO.File]::WriteAllText((Join-Path $repo 'bom.json'), '{ "a": "x" }', [Text.UTF8Encoding]::new($true))
        & git -C $repo add bom.json
        Add-StagedFile -Repo $repo -Path 'case.json' -Content '{ "a": 1, "A": 2 }'

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks'

        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'allows a .json file that does not parse with SKIP_JSON_CHECK=1' {
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path 'bad.json' -Content '{'

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks' -Env @{ SKIP_JSON_CHECK = '1' }

        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'warns and skips the JSON check when pwsh is not on PATH' -Skip:(-not $IsWindows) {
        # Windows only: the PATH below is Git for Windows' own tools, which has no pwsh.
        # Git's bin/bash.exe adds its usr/bin, so sh and the POSIX tools still resolve.
        $repo = New-WorkRepo
        Add-StagedFile -Repo $repo -Path 'bad.json' -Content '{'
        $gitRoot = Split-Path (Split-Path $script:TestBash -Parent) -Parent

        $r = Invoke-WorkHook -Repo $repo -Hook 'checks' -Env @{ PATH = "$gitRoot\cmd;$gitRoot\usr\bin" }

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'pwsh not found'
    }
}

Describe 'git/templates/work-hooks/push-warnings' -Skip:(-not $script:HasBash) {
    It 'warns without blocking when the upstream is gone' {
        $repo = New-PushRepo
        Add-StagedFile -Repo $repo -Path 'a.txt' -Content "a`n"
        Save-Commit -Repo $repo
        & git -C $repo push -q --no-verify -u origin 'feature/x' 2>&1 | Out-Null
        $origin = & git -C $repo remote get-url origin
        & git -C $origin branch -q -D 'feature/x'
        & git -C $repo fetch -q --prune 2>&1 | Out-Null

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-warnings' -Stdin (Get-PushLine -Repo $repo)

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'the upstream of feature/x is gone'
        $r.Output | Should -Match 'remote-tracking refs'
        $r.Output | Should -Not -Match 'behind'
    }

    It 'resolves the branch when the local ref is HEAD' {
        # `git push origin HEAD` passes HEAD as the local ref, not refs/heads/*.
        $repo = New-PushRepo
        Add-StagedFile -Repo $repo -Path 'a.txt' -Content "a`n"
        Save-Commit -Repo $repo
        & git -C $repo push -q --no-verify -u origin 'feature/x' 2>&1 | Out-Null
        $origin = & git -C $repo remote get-url origin
        & git -C $origin branch -q -D 'feature/x'
        & git -C $repo fetch -q --prune 2>&1 | Out-Null

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-warnings' -Stdin (Get-PushLine -Repo $repo -LocalRef 'HEAD')

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'the upstream of feature/x is gone'
    }

    It 'warns without blocking when the branch is more than 20 commits behind origin/main' {
        $repo = New-PushRepo
        & git -C $repo switch -q main 2>&1 | Out-Null
        foreach ($i in 1..21)
        {
            & git -C $repo commit -q --no-verify --allow-empty -m "m$i" 2>&1 | Out-Null
        }
        & git -C $repo push -q --no-verify origin main 2>&1 | Out-Null
        & git -C $repo switch -q 'feature/x' 2>&1 | Out-Null
        Add-StagedFile -Repo $repo -Path 'a.txt' -Content "a`n"
        Save-Commit -Repo $repo

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-warnings' -Stdin (Get-PushLine -Repo $repo)

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'feature/x is 21 commits behind origin/main'
    }

    It 'does not warn at exactly 20 commits behind' {
        $repo = New-PushRepo
        & git -C $repo switch -q main 2>&1 | Out-Null
        foreach ($i in 1..20)
        {
            & git -C $repo commit -q --no-verify --allow-empty -m "m$i" 2>&1 | Out-Null
        }
        & git -C $repo push -q --no-verify origin main 2>&1 | Out-Null
        & git -C $repo switch -q 'feature/x' 2>&1 | Out-Null

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-warnings' -Stdin (Get-PushLine -Repo $repo)

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Not -Match 'behind'
    }

    It 'measures against the branch origin/HEAD points at' {
        # origin/main stays at the seed; origin/develop moves 21 commits ahead of it.
        $repo = New-PushRepo
        & git -C $repo switch -q -c develop main 2>&1 | Out-Null
        foreach ($i in 1..21)
        {
            & git -C $repo commit -q --no-verify --allow-empty -m "d$i" 2>&1 | Out-Null
        }
        & git -C $repo push -q --no-verify origin develop 2>&1 | Out-Null
        & git -C $repo remote set-head origin develop 2>&1 | Out-Null
        & git -C $repo switch -q 'feature/x' 2>&1 | Out-Null

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-warnings' -Stdin (Get-PushLine -Repo $repo)

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'feature/x is 21 commits behind origin/develop'
    }

    It 'skips a tag and a branch delete without output' {
        $repo = New-PushRepo
        & git -C $repo tag v1
        $sha = (& git -C $repo rev-parse HEAD).Trim()
        $tagLine = Get-PushLine -Repo $repo -LocalRef 'refs/tags/v1' -RemoteRef 'refs/tags/v1'
        $stdin = $tagLine + "(delete) $script:ZeroSha refs/heads/old $sha`n"

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-warnings' -Stdin $stdin

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Not -Match 'work-push-warnings:'
    }
}

Describe 'git/templates/work-hooks/push-lint' -Skip:(-not $script:HasBash) {
    It 'warns and skips the PowerShell lint when the repo has no settings file' {
        $repo = New-PushRepo
        Add-StagedFile -Repo $repo -Path 'a.ps1' -Content "Write-Host 'x'`n"
        Save-Commit -Repo $repo

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-lint' -Stdin (Get-PushLine -Repo $repo)

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'no PSScriptAnalyzerSettings\.psd1'
    }

    It 'skips the lint with a warning for a pushed branch that is not checked out' {
        $repo = New-PushRepo
        & git -C $repo switch -q -c 'other' 2>&1 | Out-Null
        Add-StagedFile -Repo $repo -Path 'main.bicep' -Content "param x string`n"
        Save-Commit -Repo $repo
        & git -C $repo switch -q 'feature/x' 2>&1 | Out-Null
        $bin = New-FakeBicep

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-lint' -Stdin (Get-PushLine -Repo $repo -LocalRef 'refs/heads/other' -RemoteRef 'refs/heads/other') -Env @{ PATH = $bin + [IO.Path]::PathSeparator + $env:PATH }

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'other is not checked out'
        $r.Output | Should -Not -Match 'FAKE-BICEP'
    }

    It 'skips a tag and a branch delete' {
        $repo = New-PushRepo
        & git -C $repo tag v1
        $sha = (& git -C $repo rev-parse HEAD).Trim()
        $tagLine = Get-PushLine -Repo $repo -LocalRef 'refs/tags/v1' -RemoteRef 'refs/tags/v1'
        $stdin = $tagLine + "(delete) $script:ZeroSha refs/heads/old $sha`n"

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-lint' -Stdin $stdin

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Not -Match 'work-push-lint:'
    }

    It 'runs bicep lint on each changed .bicep file and blocks on a finding' {
        $repo = New-PushRepo
        Add-StagedFile -Repo $repo -Path 'infra dir/main.bicep' -Content "param x string`n"
        Save-Commit -Repo $repo
        $bin = New-FakeBicep

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-lint' -Stdin (Get-PushLine -Repo $repo) -Env @{ PATH = $bin + [IO.Path]::PathSeparator + $env:PATH }

        $r.ExitCode | Should -Not -Be 0 -Because $r.Output
        $r.Output | Should -Match 'FAKE-BICEP lint .*infra dir/main\.bicep: Warning no-unused-params'
        $r.Output | Should -Match 'SKIP_PUSH_LINT=1'
    }

    It 'does not lint a .bicep file the branch did not change' {
        # main.bicep is on origin/main already, so the merge-base excludes it.
        $repo = New-PushRepo
        & git -C $repo switch -q main 2>&1 | Out-Null
        Add-StagedFile -Repo $repo -Path 'main.bicep' -Content "param x string`n"
        Save-Commit -Repo $repo
        & git -C $repo push -q --no-verify origin main 2>&1 | Out-Null
        & git -C $repo switch -q -C 'feature/x' main 2>&1 | Out-Null
        Add-StagedFile -Repo $repo -Path 'a.txt' -Content "a`n"
        Save-Commit -Repo $repo
        $bin = New-FakeBicep

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-lint' -Stdin (Get-PushLine -Repo $repo) -Env @{ PATH = $bin + [IO.Path]::PathSeparator + $env:PATH }

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Not -Match 'FAKE-BICEP'
    }

    It 'allows a push with findings when SKIP_PUSH_LINT=1' {
        $repo = New-PushRepo
        Add-StagedFile -Repo $repo -Path 'main.bicep' -Content "param x string`n"
        Save-Commit -Repo $repo
        $bin = New-FakeBicep

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-lint' -Stdin (Get-PushLine -Repo $repo) -Env @{ PATH = $bin + [IO.Path]::PathSeparator + $env:PATH; SKIP_PUSH_LINT = '1' }

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Not -Match 'FAKE-BICEP'
    }

    It 'warns and skips bicep lint when bicep is not on PATH' {
        if (Get-Command -Name bicep -CommandType Application -ErrorAction Ignore)
        {
            Set-ItResult -Skipped -Because 'bicep is installed here'
            return
        }
        $repo = New-PushRepo
        Add-StagedFile -Repo $repo -Path 'main.bicep' -Content "param x string`n"
        Save-Commit -Repo $repo

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-lint' -Stdin (Get-PushLine -Repo $repo)

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Match 'bicep not found on PATH'
    }

    It 'lints only the PowerShell files the push changes' -Skip:(-not $script:HasAnalyzer) {
        # A violation already on origin/main must not block, and a file the branch deletes
        # must not be linted.
        $repo = New-PushRepo
        & git -C $repo switch -q main 2>&1 | Out-Null
        Add-StagedFile -Repo $repo -Path '.vscode/PSScriptAnalyzerSettings.psd1' -Content $script:WriteHostSettings
        Add-StagedFile -Repo $repo -Path 'old.ps1' -Content "function Get-Old { Write-Host 'x' }`n"
        Add-StagedFile -Repo $repo -Path 'gone.ps1' -Content "function Get-Gone { Write-Host 'x' }`n"
        Save-Commit -Repo $repo -Message 'base'
        & git -C $repo push -q --no-verify origin main 2>&1 | Out-Null
        & git -C $repo switch -q -C 'feature/x' main 2>&1 | Out-Null
        Add-StagedFile -Repo $repo -Path 'new dir/good.ps1' -Content "function Get-Good { 'x' }`n"
        & git -C $repo rm -q gone.ps1
        Save-Commit -Repo $repo

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-lint' -Stdin (Get-PushLine -Repo $repo)

        $r.ExitCode | Should -Be 0 -Because $r.Output
        $r.Output | Should -Not -Match 'PSAvoidUsingWriteHost'
    }

    It 'blocks on a PSScriptAnalyzer finding in a file whose name has brackets' -Skip:(-not $script:HasAnalyzer) {
        # The brackets in br[1].ps1 must not be read as a wildcard, which finds no file.
        $repo = New-PushRepo
        Add-StagedFile -Repo $repo -Path '.vscode/PSScriptAnalyzerSettings.psd1' -Content $script:WriteHostSettings
        Add-StagedFile -Repo $repo -Path 'src dir/br[1].ps1' -Content "function Get-A { Write-Host 'x' }`n"
        Save-Commit -Repo $repo

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-lint' -Stdin (Get-PushLine -Repo $repo -LocalRef 'HEAD')

        $r.ExitCode | Should -Not -Be 0 -Because $r.Output
        $r.Output | Should -Match 'PSAvoidUsingWriteHost'
        $r.Output | Should -Match 'SKIP_PUSH_LINT=1'
    }

    It 'blocks rather than passes when PSScriptAnalyzer itself errors' -Skip:(-not $script:HasAnalyzer) {
        # A settings file naming a missing custom rule module makes Invoke-ScriptAnalyzer
        # write an error and return no findings; that must not read as a clean lint.
        $repo = New-PushRepo
        Add-StagedFile -Repo $repo -Path 'PSScriptAnalyzerSettings.psd1' -Content "@{ CustomRulePath = @('./missing/Rules.psm1') }`n"
        Add-StagedFile -Repo $repo -Path 'a.ps1' -Content "function Get-A { 'x' }`n"
        Save-Commit -Repo $repo

        $r = Invoke-WorkHook -Repo $repo -Hook 'push-lint' -Stdin (Get-PushLine -Repo $repo)

        $r.ExitCode | Should -Not -Be 0 -Because $r.Output
        $r.Output | Should -Match 'PSScriptAnalyzer failed'
    }
}
