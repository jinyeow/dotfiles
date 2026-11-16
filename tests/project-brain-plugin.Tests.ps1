#Requires -Version 7
# Structural tests for the standalone project-brain Claude Code plugin: the repo-root marketplace
# manifest, the plugin manifest rooted at the skill directory, its SessionStart hook, and the
# scaffold templates a fresh brain area is seeded from. A broken path here only shows up as a
# silently missing skill or hook on the machine that installs the plugin, so pin each one.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:MarketplaceFile = Join-Path $script:RepoRoot '.claude-plugin/marketplace.json'
    $script:SkillDir = Join-Path $script:RepoRoot 'ai-agents/skills/project-brain'
}

Describe 'project-brain Claude Code plugin' {
    It 'lists project-brain in the repo-root marketplace with a source that resolves to the skill directory' {
        Test-Path -LiteralPath $script:MarketplaceFile -PathType Leaf | Should -BeTrue
        $marketplace = Get-Content -LiteralPath $script:MarketplaceFile -Raw | ConvertFrom-Json
        $entry = @($marketplace.plugins | Where-Object name -EQ 'project-brain')
        $entry.Count | Should -Be 1
        $resolved = [IO.Path]::GetFullPath((Join-Path $script:RepoRoot $entry[0].source))
        $resolved | Should -Be ([IO.Path]::GetFullPath($script:SkillDir))
    }

    It 'has a plugin manifest whose skills path holds SKILL.md' {
        $manifestFile = Join-Path $script:SkillDir '.claude-plugin/plugin.json'
        Test-Path -LiteralPath $manifestFile -PathType Leaf | Should -BeTrue
        $manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json
        $manifest.name | Should -Be 'project-brain'
        Test-Path -LiteralPath (Join-Path $script:SkillDir $manifest.skills 'SKILL.md') -PathType Leaf | Should -BeTrue
    }

    It 'wires a SessionStart hook to the bundled session-start.ps1 through CLAUDE_PLUGIN_ROOT' {
        $hooksFile = Join-Path $script:SkillDir 'hooks/hooks.json'
        Test-Path -LiteralPath $hooksFile -PathType Leaf | Should -BeTrue
        $commands = @((Get-Content -LiteralPath $hooksFile -Raw | ConvertFrom-Json).hooks.SessionStart.hooks.command)
        $commands.Count | Should -Be 1
        $commands[0] | Should -BeLike '*${CLAUDE_PLUGIN_ROOT}/scripts/session-start.ps1*'
        Test-Path -LiteralPath (Join-Path $script:SkillDir 'scripts/session-start.ps1') -PathType Leaf | Should -BeTrue
    }

    It 'ships the scaffold templates a new brain area copies' -ForEach @(
        @{ Name = 'core.md' }, @{ Name = 'STATUS.md' }, @{ Name = 'adr.md' }, @{ Name = 'log.md' }
    ) {
        Test-Path -LiteralPath (Join-Path $script:SkillDir 'templates' $Name) -PathType Leaf | Should -BeTrue
    }
}
