#Requires -Version 7
# Pester tests for setup.ps1 argument handling. Runs the installer as a child pwsh
# in -DryRun so it never mutates the machine.

BeforeAll {
    $script:SetupScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'setup.ps1'
}

Describe 'setup.ps1 argument validation' {
    It 'shows usage guidance and exits 1 when no -Module and no -CleanBackups are given' {
        # Regression: `$Module | Select-Object -Unique` collapsed the empty-array default to
        # $null, so the `$Module.Count` guard threw under StrictMode instead of printing usage.
        $output = & pwsh -NoProfile -File $script:SetupScript -DryRun 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $output | Should -Match 'Specify -Module'
        $output | Should -Not -Match "property 'Count' cannot be found"
    }
}

Describe 'setup.ps1 Claude bootstrap boundary' {
    It 'uses the native installer and gates all Claude projection on the executable' {
        $source = Get-Content -LiteralPath $script:SetupScript -Raw
        $source | Should -Match "Invoke-RestMethod -Uri 'https://claude\.ai/install\.ps1'"
        $source | Should -Match 'irm https://claude\.ai/install\.ps1 \| iex'
        $source | Should -Match 'Claude setup stopped before configuration or projection because the CLI is unavailable'

        $installStart = $source.IndexOf('function Install-Claude')
        $installEnd = $source.IndexOf('function Install-Pi', $installStart)
        $installBody = $source.Substring($installStart, $installEnd - $installStart)
        $installBody.IndexOf('if (-not (Confirm-ClaudeCli))') | Should -BeGreaterOrEqual 0
        $installBody.IndexOf('if (-not (Confirm-ClaudeCli))') | Should -BeLessThan $installBody.IndexOf('New-FileSymlink -Link (Join-Path $claudeDir ''settings.json'')')
    }

    It 'previews the native bootstrap without mutating Claude state in dry-run' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-bootstrap-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '(Claude Code CLI is already installed|\[DRY RUN\] would install Claude Code CLI via)'
            Test-Path (Join-Path $tmpHome '.claude') | Should -BeFalse
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 Codex bootstrap boundary' {
    It 'gates configuration and projection on the Codex executable, and never runs codex login' {
        $source = Get-Content -LiteralPath $script:SetupScript -Raw
        $source | Should -Match "Invoke-RestMethod -Uri 'https://chatgpt\.com/codex/install\.ps1'"
        $source | Should -Match 'Codex setup stopped before configuration or projection because the executable is unavailable'
        $source | Should -Not -Match '&\s*codex\s+login'

        $installStart = $source.IndexOf('function Install-Codex')
        $installEnd = $source.IndexOf('function Install-Serena', $installStart)
        $installBody = $source.Substring($installStart, $installEnd - $installStart)
        $installBody.IndexOf('if (-not (Confirm-CodexCli))') | Should -BeGreaterOrEqual 0
        $installBody.IndexOf('if (-not (Confirm-CodexCli))') | Should -BeLessThan $installBody.IndexOf('Copy-Dotfile')
    }

    It 'previews the native bootstrap without mutating Codex state in dry-run' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-bootstrap-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '(codex is already installed|\[DRY RUN\] would install Codex CLI via)'
            Test-Path (Join-Path $tmpHome '.codex') | Should -BeFalse
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 Codex MCP registration gating' {
    BeforeAll {
        $script:ShimDir = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-mcp-shim-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:ShimDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:ShimDir 'claude.cmd') -Value '@exit /b 0' -Encoding ASCII
    }

    AfterAll {
        Remove-Item -Path $script:ShimDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'skips registration when the claude CLI is present but the Claude settings file is missing' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-mcp-nosettings-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        $origPath = $env:PATH
        try {
            $env:USERPROFILE = $tmpHome
            $env:PATH = "$script:ShimDir$([IO.Path]::PathSeparator)$origPath"
            $output = & pwsh -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Claude settings file not found — skipping MCP registration'
            $output | Should -Not -Match 'would register user-scope MCP: claude mcp add --scope user codex'
        } finally {
            $env:USERPROFILE = $origUP
            $env:PATH = $origPath
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'previews registration only when both the claude CLI and the Claude settings file are present' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-mcp-ok-' + [guid]::NewGuid())
        $claudeDir = Join-Path $tmpHome '.claude'
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Set-Content -Path (Join-Path $claudeDir 'settings.json') -Value '{}'
        $origUP = $env:USERPROFILE
        $origPath = $env:PATH
        try {
            $env:USERPROFILE = $tmpHome
            $env:PATH = "$script:ShimDir$([IO.Path]::PathSeparator)$origPath"
            $output = & pwsh -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '\[DRY RUN\] would register user-scope MCP: claude mcp add --scope user codex'
        } finally {
            $env:USERPROFILE = $origUP
            $env:PATH = $origPath
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'skips registration when the claude CLI is not on PATH' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-mcp-noclaude-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        $origPath = $env:PATH
        # Resolve pwsh before stripping PATH down to a minimal set without claude on it — the
        # child-process launch below still needs to find pwsh.exe by full path.
        $pwshPath = (Get-Command pwsh).Source
        try {
            $env:USERPROFILE = $tmpHome
            $env:PATH = Join-Path $env:SystemRoot 'System32'
            $output = & $pwshPath -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'claude CLI not found — skipping MCP registration'
        } finally {
            $env:USERPROFILE = $origUP
            $env:PATH = $origPath
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 pi module' {
    It 'returns before repository projection when the skills destination is unmanaged' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-pi-unmanaged-' + [guid]::NewGuid())
        $skills = Join-Path $tmpHome '.pi\agent\skills'
        New-Item -ItemType Directory -Path (Split-Path $skills -Parent) -Force | Out-Null
        Set-Content -LiteralPath $skills -Value 'user-owned'
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module pi -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Pi skills destination is unmanaged and is not a directory'
            $output | Should -Not -Match '\.pi[\\/]agent[\\/](settings\.json|extensions|prompts|themes)'
            Get-Content -LiteralPath $skills | Should -Be 'user-owned'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'previews Pi shared and native per-skill projection without mutating the home' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-pi-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module pi -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '=== Pi ==='
            $output | Should -Match '(would install Pi via npm|pi is already installed)'
            $output | Should -Match 'pi[\\/]agent[\\/]settings\.json'
            foreach ($name in @('council', 'council-code', 'council-business', 'council-plan', 'council-doc')) {
                $output | Should -Match "pi[\\/]agent[\\/]skills[\\/]$name -> .*ai-agents[\\/]skills[\\/]$name"
            }
            Test-Path (Join-Path $tmpHome '.pi') | Should -BeFalse
            $output | Should -Not -Match "Unknown module 'pi'"
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not classify a link under the Claude-only historical root ai-agents\claude\skills as managed' -Skip:(-not $IsWindows) {
        # Regression for issue #71: Pi's installer (current or historical) never wrote into
        # ai-agents\claude\skills — that root belongs only to Claude's projection history. A
        # link that happens to resolve under it must stay untouched by Pi's cleanup, not be
        # silently removed as "obsolete managed".
        $repoRoot = Split-Path $script:SetupScript -Parent
        $claudeOnlySource = Join-Path $repoRoot 'ai-agents\claude\skills'
        $claudeOnlySkill = Join-Path $claudeOnlySource 'legacy-only'
        $createdParent = -not (Test-Path $claudeOnlySource)
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-pi-clauderoot-' + [guid]::NewGuid())
        $piSkills = Join-Path $tmpHome '.pi\agent\skills'
        New-Item -ItemType Directory -Path $claudeOnlySkill, $piSkills -Force | Out-Null
        $link = Join-Path $piSkills 'legacy-only'
        $origUP = $env:USERPROFILE
        try {
            New-Item -ItemType Junction -Path $link -Target $claudeOnlySkill -ErrorAction Stop | Out-Null
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module pi -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Not -Match 'remove obsolete Pi skill junction.*legacy-only'
            Test-Path -LiteralPath $link | Should -BeTrue
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $claudeOnlySkill -Recurse -Force -ErrorAction SilentlyContinue
            if ($createdParent) { Remove-Item -Path $claudeOnlySource -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'setup.ps1 Claude skill projection safety' {
    It 'preserves an unmanaged same-name skill directory' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-unmanaged-dir-' + [guid]::NewGuid())
        $link = Join-Path $tmpHome '.claude\skills\council'
        New-Item -ItemType Directory -Path $link -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $output | Should -Match 'Preserved unmanaged Claude skill: .*\.claude[\\/]skills[\\/]council'
            $output | Should -Not -Match '\[DRY RUN\] junction .*\.claude[\\/]skills[\\/]council ->'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'projects portable and Claude-native skills plus Claude support' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-layout-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '\.claude\\skills\\council -> .*ai-agents\\skills\\council'
            $output | Should -Match '\.claude\\skills\\codex-review -> .*claude\\skills\\codex-review'
            $output | Should -Match '\.claude\\skills\\_shared -> .*claude\\skills\\_shared'
            $output | Should -Not -Match '\.claude\\skills\\_shared -> .*ai-agents\\_shared'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'preserves an external same-name skill link' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-external-link-' + [guid]::NewGuid())
        $foreign = Join-Path $tmpHome 'foreign-council'
        $link = Join-Path $tmpHome '.claude\skills\council'
        New-Item -ItemType Directory -Path $foreign, (Split-Path $link -Parent) -Force | Out-Null
        New-Item -ItemType Junction -Path $link -Target $foreign | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $output | Should -Match 'Preserved unmanaged Claude skill link: .*\.claude\\skills\\council'
            $output | Should -Not -Match '\[DRY RUN\] junction .*\.claude\\skills\\council ->'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'warns distinctly when a preserved unmanaged skill link target is missing (dangling)' -Skip:(-not $IsWindows) {
        # Regression for issue #67 finding 1: a junction whose target was never under a managed
        # or historical skill root (an ad-hoc/dev-worktree path) is "unmanaged — preserve", which
        # is indistinguishable from a legitimate user link even when the target no longer exists.
        # Real-world case: ~/.claude/skills/{grill-me,to-issues,to-prd} pointed at a dev-worktree
        # path deleted since commit afa79c4 and sat dangling, silently, for months.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-dangling-link-' + [guid]::NewGuid())
        $foreignParent = Join-Path $tmpHome 'foreign-dev-worktree'
        $foreign = Join-Path $foreignParent 'council'
        $link = Join-Path $tmpHome '.claude\skills\council'
        New-Item -ItemType Directory -Path $foreign, (Split-Path $link -Parent) -Force | Out-Null
        New-Item -ItemType Junction -Path $link -Target $foreign | Out-Null
        Remove-Item -LiteralPath $foreignParent -Recurse -Force
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $output | Should -Match 'Preserved unmanaged Claude skill link \(target missing\): .*\.claude\\skills\\council'
            $output | Should -Not -Match '\[DRY RUN\] junction .*\.claude\\skills\\council ->'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'migrates a legacy claude\skills link to the current projection' -Skip:(-not $IsWindows) {
        # Released installs junctioned ~/.claude/skills/<name> at the old top-level claude\skills
        # source. Those links are repository-managed and must be replaced by the current
        # ai-agents projection, not preserved as dangling unmanaged links.
        $repoRoot = Split-Path $script:SetupScript -Parent
        $oldSource = Join-Path $repoRoot 'ai-agents\claude\skills'
        $oldSkill = Join-Path $oldSource 'council'
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-legacy-link-' + [guid]::NewGuid())
        $link = Join-Path $tmpHome '.claude\skills\council'
        New-Item -ItemType Directory -Path $oldSkill, (Split-Path $link -Parent) -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            New-Item -ItemType Junction -Path $link -Target $oldSkill -ErrorAction Stop | Out-Null
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Not -Match 'Preserved unmanaged Claude skill link: .*\.claude\\skills\\council'
            $output | Should -Match '\[DRY RUN\] junction .*\.claude\\skills\\council -> .*ai-agents\\skills\\council'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $oldSource -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'leaves a junction already pointing at the current projection untouched' -Skip:(-not $IsWindows) {
        # Idempotency: a re-run over an already-migrated home must recognize the junction as
        # current — not re-create it, and not misclassify it as an unmanaged entry.
        $repoRoot = Split-Path $script:SetupScript -Parent
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-idempotent-' + [guid]::NewGuid())
        $link = Join-Path $tmpHome '.claude\skills\council'
        New-Item -ItemType Directory -Path (Split-Path $link -Parent) -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            New-Item -ItemType Junction -Path $link -Target (Join-Path $repoRoot 'ai-agents\skills\council') -ErrorAction Stop | Out-Null
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Junction:\s+.*\.claude\\skills\\council \(already current\)'
            $output | Should -Not -Match '\[DRY RUN\] junction .*\.claude\\skills\\council ->'
            $output | Should -Not -Match 'Preserved unmanaged Claude skill'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'removes an obsolete legacy claude\skills junction but preserves unmanaged entries' -Skip:(-not $IsWindows) {
        $repoRoot = Split-Path $script:SetupScript -Parent
        $oldSource = Join-Path $repoRoot 'ai-agents\claude\skills'
        $oldSkill = Join-Path $oldSource 'legacy-only'
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-legacy-obsolete-' + [guid]::NewGuid())
        $claudeSkills = Join-Path $tmpHome '.claude\skills'
        New-Item -ItemType Directory -Path $oldSkill, $claudeSkills, (Join-Path $claudeSkills 'unmanaged') -Force | Out-Null
        $oldLink = Join-Path $claudeSkills 'legacy-only'
        $origUP = $env:USERPROFILE
        try {
            New-Item -ItemType Junction -Path $oldLink -Target $oldSkill -ErrorAction Stop | Out-Null
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'remove obsolete Claude skill junction.*legacy-only'
            $output | Should -Not -Match 'remove obsolete Claude skill junction.*unmanaged'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $oldSource -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not classify a link under the Codex-only historical root ai-agents\codex\skills as managed' -Skip:(-not $IsWindows) {
        # Regression for issue #71: Claude's own installer (current or historical) never wrote
        # into ai-agents\codex\skills — that root belongs only to Codex's projection history.
        # A link that happens to resolve under it must stay untouched by Claude's cleanup, not
        # be silently removed as "obsolete managed".
        $repoRoot = Split-Path $script:SetupScript -Parent
        $codexOnlySource = Join-Path $repoRoot 'ai-agents\codex\skills'
        $codexOnlySkill = Join-Path $codexOnlySource 'legacy-only'
        $createdParent = -not (Test-Path $codexOnlySource)
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-codexroot-' + [guid]::NewGuid())
        $claudeSkills = Join-Path $tmpHome '.claude\skills'
        New-Item -ItemType Directory -Path $codexOnlySkill, $claudeSkills -Force | Out-Null
        $link = Join-Path $claudeSkills 'legacy-only'
        $origUP = $env:USERPROFILE
        try {
            New-Item -ItemType Junction -Path $link -Target $codexOnlySkill -ErrorAction Stop | Out-Null
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Not -Match 'remove obsolete Claude skill junction.*legacy-only'
            Test-Path -LiteralPath $link | Should -BeTrue
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $codexOnlySkill -Recurse -Force -ErrorAction SilentlyContinue
            if ($createdParent) { Remove-Item -Path $codexOnlySource -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'does not classify a link under a same-basename-prefix sibling root as managed' -Skip:(-not $IsWindows) {
        # Regression guard: string-prefix matching without a trailing separator would let
        # ai-agents\skills-extra be misclassified as inside ai-agents\skills. A directory
        # separator must terminate the root before the prefix counts as a match.
        $repoRoot = Split-Path $script:SetupScript -Parent
        $siblingSource = Join-Path $repoRoot 'ai-agents\skills-extra'
        $siblingSkill = Join-Path $siblingSource 'legacy-only'
        $createdParent = -not (Test-Path $siblingSource)
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-prefixguard-' + [guid]::NewGuid())
        $claudeSkills = Join-Path $tmpHome '.claude\skills'
        New-Item -ItemType Directory -Path $siblingSkill, $claudeSkills -Force | Out-Null
        $link = Join-Path $claudeSkills 'legacy-only'
        $origUP = $env:USERPROFILE
        try {
            New-Item -ItemType Junction -Path $link -Target $siblingSkill -ErrorAction Stop | Out-Null
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Not -Match 'remove obsolete Claude skill junction.*legacy-only'
            Test-Path -LiteralPath $link | Should -BeTrue
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $siblingSkill -Recurse -Force -ErrorAction SilentlyContinue
            if ($createdParent) { Remove-Item -Path $siblingSource -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'setup.ps1 Claude agent directory migration' {
    It 'uses the canonical source and documents historical-link migration' {
        $source = Get-Content -LiteralPath $script:SetupScript -Raw
        $source | Should -Match 'ai-agents\\agents'
        $source | Should -Match 'ai-agents\\shared\\agents'
        $source | Should -Match 'New-ManagedDirectoryJunction'
    }

    It 'preserves a user-owned agents directory' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-agents-owned-' + [guid]::NewGuid())
        $agents = Join-Path $tmpHome '.claude\\agents'
        New-Item -ItemType Directory -Path $agents -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $agents 'custom.md') -Value 'user-owned'
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Preserved unmanaged directory: .*[\\/]\.claude[\\/]agents'
            Get-Content -LiteralPath (Join-Path $agents 'custom.md') | Should -Be 'user-owned'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'preserves an external agents link' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-agents-external-' + [guid]::NewGuid())
        $foreign = Join-Path $tmpHome 'foreign-agents'
        $link = Join-Path $tmpHome '.claude\\agents'
        New-Item -ItemType Directory -Path $foreign, (Split-Path $link -Parent) -Force | Out-Null
        New-Item -ItemType Junction -Path $link -Target $foreign | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $output | Should -Match 'Preserved unmanaged directory link: .*\\.claude[\\/]agents'
            $output | Should -Not -Match '\[DRY RUN\] junction .*\\.claude[\\/]agents ->'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'previews migration of a dangling historical agents link' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-agents-historical-' + [guid]::NewGuid())
        $link = Join-Path $tmpHome '.claude\\agents'
        $historical = Join-Path (Split-Path $script:SetupScript -Parent) 'ai-agents\\shared\\agents'
        New-Item -ItemType Directory -Path (Split-Path $link -Parent) -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            New-Item -ItemType SymbolicLink -Path $link -Target $historical -ErrorAction Stop | Out-Null
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $output | Should -Match '\[DRY RUN\] junction .*\\.claude[\\/]agents -> .*ai-agents[\\/]agents'
            $output | Should -Not -Match 'Preserved unmanaged directory link'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'recognizes the original claude\agents source as a historical root' {
        # Regression for issue #67: a live machine's ~/.claude/agents junction can predate even
        # ai-agents/shared/agents — the very first agents source was claude\agents, before the
        # #54 ai-agents-module migration. That target no longer exists, so a link still pointing
        # at it must be recognized as historical (repairable), not silently preserved forever.
        $source = Get-Content -LiteralPath $script:SetupScript -Raw
        $source | Should -Match 'claude\\agents'
    }

    It 'migrates a dangling link to the original claude\agents source' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-agents-original-' + [guid]::NewGuid())
        $link = Join-Path $tmpHome '.claude\\agents'
        $repoRoot = Split-Path $script:SetupScript -Parent
        $originalParent = Join-Path $repoRoot 'claude'
        $original = Join-Path $originalParent 'agents'
        New-Item -ItemType Directory -Path $original, (Split-Path $link -Parent) -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            New-Item -ItemType Junction -Path $link -Target $original -ErrorAction Stop | Out-Null
            Remove-Item -LiteralPath $original -Recurse -Force
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $output | Should -Match '\[DRY RUN\] junction .*\\.claude[\\/]agents -> .*ai-agents[\\/]agents'
            $output | Should -Not -Match 'Preserved unmanaged directory link'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $original -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'warns distinctly when a preserved unmanaged agents link target is missing (dangling)' -Skip:(-not $IsWindows) {
        # Sibling regression to the skill-link dangling-preserve fix (issue #67 finding 1): an
        # agents directory junction whose target was never a recognized historical root is
        # "unmanaged — preserve", indistinguishable from a legitimate user link even when the
        # target no longer exists.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-agents-dangling-' + [guid]::NewGuid())
        $foreignParent = Join-Path $tmpHome 'foreign-dev-worktree'
        $foreign = Join-Path $foreignParent 'agents'
        $link = Join-Path $tmpHome '.claude\\agents'
        New-Item -ItemType Directory -Path $foreign, (Split-Path $link -Parent) -Force | Out-Null
        New-Item -ItemType Junction -Path $link -Target $foreign | Out-Null
        Remove-Item -LiteralPath $foreignParent -Recurse -Force
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $output | Should -Match 'Preserved unmanaged directory link \(target missing\): .*\\.claude[\\/]agents'
            $output | Should -Not -Match '\[DRY RUN\] junction .*\\.claude[\\/]agents ->'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 psmux module' {
    It 'runs the psmux module in -DryRun without error and prints its section header' {
        # Isolated on a throwaway USERPROFILE, like the -Backup test below. Without this, a
        # $env:USERPROFILE/$env:HOME left empty by another test file earlier in a full `Invoke-
        # Pester -Path tests` run (setup-sh.Tests.ps1's `Remove-Item Env:\HOME` clears HOME
        # instead of restoring its prior value) leaks in: setup.ps1's non-Windows fallback is
        # `$env:USERPROFILE = $HOME`, and an empty $HOME makes that a no-op, so Join-Path still
        # throws. Pinning USERPROFILE here makes the test self-contained regardless of run order.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-psmux-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module psmux -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '=== psmux'
            $output | Should -Not -Match "Unknown module 'psmux'"
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not forward-copy vendored plugins into a live ~/.psmux/plugins during -Backup' {
        # Regression: the plugin copy loop checked -DryRun but not -Backup, so `-Module psmux
        # -Backup` (a reverse live -> repo sync) still forward-copied repo -> live, mutating the
        # filesystem during what is supposed to be a read-from-live/write-to-repo run.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-psmux-backup-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module psmux -Backup 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Skipped \(vendored copy, no drift\)'
            (Test-Path (Join-Path $tmpHome '.psmux')) | Should -Be $false
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 zellij/yazi -Backup mode' {
    It 'does not create the Zellij config parent directory during -Backup' {
        # Regression: the parent-dir mkdir ahead of New-Junction only checked -DryRun, not
        # -Backup, even though New-Junction itself skips entirely under -Backup — so a -Backup
        # run still mutated the filesystem by creating an otherwise-unused empty directory.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-zellij-backup-' + [guid]::NewGuid())
        $appData = Join-Path $tmpHome 'AppData'
        $zellijParent = Join-Path $appData 'Zellij'
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP, $origAD = $env:USERPROFILE, $env:APPDATA
        try {
            $env:USERPROFILE = $tmpHome
            $env:APPDATA = $appData
            $output = & pwsh -NoProfile -File $script:SetupScript -Module zellij -Backup 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            # Assert on the Zellij parent specifically, not $appData: redirecting USERPROFILE to
            # $tmpHome means the child pwsh writes its own module cache to $appData\Local\Microsoft\
            # PowerShell on Windows, so $appData is not a clean signal. $appData\Zellij is exactly
            # the dir the guarded mkdir would create — the precise regression target.
            (Test-Path $zellijParent) | Should -Be $false
        } finally {
            $env:USERPROFILE = $origUP; $env:APPDATA = $origAD
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not create the yazi config parent directory during -Backup' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-yazi-backup-' + [guid]::NewGuid())
        $appData = Join-Path $tmpHome 'AppData'
        $yaziParent = Join-Path $appData 'yazi'
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP, $origAD = $env:USERPROFILE, $env:APPDATA
        try {
            $env:USERPROFILE = $tmpHome
            $env:APPDATA = $appData
            $output = & pwsh -NoProfile -File $script:SetupScript -Module yazi -Backup 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            # Assert on the yazi parent specifically, not $appData: the child pwsh writes its own
            # module cache under $appData\Local on Windows once USERPROFILE is redirected, so only
            # $appData\yazi (the dir the guarded mkdir would create) is the precise regression target.
            (Test-Path $yaziParent) | Should -Be $false
        } finally {
            $env:USERPROFILE = $origUP; $env:APPDATA = $origAD
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 dry-run directory-creation cosmetics' {
    It 'marks a not-yet-existing parent directory as [DRY RUN] rather than a bare "Created:"' {
        # Regression: Copy-Dotfile (and Install-Psmux's plugin-dir creation, covered by the
        # psmux -DryRun test above) printed "Created:    $dir" even under -DryRun, when nothing
        # was actually created — the message just lied. codex's config.toml/AGENTS.md copy is a
        # Copy-Dotfile call whose parent (~/.codex) does not exist yet in a fresh HOME.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '\[DRY RUN\] would create:\s+\S*\.codex\b'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 codex module shared skills' {
    It 'junctions portable shared skill subdirectories into ~/.codex/skills'  -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-skills-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            # Patterns anchor on the "link -> target" separator so `tdd` can't false-match a
            # future `tdd-something` skill (`\b` treats the hyphen as a word boundary).
            $output | Should -Match '\[DRY RUN\] junction .*\.codex\\skills\\tdd ->'
            foreach ($name in @('council', 'council-code', 'council-business', 'council-plan', 'council-doc')) {
                $output | Should -Match "\\.codex\\skills\\$name -> .*ai-agents\\skills\\$name"
            }
            # Claude-only skills are not sourced into Codex.
            $output | Should -Not -Match '\.codex\\skills\\codex-review ->'
            $output | Should -Not -Match '\.codex\\skills\\handoff ->'
            $output | Should -Not -Match '\.codex\\skills\\git-guardrails-claude-code ->'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'junctions only the Codex-native flavour when an ai-agents/codex skill collides with shared'  -Skip:(-not $IsWindows) {
        # A name in both sources must yield ONE junction (the codex/skills one) — junctioning
        # the shared dir first and letting the native one replace it would back up and re-create
        # the junction on every run, accumulating stale .bak.* junctions.
        $repoRoot = Split-Path $script:SetupScript -Parent
        $codexSkillsDir = Join-Path $repoRoot 'codex\skills'
        $createdParent = -not (Test-Path $codexSkillsDir)
        $fixture = Join-Path $codexSkillsDir 'tdd'
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-collision-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $fixture, $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '\.codex\\skills\\tdd -> .*codex\\skills\\tdd'
            $output | Should -Not -Match '\.codex\\skills\\tdd -> .*ai-agents\\skills\\tdd'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $fixture -Recurse -Force -ErrorAction SilentlyContinue
            if ($createdParent) { Remove-Item -Path $codexSkillsDir -Force -ErrorAction SilentlyContinue }
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 Codex skill migration' {
    It 'previews removal of obsolete managed Codex skill junctions but preserves unmanaged entries' -Skip:(-not $IsWindows) {
        # ai-agents\codex\skills is Codex's own former native-skills root (issue #71) — the root
        # that is actually historical for Codex's installer, unlike ai-agents\claude\skills.
        $repoRoot = Split-Path $script:SetupScript -Parent
        $oldSource = Join-Path $repoRoot 'ai-agents\codex\skills'
        $oldSkill = Join-Path $oldSource 'legacy-only'
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-migration-' + [guid]::NewGuid())
        $codexSkills = Join-Path $tmpHome '.codex\skills'
        New-Item -ItemType Directory -Path $oldSkill, $codexSkills, (Join-Path $codexSkills 'unmanaged') -Force | Out-Null
        $oldLink = Join-Path $codexSkills 'legacy-only'
        $origUP = $env:USERPROFILE
        try {
            New-Item -ItemType Junction -Path $oldLink -Target $oldSkill -ErrorAction Stop | Out-Null
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'remove obsolete Codex skill junction.*legacy-only'
            $output | Should -Not -Match 'remove obsolete Codex skill junction.*unmanaged'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $oldSource -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not classify a link under the Claude-only historical root ai-agents\claude\skills as managed' -Skip:(-not $IsWindows) {
        # Regression for issue #71: Codex's installer (current or historical) never wrote into
        # ai-agents\claude\skills — that root belongs only to Claude's projection history. A
        # link that happens to resolve under it must stay untouched by Codex's cleanup, not be
        # silently removed as "obsolete managed".
        $repoRoot = Split-Path $script:SetupScript -Parent
        $claudeOnlySource = Join-Path $repoRoot 'ai-agents\claude\skills'
        $claudeOnlySkill = Join-Path $claudeOnlySource 'legacy-only'
        $createdParent = -not (Test-Path $claudeOnlySource)
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-clauderoot-' + [guid]::NewGuid())
        $codexSkills = Join-Path $tmpHome '.codex\skills'
        New-Item -ItemType Directory -Path $claudeOnlySkill, $codexSkills -Force | Out-Null
        $link = Join-Path $codexSkills 'legacy-only'
        $origUP = $env:USERPROFILE
        try {
            New-Item -ItemType Junction -Path $link -Target $claudeOnlySkill -ErrorAction Stop | Out-Null
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Not -Match 'remove obsolete Codex skill junction.*legacy-only'
            Test-Path -LiteralPath $link | Should -BeTrue
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $claudeOnlySkill -Recurse -Force -ErrorAction SilentlyContinue
            if ($createdParent) { Remove-Item -Path $claudeOnlySource -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'setup.ps1 claude module output styles' {
    It 'junctions claude/output-styles into ~/.claude/output-styles' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-styles-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '\[DRY RUN\] junction .*\.claude\\output-styles'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 herdr module' {
    It 'dry-run links config.toml and, when herdr + an agent are present, wires the integration' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-herdr-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module herdr -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '\[DRY RUN\] symlink .*herdr[\\/]config\.toml'
            # The agent-integration wiring only runs when herdr itself is on PATH; assert its
            # dry-run line only then, so CI (which has no herdr) still exercises the symlink path.
            if (Get-Command -Name herdr -ErrorAction Ignore) {
                foreach ($agent in @('claude', 'codex')) {
                    if (Get-Command -Name $agent -ErrorAction Ignore) {
                        $output | Should -Match "\[DRY RUN\] herdr integration install $agent"
                    }
                }
            }
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 langservers module' {
    It 'names all three npm language-server packages in a dry run' {
        # The dry run must state which packages this module OWNS, not what this machine happens
        # to have — the per-binary presence check lives after the -DryRun branch on purpose, so
        # this assertion stays deterministic once the servers are actually installed here.
        $output = & pwsh -NoProfile -File $script:SetupScript -Module langservers -DryRun 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'volta install vscode-langservers-extracted'
        $output | Should -Match 'volta install yaml-language-server'
        $output | Should -Match 'volta install azure-pipelines-language-server'
        $output | Should -Not -Match "Unknown module 'langservers'"
    }

    It 'warns and skips rather than failing when the Node toolchain manager is absent' {
        # Simulating a missing toolchain means REPLACING PATH with an empty directory, not
        # shimming something into it (you cannot shim absence). pwsh itself then no longer
        # resolves from PATH, so the child is launched by absolute path from $PSHOME.
        $emptyDir = Join-Path ([IO.Path]::GetTempPath()) ('setup-langservers-nopath-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $pwshName = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
        $pwshExe = Join-Path $PSHOME $pwshName
        $origPath = $env:PATH
        try {
            $env:PATH = $emptyDir
            $output = & $pwshExe -NoProfile -File $script:SetupScript -Module langservers 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'volta not found'
        } finally {
            $env:PATH = $origPath
            Remove-Item -Path $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # The two tests above both return before the install loop (one at the -DryRun branch, one at
    # the volta guard), so without these the loop itself — the package/binary pairing, the
    # already-installed skip, and the per-package exit-code check — is never executed by the suite.
    # Driven against a fake `volta` on a stripped PATH, the same shim technique tests/psmux.Tests.ps1
    # uses for save.ps1. Stripping PATH also hides the real language-server binaries, so the
    # presence check falls through to the install branch on a machine where they ARE installed.
    Context 'install loop, driven against a shimmed volta' -Skip:(-not $IsWindows) {
        BeforeAll {
            $script:PwshExe = Join-Path $PSHOME 'pwsh.exe'
            $script:Packages = @(
                'vscode-langservers-extracted'
                'yaml-language-server'
                'azure-pipelines-language-server'
            )

            # Writes a volta.cmd that exits with $ExitCode and echoes the args it was handed, so a
            # test can assert WHICH package each invocation got, not merely that something ran.
            # Must be declared `function script:` inside BeforeAll — a bare `function` in a Context
            # body is not in scope for its It blocks under Pester 5.
            function script:New-VoltaShim ([int]$ExitCode) {
                $dir = Join-Path ([IO.Path]::GetTempPath()) ('setup-langservers-shim-' + [guid]::NewGuid())
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Set-Content -Path (Join-Path $dir 'volta.cmd') -Encoding ASCII -Value @"
@echo off
echo SHIM-CALLED %*
exit /b $ExitCode
"@
                return $dir
            }
        }

        It 'installs each package by name and reports success when volta exits 0' {
            $shimDir = New-VoltaShim -ExitCode 0
            $origPath = $env:PATH
            try {
                $env:PATH = $shimDir
                $output = & $script:PwshExe -NoProfile -File $script:SetupScript -Module langservers 2>&1 | Out-String
                $LASTEXITCODE | Should -Be 0
                foreach ($package in $script:Packages) {
                    $output | Should -Match "SHIM-CALLED install $([regex]::Escape($package))"
                    $output | Should -Match "installed $([regex]::Escape($package))"
                }
                $output | Should -Not -Match 'failed \(exit'
            } finally {
                $env:PATH = $origPath
                Remove-Item -Path $shimDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'reports each package that fails rather than reporting overall success' {
            # Story 14: a partial failure must be visible. A non-zero volta exit has to reach the
            # else branch and name the package — not be swallowed, and not abort the remaining ones.
            $shimDir = New-VoltaShim -ExitCode 1
            $origPath = $env:PATH
            try {
                $env:PATH = $shimDir
                $output = & $script:PwshExe -NoProfile -File $script:SetupScript -Module langservers 2>&1 | Out-String
                foreach ($package in $script:Packages) {
                    $output | Should -Match "volta install $([regex]::Escape($package)) failed \(exit 1\)"
                }
                $output | Should -Not -Match 'Language server: installed'
            } finally {
                $env:PATH = $origPath
                Remove-Item -Path $shimDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'setup.ps1 -Module ai-agents (composite)' {
    It 'runs the Claude, Codex, and Pi modules in sequence without duplicating any of them' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-ai-agents-composite-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module ai-agents -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Not -Match "Unknown module 'ai-agents'"
            @($output | Select-String -Pattern '=== Claude Code ===').Count | Should -Be 1
            @($output | Select-String -Pattern '=== Codex CLI ===').Count | Should -Be 1
            @($output | Select-String -Pattern '=== Pi ===').Count | Should -Be 1
            # Codex's MCP registration gates on ~/.claude/settings.json already existing (issue
            # #72), so Claude must project first — proves the composite doesn't just alias 'all'.
            $output.IndexOf('=== Claude Code ===') | Should -BeLessThan $output.IndexOf('=== Codex CLI ===')
            $output.IndexOf('=== Codex CLI ===') | Should -BeLessThan $output.IndexOf('=== Pi ===')
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Pi failure isolation (dot-sourced, functions mocked to fault-inject)' {
        BeforeAll {
            # Load real functions into this scope without running the main dispatch (the script
            # exits 1 for a truly empty -Module, so pass a harmless bogus module — same pattern
            # as the 'relative reparse-target comparison' Describe block below).
            . $script:SetupScript -Module bogus -DryRun *>$null
        }

        It 'does not abort Claude or Codex projection when Pi throws an unanticipated error' -Skip:(-not $IsWindows) {
            Mock Install-Pi { throw 'simulated unanticipated Pi failure' }
            $threw = $false
            try {
                $output = Install-AiAgents 6>&1 | Out-String
            } catch {
                $threw = $true
            }
            $threw | Should -BeFalse
            $output | Should -Match '=== Claude Code ==='
            $output | Should -Match '=== Codex CLI ==='
            $output | Should -Match 'simulated unanticipated Pi failure'
        }
    }
}

Describe 'setup.ps1 -Module all' {
    It 'runs the full module set in -DryRun without error (Windows-only)' -Skip:(-not $IsWindows) {
        # Non-Windows hits [Environment]::GetFolderPath('MyDocuments') returning an empty string
        # inside Install-PowerShell, which throws even under -DryRun (Join-Path with an empty
        # base path) — a genuine Windows-only API gap, not something -DryRun is meant to paper
        # over. Verified locally on Linux: `Join-Path: Cannot bind argument to parameter 'Path'
        # because it is an empty string.` So this smoke test only runs on windows-latest, which
        # is where the full module set is meant to work end to end.
        $output = & pwsh -NoProfile -File $script:SetupScript -Module all -DryRun 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Not -Match 'Unknown module'
    }

    It 'runs Claude, Codex, and Pi exactly once via the ai-agents composite (no duplicate runs)' -Skip:(-not $IsWindows) {
        $output = & pwsh -NoProfile -File $script:SetupScript -Module all -DryRun 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        @($output | Select-String -Pattern '=== Claude Code ===').Count | Should -Be 1
        @($output | Select-String -Pattern '=== Codex CLI ===').Count | Should -Be 1
        @($output | Select-String -Pattern '=== Pi ===').Count | Should -Be 1
    }

    It 'runs langservers after winget (whose curated set carries Volta) and before herdr' -Skip:(-not $IsWindows) {
        # Two ordering constraints, both enforced here rather than left to a comment: langservers
        # depends on Volta, which is part of the winget module's curated package set, and herdr must
        # stay LAST (it writes hook registrations through a settings.json the claude module
        # symlinks into the repo).
        $output = & pwsh -NoProfile -File $script:SetupScript -Module all -DryRun 2>&1 | Out-String
        $winget      = $output.IndexOf('=== winget packages')
        $langservers = $output.IndexOf('=== Language servers')
        $herdr       = $output.IndexOf('=== Herdr')
        $winget      | Should -BeGreaterThan -1
        $langservers | Should -BeGreaterThan $winget
        $herdr       | Should -BeGreaterThan $langservers
    }
}

Describe 'relative reparse-target comparison' {
    BeforeAll {
        # Load helper functions without running a real module.
        . $script:SetupScript -Module bogus *>$null
    }

    It 'canonicalizes a relative target against the link parent' {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('link-target-resolution-' + [guid]::NewGuid())
        $link = Join-Path $root 'nested/live-link'
        $expected = [IO.Path]::GetFullPath((Join-Path $root 'target'))
        Resolve-LinkTargetPath -Link $link -Target '../target' | Should -Be $expected
    }

    It 'fails closed when a target cannot be resolved' {
        Resolve-LinkTargetPath -Link ([IO.Path]::GetTempPath()) -Target ([string][char]0) | Should -BeNullOrEmpty
    }
}

Describe 'New-FileSymlink failure recovery' {
    BeforeAll {
        # -Module bogus keeps the top-level script from exiting early (`$Module.Count` is 1) and
        # does no real filesystem work (falls to the `default` unknown-module warn branch), so
        # it's safe to dot-source in-process to pull New-FileSymlink / Backup-Existing into this
        # Describe's scope without running any of the actual install modules.
        . $script:SetupScript -Module bogus *>$null
    }

    BeforeEach {
        $script:Tmp = Join-Path ([IO.Path]::GetTempPath()) ('symlink-restore-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null
        $script:Link = Join-Path $script:Tmp 'live.conf'
        $script:Target = Join-Path $script:Tmp 'target.conf'
        Set-Content -Path $script:Link -Value 'ORIGINAL CONTENT' -Encoding UTF8
        Set-Content -Path $script:Target -Value 'TARGET CONTENT' -Encoding UTF8
    }
    AfterEach {
        Remove-Item -Path $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'restores the original file when New-Item -ItemType SymbolicLink fails' {
        # Regression: Backup-Existing renamed the live file away BEFORE the symlink attempt.
        # When New-Item then failed (e.g. no Developer Mode on Windows), the user's real config
        # was left renamed to a .bak file with nothing in its place.
        Mock New-Item {
            throw 'A required privilege is not held by the client (simulated: no Developer Mode)'
        } -ParameterFilter { $ItemType -eq 'SymbolicLink' }

        New-FileSymlink -Link $script:Link -Target $script:Target

        (Test-Path -LiteralPath $script:Link) | Should -Be $true
        (Get-Content -LiteralPath $script:Link -Raw).Trim() | Should -Be 'ORIGINAL CONTENT'
        # No stray .bak file should be left behind once restored.
        @(Get-ChildItem -Path $script:Tmp -Filter '*.bak.*') | Should -BeNullOrEmpty
    }
}
