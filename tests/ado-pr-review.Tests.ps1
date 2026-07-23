#Requires -Version 7
# Pester tests for Invoke-AdoPrReview (prr) in powershell/Microsoft.PowerShell_profile.ps1:
# the bare-worktree resolution + guards, review-worktree creation, and the nvim handoff.
# The profile runs side effects at load and is not dot-sourceable, so the function is
# lifted out by AST (same pattern as fzf-pickers.Tests.ps1). az/fzf are never reached
# when -Id is passed; nvim is replaced by a PATH shim that records its arguments, so no
# editor launches. The interactive az/fzf discovery path is not covered here — it needs
# a real ADO remote and a logged-in az.

BeforeAll {
    $profilePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'powershell' 'Microsoft.PowerShell_profile.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$null, [ref]$null)
    $wanted = 'Invoke-AdoPrReview', 'ConvertFrom-AdoRemoteUrl'
    $funcs = $ast.FindAll(
        { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
        Where-Object { $fn = $_.Name; $wanted | Where-Object { $fn -match $_ } }
    foreach ($fn in $funcs) {
        . ([scriptblock]::Create($fn.Extent.Text))
    }

    # nvim shim: records its args instead of launching an editor.
    $script:shimDir = Join-Path $TestDrive 'shims'
    $script:nvimArgsFile = Join-Path $TestDrive 'nvim-args.txt'
    New-Item -ItemType Directory -Path $script:shimDir | Out-Null
    Set-Content -Path (Join-Path $script:shimDir 'nvim.cmd') -Value "@echo %*> `"$script:nvimArgsFile`""
    $script:origPath = $env:PATH
    $env:PATH = $script:shimDir + [IO.Path]::PathSeparator + $env:PATH

    # Bare-worktree fixture: <layout>/.bare + <layout>/main, cloned from a seed repo.
    $seed = Join-Path $TestDrive 'seed'
    git init -b main $seed 2>&1 | Out-Null
    Set-Content -Path (Join-Path $seed 'file.txt') -Value 'seed'
    git -C $seed add file.txt 2>&1 | Out-Null
    git -C $seed -c user.name=test -c user.email=test@test commit -m seed 2>&1 | Out-Null
    $script:layout = Join-Path $TestDrive 'layout'
    git clone --bare $seed (Join-Path $script:layout '.bare') 2>&1 | Out-Null
    git -C (Join-Path $script:layout '.bare') worktree add ../main main 2>&1 | Out-Null
}

AfterAll {
    $env:PATH = $script:origPath
    # git pack/object files are read-only, which Pester's TestDrive cleanup cannot delete.
    Get-ChildItem $TestDrive -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
}

Describe 'ConvertFrom-AdoRemoteUrl' {
    It 'parses the https-with-userinfo form and unescapes names' {
        $r = ConvertFrom-AdoRemoteUrl -Url 'https://MyOrg@dev.azure.com/MyOrg/My%20Project/_git/My.Repo'
        $r.Organization | Should -Be 'MyOrg'
        $r.Project | Should -Be 'My Project'
        $r.Repository | Should -Be 'My.Repo'
    }

    It 'parses the plain https form' {
        $r = ConvertFrom-AdoRemoteUrl -Url 'https://dev.azure.com/MyOrg/Proj/_git/Repo'
        $r.Organization | Should -Be 'MyOrg'
        $r.Project | Should -Be 'Proj'
        $r.Repository | Should -Be 'Repo'
    }

    It 'parses the ssh v3 form' {
        $r = ConvertFrom-AdoRemoteUrl -Url 'git@ssh.dev.azure.com:v3/MyOrg/Proj/Repo'
        $r.Organization | Should -Be 'MyOrg'
        $r.Project | Should -Be 'Proj'
        $r.Repository | Should -Be 'Repo'
    }

    It 'returns nothing for a non-ADO remote' {
        ConvertFrom-AdoRemoteUrl -Url 'git@github.com:user/repo.git' | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-AdoPrReview' {
    BeforeEach {
        Push-Location $TestDrive
    }

    AfterEach {
        # The success path Set-Locations into the review worktree — restore for the next test.
        Pop-Location
    }

    Context 'guards' {
        It 'errors outside a git repository' {
            $bare = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'not-a-repo') -Force
            Set-Location $bare
            $out = Invoke-AdoPrReview -Id 1 2>&1
            $out | Should -Match 'not inside a git repository'
        }

        It 'errors in a normal (non-bare-layout) clone' {
            Set-Location (Join-Path $TestDrive 'seed')
            $out = Invoke-AdoPrReview -Id 1 2>&1
            $out | Should -Match 'bare-worktree layout'
        }
    }

    Context 'success path' {
        It 'creates the detached review worktree beside .bare and hands off to nvim' {
            Set-Location (Join-Path $script:layout 'main')
            Invoke-AdoPrReview -Id 42

            $reviewDir = Join-Path $script:layout 'review'
            Test-Path $reviewDir | Should -BeTrue
            (git -C $reviewDir rev-parse --path-format=absolute --git-common-dir) |
                Should -Be ((Join-Path $script:layout '.bare') -replace '\\', '/')
            (Get-Location).Path | Should -Be $reviewDir
            (Get-Content $script:nvimArgsFile) | Should -Match '\+AdoPrReview 42'
        }

        It 'errors instead of checking out when the review worktree is dirty' {
            # Self-sufficient under test filtering: ensure the review worktree exists even if
            # the creation test above did not run.
            if (-not (Test-Path (Join-Path $script:layout 'review'))) {
                git -C (Join-Path $script:layout '.bare') worktree add --detach ../review 2>&1 | Out-Null
            }
            Set-Content -Path (Join-Path $script:layout 'review' 'file.txt') -Value 'dirty'
            Set-Location (Join-Path $script:layout 'main')
            if (Test-Path $script:nvimArgsFile) { Remove-Item $script:nvimArgsFile }
            $out = Invoke-AdoPrReview -Id 42 2>&1
            $out | Should -Match 'dirty'
            Test-Path $script:nvimArgsFile | Should -BeFalse
        }
    }
}
