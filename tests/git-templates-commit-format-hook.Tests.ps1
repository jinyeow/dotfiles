#Requires -Version 7
# Behavioural tests for the commit-format check in git/templates/hooks/commit-msg. The
# hook is POSIX sh, so the suite drives the shipped hook directly through a real bash
# (skip, not false-green, when absent), against throwaway repos that set
# work.commitFormat (or leave it unset). Every git call sees an empty global config and
# no system config, so the developer's own settings cannot turn either check on.
# The AI-reference scan in the same hook is covered by
# tests/git-templates-ai-reference-hook.Tests.ps1.

. (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')
$script:HasBash = [bool](Resolve-TestBash)

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    . (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')
    $script:TestBash = Resolve-TestBash
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:CommitMsgHook = Join-Path $script:RepoRoot 'git/templates/hooks/commit-msg'

    $script:Root = Join-Path ([IO.Path]::GetTempPath()) ('commit-format-' + [guid]::NewGuid())
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

    # A throwaway repo with the given work.* keys in its local config.
    function New-TestRepo
    {
        param([string] $CommitFormat, [string] $AiReferenceScan)

        $repo = Join-Path $script:Root ('repo-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init -q . 2>&1 | Out-Null
        if ($CommitFormat)
        {
            & git -C $repo config work.commitFormat $CommitFormat 2>&1 | Out-Null
        }
        if ($AiReferenceScan)
        {
            & git -C $repo config work.aiReferenceScan $AiReferenceScan 2>&1 | Out-Null
        }
        return $repo
    }

    # Runs the shipped commit-msg hook against a message, returning exit code + output.
    function Invoke-CommitMsgHook
    {
        param(
            [string] $Repo,
            [string] $Message,
            [hashtable] $Env = @{}
        )

        $msgFile = Join-Path $Repo 'COMMIT_EDITMSG'
        Set-Content -Path $msgFile -Value $Message -NoNewline

        $envAssignments = ($Env.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '
        Push-Location $Repo
        try
        {
            $hook = $script:CommitMsgHook -replace '\\', '/'
            $msg = $msgFile -replace '\\', '/'
            $out = & $script:TestBash -c "$envAssignments `"$hook`" `"$msg`"" 2>&1 | Out-String
            $rc = $LASTEXITCODE
        }
        finally
        {
            Pop-Location
        }
        return @{ ExitCode = $rc; Output = $out }
    }
}

AfterAll {
    # [NullString]::Value unsets a variable that was unset before. A plain $null reaches
    # .NET as ''.
    foreach ($name in $script:SavedEnv.Keys)
    {
        $value = if ($null -eq $script:SavedEnv[$name]) { [NullString]::Value } else { $script:SavedEnv[$name] }
        [Environment]::SetEnvironmentVariable($name, $value)
    }
    Remove-Item -Path $script:Root -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'git/templates/hooks/commit-msg format check' -Skip:(-not $script:HasBash) {
    It 'allows "<Subject>"' -ForEach @(
        @{ Subject = 'feat(api): [#123] add the endpoint' }
        @{ Subject = 'fix: [#1] a thing' }
        @{ Subject = 'refactor(db)!: [#22] drop a parameter' }
        @{ Subject = "chore(deps): [#5] bump tools`n`nBody line." }
        @{ Subject = "feat(api): [#123] add the endpoint`r`n`r`nBody line." }
        @{ Subject = "# a leading comment`nfeat: [#9] after a comment line" }
        @{ Subject = 'Merge branch ''main'' into feature/1-x' }
        @{ Subject = 'Revert "feat: [#1] a thing"' }
        @{ Subject = 'Reapply "feat: [#1] a thing"' }
        @{ Subject = 'fixup! feat: [#1] a thing' }
        @{ Subject = 'squash! feat: [#1] a thing' }
        @{ Subject = 'amend! feat: [#1] a thing' }
    ) {
        $repo = New-TestRepo -CommitFormat 'true'
        $r = Invoke-CommitMsgHook -Repo $repo -Message $Subject
        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'blocks "<Subject>"' -ForEach @(
        @{ Subject = 'add the thing' }
        @{ Subject = 'feat: add the thing' }
        @{ Subject = 'feat(api): add the thing' }
        @{ Subject = 'feature: [#1] add the thing' }
        @{ Subject = 'feat: [#] add the thing' }
        @{ Subject = 'feat: [#12] ' }
        @{ Subject = 'feat:[#12] no space' }
        @{ Subject = 'Feat: [#12] capital type' }
        @{ Subject = "`n`r`nadd the thing after blank lines" }
    ) {
        $repo = New-TestRepo -CommitFormat 'true'
        $r = Invoke-CommitMsgHook -Repo $repo -Message $Subject
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'Commit-format check blocked'
        $r.Output | Should -Match 'feat\(api\): \[#123\] add the endpoint'
        $r.Output | Should -Match 'SKIP_COMMIT_FORMAT=1'
    }

    It 'names the old style for "<Subject>"' -ForEach @(
        @{ Subject = '[#123]-feat(x): add it'; Style = 'leading \[#id\] prefix' }
        @{ Subject = 'feat(x): add it AB#123'; Style = 'AB#id reference' }
        @{ Subject = 'feat(x): add it #123'; Style = 'bare #id' }
        @{ Subject = 'feat(x): #123 add it'; Style = 'bare #id' }
    ) {
        $repo = New-TestRepo -CommitFormat 'true'
        $r = Invoke-CommitMsgHook -Repo $repo -Message $Subject
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match "old style with an? $Style"
    }

    It 'checks the first non-comment line, not a later one' {
        $repo = New-TestRepo -CommitFormat 'true'
        $r = Invoke-CommitMsgHook -Repo $repo -Message "# comment`nadd the thing`n`nfeat: [#1] later line"
        $r.ExitCode | Should -Not -Be 0
    }

    It 'honours SKIP_COMMIT_FORMAT=1' {
        $repo = New-TestRepo -CommitFormat 'true'
        $r = Invoke-CommitMsgHook -Repo $repo -Message 'add the thing' -Env @{ SKIP_COMMIT_FORMAT = '1' }
        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'does not check the format when the key is <Case>' -ForEach @(
        @{ Case = 'unset'; Value = '' }
        @{ Case = 'false'; Value = 'false' }
        @{ Case = 'not a boolean'; Value = 'not-a-bool' }
    ) {
        $repo = New-TestRepo -CommitFormat $Value
        $r = Invoke-CommitMsgHook -Repo $repo -Message 'add the thing'
        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'does not check the format when only the AI-reference scan is on' {
        $repo = New-TestRepo -AiReferenceScan 'true'
        $r = Invoke-CommitMsgHook -Repo $repo -Message 'add the thing'
        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'still runs the AI-reference scan when SKIP_COMMIT_FORMAT=1' {
        $repo = New-TestRepo -CommitFormat 'true' -AiReferenceScan 'true'
        $r = Invoke-CommitMsgHook -Repo $repo -Message 'feat: [#1] written by Claude' -Env @{ SKIP_COMMIT_FORMAT = '1' }
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'AI-reference scan blocked'
        $r.Output | Should -Not -Match 'Commit-format check blocked'
    }

    It 'still runs the format check when SKIP_AI_REFERENCE_SCAN=1' {
        $repo = New-TestRepo -CommitFormat 'true' -AiReferenceScan 'true'
        $r = Invoke-CommitMsgHook -Repo $repo -Message 'add the thing' -Env @{ SKIP_AI_REFERENCE_SCAN = '1' }
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'Commit-format check blocked'
    }

    It 'reports both checks in one run' {
        $repo = New-TestRepo -CommitFormat 'true' -AiReferenceScan 'true'
        $r = Invoke-CommitMsgHook -Repo $repo -Message 'add the thing, written by Claude'
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'Commit-format check blocked'
        $r.Output | Should -Match 'AI-reference scan blocked'
    }
}
