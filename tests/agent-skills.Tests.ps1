Describe 'agent skill source layout' {
    BeforeAll {
        $repo = Split-Path $PSScriptRoot -Parent
        $shared = Join-Path $repo 'ai-agents/shared/skills'
        $claude = Join-Path $repo 'ai-agents/claude/skills'
    }

    It 'does not retain the old Claude skill source tree' {
        Test-Path (Join-Path $repo 'claude/skills') | Should -BeFalse
    }

    It 'classifies every skill in exactly one source area' {
        $ownership = Get-Content (Join-Path $repo 'ai-agents/SKILL-OWNERSHIP.md') -Raw
        $sharedStart = $ownership.IndexOf('## Shared')
        $claudeStart = $ownership.IndexOf('## Claude-only')
        $codexStart = $ownership.IndexOf('Codex-specific')
        $sharedSection = $ownership.Substring($sharedStart, $claudeStart - $sharedStart)
        $claudeSection = $ownership.Substring($claudeStart, $codexStart - $claudeStart)
        $claudeNames = @([regex]::Matches($claudeSection, '(?m)^- `([^`]+)`') | ForEach-Object { $_.Groups[1].Value })
        $actualShared = @(Get-ChildItem $shared -Directory | Select-Object -ExpandProperty Name)
        $actualClaude = @(Get-ChildItem $claude -Directory | Select-Object -ExpandProperty Name)

        $sharedStart | Should -BeGreaterThan -1
        $actualShared.Count | Should -BeGreaterThan 0
        foreach ($name in $actualClaude) {
            $claudeNames | Should -Contain $name
        }
        $actualClaude.Count | Should -Be $claudeNames.Count
        (@($actualShared + $actualClaude) | Sort-Object -Unique).Count | Should -Be ($actualShared.Count + $actualClaude.Count)
    }

    It 'stores the custom agents in the shared agent source area' {
        $agents = Join-Path $repo 'ai-agents/shared/agents'
        Test-Path $agents | Should -BeTrue
        @(Get-ChildItem $agents -File -Filter '*.md').Count | Should -BeGreaterThan 0
        Test-Path (Join-Path $repo 'claude/agents') | Should -BeFalse
    }

    It 'keeps shared skills free of runtime-specific source references' {
        $hits = Get-ChildItem $shared -Recurse -File | Select-String -Pattern 'ai-agents/claude/skills|ai-agents/claude/agents'
        $hits | Should -BeNullOrEmpty
    }
}
