#Requires -Version 7
# Behavioural tests for ai-agents/skills/project-brain/scripts/convert-to-okf.ps1 — the shared
# mechanical OKF conversion script (#196) every brain-repo migration batch (#197-204) runs
# instead of hand-formatting the same transform. Drives the real script as a subprocess against
# throwaway git-repo fixtures, per this repo's existing hook-test convention
# (tests/memory-review-nudge.Tests.ps1, tests/ctags-hook.Tests.ps1).

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Script = Join-Path $script:RepoRoot 'ai-agents/skills/project-brain/scripts/convert-to-okf.ps1'

    if (-not (Test-Path -LiteralPath $script:Script)) {
        throw "convert-to-okf.Tests.ps1: script not found: $script:Script"
    }

    function New-TestRepo {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('okf-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        & git -C $root init -q . 2>&1 | Out-Null
        & git -C $root config user.email 'test@example.invalid' 2>&1 | Out-Null
        & git -C $root config user.name 'Test' 2>&1 | Out-Null
        return $root
    }

    function Add-Commit {
        param([string] $Repo, [string] $Message = 'commit')
        & git -C $Repo add -A 2>&1 | Out-Null
        & git -C $Repo commit -q -m $Message 2>&1 | Out-Null
    }

    function Invoke-Convert {
        param([string] $Path)
        & pwsh -NoProfile -File $script:Script -Path $Path 2>&1 | Out-Null
        return $LASTEXITCODE
    }
}

Describe 'ai-agents/skills/project-brain/scripts/convert-to-okf.ps1' {
    AfterEach {
        if ($script:Repo -and (Test-Path -LiteralPath $script:Repo)) {
            Remove-Item -LiteralPath $script:Repo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rewrites [[a/b|label]] wikilinks to markdown-link form' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "See [[adr/0001-foo|the decision]]." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Match ([regex]::Escape('[the decision](/adr/0001-foo.md)'))
    }

    It 'rewrites bare [[a/b]] wikilinks, using the last path segment as the label' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "See [[research/bar]]." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Match ([regex]::Escape('[bar](/research/bar.md)'))
    }

    It 'inserts type: frontmatter inferred from the file role' {
        $script:Repo = New-TestRepo
        New-Item -ItemType Directory -Path (Join-Path $script:Repo 'adr') -Force | Out-Null
        $file = Join-Path $script:Repo 'adr/0001-foo.md'
        Set-Content -LiteralPath $file -Value "# ADR-0001 - foo`n`n- Status: Accepted" -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Match '(?m)^type: adr$'
    }

    It 'derives generated.at from the file''s own add commit when git history has it' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: core`nupdated: 2026-01-01`n---`n`nbody" -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo -Message 'add core.md'

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        $content | Should -Match '(?m)^generated:$'
        $content | Should -Match '(?m)^\s+at: \d{4}-\d{2}-\d{2}T'
    }

    It 'omits generated.at entirely when git history has no add commit for the file' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        # No git commit at all — the file is untracked.
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: core`nupdated: 2026-01-01`n---`n`nbody" -NoNewline -Encoding utf8

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        $content | Should -Not -Match '(?m)^generated:$'
    }

    It 'never populates verified: with content — only ever inserts it empty' {
        $script:Repo = New-TestRepo
        New-Item -ItemType Directory -Path (Join-Path $script:Repo 'research') -Force | Out-Null
        $file = Join-Path $script:Repo 'research/finding.md'
        Set-Content -LiteralPath $file -Value "# Finding`n`nVerified by spike." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Match '(?m)^verified: \[\]$'
    }

    It 'computes stale_after as updated: + 7 days on status-typed files' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'STATUS.md'
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: status`nupdated: 2026-01-01`n---`n`nNow" -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Match '(?m)^stale_after: 2026-01-08$'
    }

    It 'does not add type: to reserved index.md / log.md filenames' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'index.md'
        Set-Content -LiteralPath $file -Value "# Brain index`n`nSee [[adr/0001-foo]]." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        $content | Should -Not -Match '(?m)^type:'
        $content | Should -Match ([regex]::Escape('[0001-foo](/adr/0001-foo.md)'))
    }

    It 'is idempotent: running it twice produces no further change' {
        $script:Repo = New-TestRepo
        New-Item -ItemType Directory -Path (Join-Path $script:Repo 'adr') -Force | Out-Null
        $core = Join-Path $script:Repo 'core.md'
        $status = Join-Path $script:Repo 'STATUS.md'
        $adr = Join-Path $script:Repo 'adr/0001-foo.md'
        Set-Content -LiteralPath $core -Value "---`ninitiative: x`ntype: core`nupdated: 2026-01-01`n---`n`nSee [[adr/0001-foo|the decision]]." -NoNewline -Encoding utf8
        Set-Content -LiteralPath $status -Value "---`ninitiative: x`ntype: status`nupdated: 2026-01-01`n---`n`nNow" -NoNewline -Encoding utf8
        Set-Content -LiteralPath $adr -Value "# ADR-0001 - foo`n`n- Status: Accepted" -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $script:Repo | Should -Be 0
        $firstPass = @{
            core   = Get-Content -LiteralPath $core -Raw
            status = Get-Content -LiteralPath $status -Raw
            adr    = Get-Content -LiteralPath $adr -Raw
        }

        Invoke-Convert -Path $script:Repo | Should -Be 0
        (Get-Content -LiteralPath $core -Raw) | Should -Be $firstPass.core
        (Get-Content -LiteralPath $status -Raw) | Should -Be $firstPass.status
        (Get-Content -LiteralPath $adr -Raw) | Should -Be $firstPass.adr
    }

    It 'processes a directory recursively' {
        $script:Repo = New-TestRepo
        New-Item -ItemType Directory -Path (Join-Path $script:Repo 'adr') -Force | Out-Null
        $core = Join-Path $script:Repo 'core.md'
        $adr = Join-Path $script:Repo 'adr/0001-foo.md'
        Set-Content -LiteralPath $core -Value "See [[adr/0001-foo]]." -NoNewline -Encoding utf8
        Set-Content -LiteralPath $adr -Value "# ADR-0001 - foo" -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $script:Repo | Should -Be 0
        (Get-Content -LiteralPath $core -Raw) | Should -Match ([regex]::Escape('[0001-foo](/adr/0001-foo.md)'))
        (Get-Content -LiteralPath $adr -Raw) | Should -Match '(?m)^type: adr$'
    }
}
