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
        $sharedSection = [regex]::Match($ownership, '(?s)## Shared \(`ai-agents/shared/skills/`\)(.*?)(?=\r?\n## Claude-only)').Groups[1].Value
        $claudeSection = [regex]::Match($ownership, '(?s)## Claude-only \(`ai-agents/claude/skills/`\)(.*?)(?=\r?\n\r?\nCodex-specific)').Groups[1].Value
        $sharedNames = @([regex]::Matches($sharedSection, '(?m)^- `([^`]+)`$') | ForEach-Object { $_.Groups[1].Value })
        $claudeNames = @([regex]::Matches($claudeSection, '(?m)^- `([^`]+)`$') | ForEach-Object { $_.Groups[1].Value })
        $actualShared = @(Get-ChildItem $shared -Directory | Select-Object -ExpandProperty Name)
        $actualClaude = @(Get-ChildItem $claude -Directory | Select-Object -ExpandProperty Name)

        $sharedNames | Sort-Object | Should -Be ($actualShared | Sort-Object)
        $claudeNames | Sort-Object | Should -Be ($actualClaude | Sort-Object)
        (@($sharedNames + $claudeNames) | Sort-Object -Unique).Count | Should -Be ($sharedNames.Count + $claudeNames.Count)
    }

    It 'keeps shared skills free of runtime-specific source references' {
        $hits = Get-ChildItem $shared -Recurse -File | Select-String -Pattern 'claude/skills|codex/skills|~/.claude|~/.codex|/to-(spec|hld|tickets)|/setup-agent-skills|CLAUDE\.md'
        $hits | Should -BeNullOrEmpty
    }
}
