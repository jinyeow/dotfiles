#Requires -Version 7
# Behavioural tests for git/templates/hooks/prepare-commit-msg.ps1 and its POSIX-sh
# sibling prepare-commit-msg.sh. Both variants are driven directly (not through the
# sh dispatcher, which just picks one based on pwsh availability) against a throwaway
# git repo + a fake COMMIT_EDITMSG file, so the suite exercises the shipped hooks
# rather than copies that could drift from them.
#
# Regression coverage: -match is case-insensitive in PowerShell, so branch
# feature/fix-123 used to get a bogus "Refs: fix-123" trailer from the ps1 variant
# (the ticket regex's [A-Z] classes matched the lowercase "fix" case-insensitively).
# The sh variant used [A-Z][A-Z]* (1+ letters) for the project key, which wrongly
# accepted single-letter keys like "A-123" that JIRA never issues (keys are >= 2
# chars) — both fixed here.

# Discovery-time constant: -ForEach is evaluated during Pester's discovery pass,
# before any BeforeAll runs, so this must be a plain script-scope variable, not
# something assigned inside BeforeAll (which would leave -ForEach with nothing to
# iterate and silently produce zero tests).
$script:Variants = @(
    @{ Variant = 'ps1' }
    @{ Variant = 'sh' }
)

BeforeAll {
    . (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')

    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:HooksDir = Join-Path $script:RepoRoot 'git/templates/hooks'
    $script:HookPs1  = Join-Path $script:HooksDir 'prepare-commit-msg.ps1'
    $script:HookSh   = Join-Path $script:HooksDir 'prepare-commit-msg.sh'
    $script:TestBash = Resolve-TestBash

    function New-TestRepo {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('pcm-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        & git -C $root init -q . 2>&1 | Out-Null
        & git -C $root config user.email 'test@example.invalid' 2>&1 | Out-Null
        & git -C $root config user.name 'Test' 2>&1 | Out-Null
        return $root
    }

    # Points HEAD at an unborn branch of the given name, without needing a commit —
    # avoids depending on whatever default branch name the local git/global config
    # would otherwise pick.
    function Set-TestBranch {
        param([string] $Repo, [string] $Branch)
        & git -C $Repo symbolic-ref HEAD "refs/heads/$Branch" 2>&1 | Out-Null
    }

    function Invoke-Hook {
        param(
            [ValidateSet('ps1', 'sh')] [string] $Variant,
            [string] $Repo,
            [string] $MsgFile,
            [string] $Source = ''
        )
        Push-Location $Repo
        try {
            if ($Variant -eq 'ps1') {
                & pwsh -NoProfile -File $script:HookPs1 $MsgFile $Source 2>&1 | Out-Null
            } else {
                if (-not $script:TestBash) {
                    throw 'No usable bash found; Resolve-TestBash returned $null.'
                }
                & $script:TestBash $script:HookSh $MsgFile $Source 2>&1 | Out-Null
            }
        } finally {
            Pop-Location
        }
    }
}

Describe 'prepare-commit-msg hooks (ps1 + sh)' {
    BeforeEach {
        $script:Repo = New-TestRepo
        $script:MsgFile = Join-Path $script:Repo 'COMMIT_EDITMSG'
    }

    AfterEach {
        Remove-Item -Path $script:Repo -Recurse -Force -ErrorAction SilentlyContinue
    }

    It '<Variant> appends a JIRA trailer for feature/PROJ-123-foo' -ForEach $script:Variants {
        Set-TestBranch -Repo $script:Repo -Branch 'feature/PROJ-123-foo'
        Set-Content -Path $script:MsgFile -Value 'Add the thing' -NoNewline
        Invoke-Hook -Variant $Variant -Repo $script:Repo -MsgFile $script:MsgFile
        (Get-Content -Path $script:MsgFile -Raw) | Should -Match 'Refs: PROJ-123'
    }

    It '<Variant> does NOT tag feature/fix-123 (case-sensitive project key)' -ForEach $script:Variants {
        # Regression case: "fix" must not case-insensitively satisfy [A-Z][A-Z]+.
        Set-TestBranch -Repo $script:Repo -Branch 'feature/fix-123'
        Set-Content -Path $script:MsgFile -Value 'Fix the thing' -NoNewline
        Invoke-Hook -Variant $Variant -Repo $script:Repo -MsgFile $script:MsgFile
        (Get-Content -Path $script:MsgFile -Raw) | Should -Not -Match 'Refs:'
    }

    It '<Variant> leaves skip-list branch "<Branch>" untouched' -ForEach @(
        @{ Variant = 'ps1'; Branch = 'master' }
        @{ Variant = 'sh'; Branch = 'master' }
        @{ Variant = 'ps1'; Branch = 'develop' }
        @{ Variant = 'sh'; Branch = 'develop' }
    ) {
        Set-TestBranch -Repo $script:Repo -Branch $Branch
        Set-Content -Path $script:MsgFile -Value 'Some commit' -NoNewline
        Invoke-Hook -Variant $Variant -Repo $script:Repo -MsgFile $script:MsgFile
        (Get-Content -Path $script:MsgFile -Raw) | Should -Be 'Some commit'
    }

    It '<Variant> does not tag a single-letter project key (A-123)' -ForEach $script:Variants {
        # JIRA project keys are >= 2 chars; a single letter must not match.
        Set-TestBranch -Repo $script:Repo -Branch 'feature/A-123-foo'
        Set-Content -Path $script:MsgFile -Value 'Add the thing' -NoNewline
        Invoke-Hook -Variant $Variant -Repo $script:Repo -MsgFile $script:MsgFile
        (Get-Content -Path $script:MsgFile -Raw) | Should -Not -Match 'Refs:'
    }

    It '<Variant> tags an ADO numeric branch feature/1234-foo' -ForEach $script:Variants {
        Set-TestBranch -Repo $script:Repo -Branch 'feature/1234-foo'
        Set-Content -Path $script:MsgFile -Value 'Add the thing' -NoNewline
        Invoke-Hook -Variant $Variant -Repo $script:Repo -MsgFile $script:MsgFile
        (Get-Content -Path $script:MsgFile -Raw) | Should -Match 'Refs: AB#1234'
    }

    It '<Variant> skips merge commit source' -ForEach $script:Variants {
        Set-TestBranch -Repo $script:Repo -Branch 'feature/PROJ-123-foo'
        Set-Content -Path $script:MsgFile -Value 'Merge branch' -NoNewline
        Invoke-Hook -Variant $Variant -Repo $script:Repo -MsgFile $script:MsgFile -Source 'merge'
        (Get-Content -Path $script:MsgFile -Raw) | Should -Be 'Merge branch'
    }
}
