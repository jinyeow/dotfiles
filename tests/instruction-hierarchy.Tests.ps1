# Pester tests for the portable project instruction hierarchy.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:AgentsPath = Join-Path $script:RepoRoot 'AGENTS.md'
    $script:ClaudePath = Join-Path $script:RepoRoot 'CLAUDE.md'
    $script:AgentDocsPath = Join-Path $script:RepoRoot 'docs/agents'
    $script:WorkGitignorePath = Join-Path $script:RepoRoot 'git/gitignore-work'
    $script:RationalePath = Join-Path $script:RepoRoot 'docs/adr/agent-instructions-rationale.md'
    $script:AzProfileRationalePath = Join-Path $script:RepoRoot 'docs/adr/az-cli-profile-isolation.md'
}

Describe 'repository instruction hierarchy' {
    It 'keeps concise project guidance in the repository-root AGENTS.md' {
        $agents = Get-Content -Raw $script:AgentsPath

        $agents | Should -Match '# AGENTS\.md'
        $agents | Should -Match '## Scope and safety'
        $agents | Should -Match '## Authority index'
        $agents | Should -Match '## Shared agent configuration boundaries'
        $agents.Length | Should -BeLessThan 7000
    }

    It 'keeps detailed rationale outside the loaded project guide' {
        $agents = Get-Content -Raw $script:AgentsPath
        $rationale = Get-Content -Raw $script:RationalePath
        $azProfileRationale = Get-Content -Raw $script:AzProfileRationalePath

        $rationale | Should -Match '^# Agent-instruction pruning: durable rationale'
        $rationale | Should -Match 'Classification of removed material'
        $rationale | Should -Match 'Always-loaded invariant'
        $rationale | Should -Match 'Current subsystem documentation'
        $rationale | Should -Match 'Historical ADR material'
        $rationale | Should -Match 'Obsolete content'
        $azProfileRationale | Should -Match '^# Azure CLI named-profile isolation'
        $azProfileRationale | Should -Match 'left torn state'
        $azProfileRationale | Should -Match ([regex]::Escape('~/.azure-*'))
        $agents | Should -Not -Match '### Key decisions \(do not reverse without asking\)'
    }

    It 'keeps the repository-root CLAUDE.md as a thin Claude adapter' {
        $claude = Get-Content -Raw $script:ClaudePath

        $claude | Should -Match '@AGENTS\.md'
        $claude | Should -Match 'only Claude Code-specific behavior'
        $claude | Should -Not -Match '## Repository scope'
        $claude | Should -Not -Match '## Installation entry points'
        ($claude -split "`n").Count | Should -BeLessThan 15
    }

    It 'keeps the agent-skill configuration in docs/agents behind an Agent skills block' {
        $agents = Get-Content -Raw $script:AgentsPath

        $agents | Should -Match '## Agent skills'
        foreach ($name in @('issue-tracker.md', 'triage-labels.md', 'domain.md'))
        {
            $agents | Should -Match ([regex]::Escape("docs/agents/$name"))
            Test-Path (Join-Path $script:AgentDocsPath $name) | Should -BeTrue
        }
        Test-Path (Join-Path $script:RepoRoot 'GLOSSARY.md') | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'CONTEXT.md') | Should -BeFalse
        Test-Path (Join-Path $script:RepoRoot '.agents/workflow.md') | Should -BeFalse
    }

    It 'keeps the glossary private in work repos without hiding shared agent docs' {
        $repo = Join-Path $TestDrive 'work-repo'
        $agentDocs = Join-Path $repo 'docs/agents'
        New-Item -ItemType Directory -Path $agentDocs -Force | Out-Null
        Set-Content -Path (Join-Path $repo 'GLOSSARY.md') -Value '# private'
        Set-Content -Path (Join-Path $agentDocs 'issue-tracker.md') -Value '# shared'

        git -C $repo init --quiet
        git -C $repo config core.excludesFile $script:WorkGitignorePath

        git -C $repo check-ignore --quiet GLOSSARY.md
        $LASTEXITCODE | Should -Be 0
        git -C $repo check-ignore --quiet docs/agents/issue-tracker.md
        $LASTEXITCODE | Should -Be 1
    }

    It 'routes every major subsystem to existing authority files' {
        $agents = Get-Content -Raw $script:AgentsPath
        $routes = @(
            @('PowerShell profile', 'powershell/README.md', 'powershell/Microsoft.PowerShell_profile.ps1'),
            @('Prompt', 'powershell/Profile/Set-Prompt.ps1', 'tests/Set-Prompt.Tests.ps1'),
            @('Git', 'git/README.md', 'git/gitconfig-work', 'tests/git-config.Tests.ps1'),
            @('Neovim', 'nvim/README.md', 'nvim/nvim-pack-lock.json'),
            @('psmux', 'psmux/README.md', 'psmux/psmux.conf'),
            @('Zellij', 'zellij/README.md', 'zellij/config.kdl'),
            @('Herdr', 'herdr/README.md', 'herdr/config.toml'),
            @('Yazi', 'yazi/yazi.toml', 'yazi/keymap.toml', 'yazi/theme.toml'),
            @('Setup', 'setup.ps1', 'setup.sh', 'tests/setup.Tests.ps1'),
            @('Agent workflow', 'docs/agents/', 'ai-agents/skills/setup-matt-pocock-skills/SKILL.md'),
            @('Claude', 'claude/README.md', 'ai-agents/AGENTS.md'),
            @('Codex', 'codex/README.md', 'codex/config.toml'),
            @('Pi', 'pi/README.md', 'pi/settings.json')
        )

        foreach ($route in $routes)
        {
            $routeName = $route[0]
            foreach ($target in $route[1..($route.Count - 1)])
            {
                $linkPattern = '\]\(' + [regex]::Escape($target) + '(?:#[^)]+)?\)'
                $agents | Should -Match $linkPattern -Because "$routeName routing should link $target"
                (Test-Path (Join-Path $script:RepoRoot $target)) | Should -BeTrue -Because "$routeName target $target should exist"
            }
        }
    }

    It 'has no dead linked repository paths in the loaded guide' {
        $agents = Get-Content -Raw $script:AgentsPath
        $references = [regex]::Matches($agents, '\[[^\]]+\]\(([^)]+)\)') |
            ForEach-Object { $_.Groups[1].Value } |
            Where-Object { $_ -notmatch '^(?:[a-z][a-z0-9+.-]*:|#)' } |
            ForEach-Object { $_ -replace '#.*$', '' } |
            Select-Object -Unique

        $references.Count | Should -BeGreaterThan 0
        foreach ($reference in $references)
        {
            (Test-Path (Join-Path $script:RepoRoot $reference)) | Should -BeTrue -Because "linked repository path $reference should not be stale"
        }
    }
}
