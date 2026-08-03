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
        $agents | Should -Match '## Scope and wayfinding'
        $agents | Should -Match '## Current project rules'
        $agents.Length | Should -BeLessThan 12000
    }

    It 'keeps detailed rationale outside the loaded project guide' {
        $agents = Get-Content -Raw $script:AgentsPath
        $rationale = Get-Content -Raw $script:RationalePath

        $rationale | Should -Match '^# Agent-instruction pruning: durable rationale'
        $rationale | Should -Match 'Rejected alternatives'
        $agents | Should -Not -Match '### Key decisions \(do not reverse without asking\)'
    }

    It 'keeps the repository-root CLAUDE.md as a thin Claude adapter' {
        $claude = Get-Content -Raw $script:ClaudePath

        $claude | Should -Match '@AGENTS\.md'
        $claude | Should -Match 'only Claude Code-specific behavior'
        $claude | Should -Not -Match '## Repository scope'
        $claude | Should -Not -Match '## Installation entry points'
    }
}
