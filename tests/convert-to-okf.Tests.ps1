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

    It 'does not double-append .md to a bare wikilink target that already ends in .md' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "See [[adr/foo.md]]." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        $content | Should -Match ([regex]::Escape('[foo](/adr/foo.md)'))
        $content | Should -Not -Match ([regex]::Escape('.md.md'))
    }

    It 'does not double-append .md to a labeled wikilink target that already ends in .md' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "See [[adr/foo.md|Label]]." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        $content | Should -Match ([regex]::Escape('[Label](/adr/foo.md)'))
        $content | Should -Not -Match ([regex]::Escape('.md.md'))
    }

    It 'preserves a #anchor fragment on a bare wikilink target' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "See [[a/b#section]]." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Match ([regex]::Escape('[b](/a/b.md#section)'))
    }

    It 'preserves a #anchor fragment on a labeled wikilink target' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "See [[a/b#section|Label]]." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Match ([regex]::Escape('[Label](/a/b.md#section)'))
    }

    It 'converts a bare local-heading wikilink [[#Heading]] to a plain anchor link, not .md#Heading' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "See [[#Background]] above." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        $content | Should -Match ([regex]::Escape('[Background](#Background)'))
        $content | Should -Not -Match ([regex]::Escape('.md#Background'))
    }

    It 'converts a labeled local-heading wikilink [[#Heading|Label]] to a plain anchor link, not .md#Heading' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "See [[#Background|this section]] above." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        $content | Should -Match ([regex]::Escape('[this section](#Background)'))
        $content | Should -Not -Match ([regex]::Escape('.md#Background'))
    }

    It 'leaves wikilink-looking text inside a tilde-fenced code block untouched' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'index.md'
        $value = "Example:`n" + '~~~' + "`nSee [[a/b]] here.`n" + '~~~' + "`nDone."
        Set-Content -LiteralPath $file -Value $value -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Be $value
    }

    It 'leaves wikilink-looking text untouched inside a 4-backtick fence wrapping a literal triple-backtick example' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'index.md'
        $value = "Example:`n" + '````' + "`nHere is a snippet:`n" + '```' + "`nSee [[a/b]] here.`n" + '```' + "`nmore text`n" + '````' + "`nDone."
        Set-Content -LiteralPath $file -Value $value -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Be $value
    }

    It 'leaves wikilink-looking text inside a double-backtick inline code span untouched' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'index.md'
        $value = 'Use ``[[a/b]]`` syntax for links.'
        Set-Content -LiteralPath $file -Value $value -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Be $value
    }

    It 'leaves wikilink-looking text inside inline code spans untouched' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'index.md'
        Set-Content -LiteralPath $file -Value 'Use `[[a/b]]` syntax for links.' -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Be 'Use `[[a/b]]` syntax for links.'
    }

    It 'leaves wikilink-looking text inside fenced code blocks untouched' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'index.md'
        $value = "Example:`n" + '```' + "`nSee [[a/b]] here.`n" + '```' + "`nDone."
        Set-Content -LiteralPath $file -Value $value -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Be $value
    }

    It 'leaves wikilink-looking text inside YAML frontmatter untouched' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        $value = "---`ninitiative: x`ntype: core`nupdated: 2026-01-01`nnote: `"See [[a/b]] here.`"`n---`n`nbody"
        Set-Content -LiteralPath $file -Value $value -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        $content | Should -Match ([regex]::Escape('note: "See [[a/b]] here."'))
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

    It 'raises an error rather than silently omitting generated.at when git log genuinely fails' {
        $script:Repo = Join-Path ([IO.Path]::GetTempPath()) ('okf-corrupt-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:Repo -Force | Out-Null
        # A .git directory that is not a real git repository — Find-GitRoot finds it
        # (it only checks for the directory's presence), but any `git` command run
        # against it fails with a non-zero exit code. This must surface as a real
        # error, not be silently treated the same as "no history for this file".
        New-Item -ItemType Directory -Path (Join-Path $script:Repo '.git') -Force | Out-Null
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: core`nupdated: 2026-01-01`n---`n`nbody" -NoNewline -Encoding utf8

        Invoke-Convert -Path $file | Should -Not -Be 0
    }

    It 'raises an error rather than silently treating a corrupt HEAD (not merely unborn) as an empty repo' {
        $script:Repo = New-TestRepo
        # A real, valid work tree with no commits yet has an unborn-but-legitimate HEAD:
        # `git symbolic-ref -q HEAD` succeeds (HEAD is a valid symref to a branch that
        # simply has no commits yet), while `rev-parse --verify -q HEAD` fails (no commit
        # to resolve to). Point HEAD at a malformed ref name instead — `rev-parse --verify
        # -q HEAD` still fails the same way, but `git symbolic-ref -q HEAD` now fails too
        # ("your current branch appears to be broken"), which is what distinguishes a
        # genuinely corrupt HEAD from legitimate unborn HEAD. This must surface as a real
        # error, not be silently swallowed as "no history".
        Set-Content -LiteralPath (Join-Path $script:Repo '.git/HEAD') -Value 'ref: refs/heads/bad ref name' -NoNewline -Encoding utf8
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: core`nupdated: 2026-01-01`n---`n`nbody" -NoNewline -Encoding utf8

        Invoke-Convert -Path $file | Should -Not -Be 0
    }

    It 'raises an error when HEAD itself is a valid symref but the branch it targets is corrupt' {
        $script:Repo = New-TestRepo
        # A different corruption shape than the previous test: HEAD's own content is a
        # well-formed symref ("ref: refs/heads/main"), but the branch ref it points at
        # holds garbage instead of a commit SHA. `git symbolic-ref -q HEAD` must also
        # fail to resolve this (not just report HEAD's literal text), or this would be
        # misclassified as legitimate unborn HEAD the same way f205-12 originally did.
        $branch = & git -C $script:Repo symbolic-ref -q HEAD
        New-Item -ItemType Directory -Path (Join-Path $script:Repo ".git/$(Split-Path $branch -Parent)") -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:Repo ".git/$branch") -Value 'notahexsha' -NoNewline -Encoding utf8
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: core`nupdated: 2026-01-01`n---`n`nbody" -NoNewline -Encoding utf8

        Invoke-Convert -Path $file | Should -Not -Be 0
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

    It 'recomputes stale_after when updated: changes on a rerun' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'STATUS.md'
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: status`nupdated: 2026-01-01`n---`n`nNow" -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Match '(?m)^stale_after: 2026-01-08$'

        $content = Get-Content -LiteralPath $file -Raw
        $content = $content -replace 'updated: 2026-01-01', 'updated: 2026-02-01'
        Set-Content -LiteralPath $file -Value $content -NoNewline -Encoding utf8

        Invoke-Convert -Path $file | Should -Be 0
        $result = Get-Content -LiteralPath $file -Raw
        $result | Should -Match '(?m)^stale_after: 2026-02-08$'
        $result | Should -Not -Match '(?m)^stale_after: 2026-01-08$'
    }

    It 'is a no-op rerun (changed: $false) when updated: is unchanged' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'STATUS.md'
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: status`nupdated: 2026-01-01`n---`n`nNow" -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        $firstPass = Get-Content -LiteralPath $file -Raw

        $json = & pwsh -NoProfile -Command "& '$script:Script' -Path '$file' | ConvertTo-Json"
        $LASTEXITCODE | Should -Be 0
        $result = $json | ConvertFrom-Json
        $result.Changed | Should -Be $false
        (Get-Content -LiteralPath $file -Raw) | Should -Be $firstPass
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

    It 'types a file by its path relative to the brain root, not by an ancestor directory that happens to share a role name' {
        # The fixture repo root itself sits under a parent directory segment named
        # "adr" (e.g. .../Temp/adr/okf-<guid>). The file lives under the brain's own
        # reports/ directory, so it must type as 'report' — matching the absolute
        # path (which also contains "adr/" from the ancestor) would mistype it as
        # 'adr'.
        $parent = Join-Path ([IO.Path]::GetTempPath()) 'adr'
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $script:Repo = Join-Path $parent ('okf-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:Repo -Force | Out-Null
        & git -C $script:Repo init -q . 2>&1 | Out-Null
        & git -C $script:Repo config user.email 'test@example.invalid' 2>&1 | Out-Null
        & git -C $script:Repo config user.name 'Test' 2>&1 | Out-Null

        New-Item -ItemType Directory -Path (Join-Path $script:Repo 'reports') -Force | Out-Null
        $file = Join-Path $script:Repo 'reports/foo.md'
        Set-Content -LiteralPath $file -Value "Body." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Match '(?m)^type: report$'
    }

    It 'does not duplicate frontmatter when the closing fence is the last line with no trailing newline' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        # No newline after the closing '---' fence and no body at all.
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: core`nupdated: 2026-01-01`n---" -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        $fenceCount = ([regex]::Matches($content, '(?m)^---$')).Count
        $fenceCount | Should -Be 2
    }

    It 'rebuilds frontmatter using CRLF line endings and stays a true no-op rerun on a CRLF file' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'STATUS.md'
        $value = "---`r`ninitiative: x`r`ntype: status`r`nupdated: 2026-01-01`r`n---`r`n`r`nNow`r`n"
        [IO.File]::WriteAllText($file, $value)
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        $rawBytes = Get-Content -LiteralPath $file -Raw
        $rawBytes | Should -Not -Match "(?<!`r)`n"

        $json = & pwsh -NoProfile -Command "& '$script:Script' -Path '$file' | ConvertTo-Json"
        $LASTEXITCODE | Should -Be 0
        $result = $json | ConvertFrom-Json
        $result.Changed | Should -Be $false

        $rerunContent = Get-Content -LiteralPath $file -Raw
        $rerunContent | Should -Not -Match "(?<!`r)`n"
    }

    It 'leaves the file byte-identical under -WhatIf' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "See [[adr/0001-foo|the decision]]." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo
        $before = Get-Content -LiteralPath $file -Raw

        & pwsh -NoProfile -File $script:Script -Path $file -WhatIf 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Be $before
    }

    It 'does not write generated.by alongside a backfilled generated.at' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: core`nupdated: 2026-01-01`n---`n`nbody" -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo -Message 'add core.md'

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        $content | Should -Match '(?m)^\s+at: \d{4}-\d{2}-\d{2}T'
        $content | Should -Not -Match '(?m)^\s*by\s*:'
    }

    It 'backfills at: into an existing generated: block that only has by:, without duplicating the block' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: core`nupdated: 2026-01-01`ngenerated:`n  by: someone`n---`n`nbody" -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo -Message 'add core.md'

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        ([regex]::Matches($content, '(?m)^generated:\s*$')).Count | Should -Be 1
        $content | Should -Match '(?m)^\s+by: someone$'
        $content | Should -Match '(?m)^\s+at: \d{4}-\d{2}-\d{2}T'

        # Rerunning must be a true no-op — the backfill must not itself be a moving target.
        $firstPass = $content
        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Be $firstPass
    }

    It 'backfills at: into an existing inline generated: { by: ... } map, without duplicating the field' {
        $script:Repo = New-TestRepo
        $file = Join-Path $script:Repo 'core.md'
        Set-Content -LiteralPath $file -Value "---`ninitiative: x`ntype: core`nupdated: 2026-01-01`ngenerated: { by: someone }`n---`n`nbody" -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo -Message 'add core.md'

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        ([regex]::Matches($content, '(?m)^generated\s*:')).Count | Should -Be 1
        $content | Should -Match '(?m)^generated: \{ by: someone, at: \d{4}-\d{2}-\d{2}T[^}]*\}$'

        # Rerunning must be a true no-op — the backfill must not itself be a moving target.
        $firstPass = $content
        Invoke-Convert -Path $file | Should -Be 0
        (Get-Content -LiteralPath $file -Raw) | Should -Be $firstPass
    }

    It 'does not add type: (or type-derived fields) to files under a templates/ directory, but still rewrites their wikilinks' {
        $script:Repo = New-TestRepo
        New-Item -ItemType Directory -Path (Join-Path $script:Repo 'templates') -Force | Out-Null
        $file = Join-Path $script:Repo 'templates/core.md'
        Set-Content -LiteralPath $file -Value "See [[adr/0001-foo|the decision]]." -NoNewline -Encoding utf8
        Add-Commit -Repo $script:Repo

        Invoke-Convert -Path $file | Should -Be 0
        $content = Get-Content -LiteralPath $file -Raw
        $content | Should -Not -Match '(?m)^type:'
        $content | Should -Not -Match '(?m)^generated:'
        $content | Should -Match ([regex]::Escape('[the decision](/adr/0001-foo.md)'))
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
