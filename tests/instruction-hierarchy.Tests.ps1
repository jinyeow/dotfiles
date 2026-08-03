# Pester tests for the portable project instruction hierarchy.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:AgentsPath = Join-Path $script:RepoRoot 'AGENTS.md'
    $script:ClaudePath = Join-Path $script:RepoRoot 'CLAUDE.md'
    $script:RationalePath = Join-Path $script:RepoRoot 'docs/adr/agent-instructions-rationale.md'
}

Describe 'repository instruction hierarchy' {
    It 'keeps concise project guidance in the repository-root AGENTS.md' {
        $agents = Get-Content -Raw $script:AgentsPath

        $agents | Should -Match '# AGENTS\.md'
        $agents | Should -Match '## Scope and safety'
        $agents | Should -Match '## Authority index'
        $agents | Should -Match '## Shared agent configuration boundaries'
        $agents.Length | Should -BeLessThan 6000
    }

    It 'keeps detailed rationale outside the loaded project guide' {
        $agents = Get-Content -Raw $script:AgentsPath
        $rationale = Get-Content -Raw $script:RationalePath

        $rationale | Should -Match '^# Agent-instruction pruning: durable rationale'
        $rationale | Should -Match 'Classification of removed material'
        $rationale | Should -Match 'Always-loaded invariant'
        $rationale | Should -Match 'Current subsystem documentation'
        $rationale | Should -Match 'Historical ADR material'
        $rationale | Should -Match 'Obsolete content'
        $agents | Should -Not -Match '### Key decisions \(do not reverse without asking\)'
    }

    It 'keeps the repository-root CLAUDE.md as a thin Claude adapter' {
        $claude = Get-Content -Raw $script:ClaudePath

        $claude | Should -Match '@AGENTS\.md'
        $claude | Should -Match 'Claude Code-specific behavior'
        $claude | Should -Not -Match '## Repository scope'
        $claude | Should -Not -Match '## Installation entry points'
        ($claude -split "`n").Count | Should -BeLessThan 15
    }

    It 'routes every major subsystem to existing authority files' {
        $agents = Get-Content -Raw $script:AgentsPath
        $routes = @(
            @('PowerShell profile', 'powershell/README.md', 'powershell/Microsoft.PowerShell_profile.ps1'),
            @('Prompt', 'powershell/Profile/Set-Prompt.ps1', 'tests/Set-Prompt.Tests.ps1'),
            @('Git', 'git/README.md', 'tests/git-work-hooks.Tests.ps1'),
            @('Neovim', 'nvim/README.md', 'nvim/nvim-pack-lock.json'),
            @('Multiplexers', 'psmux/README.md', 'zellij/README.md'),
            @('Herdr', 'herdr/README.md', 'herdr/config.toml'),
            @('Yazi', 'yazi/yazi.toml', 'yazi/keymap.toml', 'yazi/theme.toml'),
            @('Setup', 'setup.ps1', 'setup.sh', 'tests/setup.Tests.ps1'),
            @('Claude', 'claude/README.md', 'claude/AGENTS.md'),
            @('Codex', 'codex/README.md', 'codex/config.toml'),
            @('Pi', 'pi/README.md', 'pi/settings.json')
        )

        foreach ($route in $routes) {
            $routeName = $route[0]
            foreach ($target in $route[1..($route.Count - 1)]) {
                $agents | Should -Match ([regex]::Escape($target)) -Because "$routeName routing should name $target"
                (Test-Path (Join-Path $script:RepoRoot $target)) | Should -BeTrue -Because "$routeName target $target should exist"
            }
        }
    }

    It 'has no dead repository-path references in the loaded guide' {
        $agents = Get-Content -Raw $script:AgentsPath
        $references = [regex]::Matches($agents, '`([^`]+)`') |
            ForEach-Object { $_.Groups[1].Value } |
            Where-Object { $_ -match '[/.]' -and $_ -notmatch '\s' } |
            Select-Object -Unique

        foreach ($reference in $references) {
            (Test-Path (Join-Path $script:RepoRoot $reference)) | Should -BeTrue -Because "authority reference $reference should not be stale"
        }
    }

    It 'supports realistic discovery examples without loading the old archive' {
        $agents = Get-Content -Raw $script:AgentsPath

        @(
            @('fix prompt CWD handling', 'powershell/Profile/Set-Prompt.ps1', 'tests/Set-Prompt.Tests.ps1'),
            @('change a Neovim plugin', 'nvim/README.md', 'nvim/nvim-pack-lock.json'),
            @('change a work hook', 'git/README.md', 'tests/git-work-hooks.Tests.ps1'),
            @('adjust installer projection', 'setup.ps1', 'tests/setup.Tests.ps1')
        ) | ForEach-Object {
            $agents | Should -Match ([regex]::Escape($_[1])) -Because "task '$($_[0])' must be discoverable"
            $agents | Should -Match ([regex]::Escape($_[2])) -Because "task '$($_[0])' must name validation"
        }
    }
}
