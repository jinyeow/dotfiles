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

    It 'owns all council skills only in the shared source area' {
        foreach ($name in @('council', 'council-code', 'council-business', 'council-plan', 'council-doc')) {
            Test-Path (Join-Path $shared "$name/SKILL.md") | Should -BeTrue
            Test-Path (Join-Path $claude $name) | Should -BeFalse
        }
    }

    It 'keeps council aliases thin and linked to the shared contract' {
        foreach ($name in @('council-code', 'council-business', 'council-plan', 'council-doc')) {
            $aliasPath = Join-Path $shared "$name/SKILL.md"
            $content = Get-Content $aliasPath -Raw
            $contractLink = [regex]::Match($content, '\]\((\.\./council/SKILL\.md)\)').Groups[1].Value
            $contractLink | Should -Not -BeNullOrEmpty
            Test-Path (Join-Path (Split-Path $aliasPath -Parent) $contractLink) | Should -BeTrue
            $content | Should -Match 'Pass through'
            $content | Should -Not -Match '(?s)NORMALIZE.*CAPABILITIES.*SELECT'
        }
    }

    It 'defines runtime-neutral cost and role contracts for council' {
        $council = Join-Path $shared 'council'
        $content = Get-Content (Join-Path $council 'SKILL.md') -Raw
        Test-Path (Join-Path $council 'references/critic-contract.md') | Should -BeTrue
        Test-Path (Join-Path $council 'references/chair-contract.md') | Should -BeTrue
        Test-Path (Join-Path $council 'references/codex-charter.md') | Should -BeTrue
        $content | Should -Match 'references/codex-charter\.md'
        $content | Should -Match 'default mode is \*\*quick\*\*'
        $content | Should -Match '--debate'
        $content | Should -Match '--codex'
        $content | Should -Match '2–5'
        $content | Should -Match 'call cap of \*\*12\*\*'
        $content | Should -Match '(?s)precedence order.*\*\*plan\*\*.*\*\*code\*\*.*\*\*business\*\*.*\*\*doc\*\*'
        $content | Should -Match '(?s)Which council panel\s+should review this: code, business, plan, or doc\?'
        $content | Should -Match '\.agents/council/reports/'
        $content | Should -Not -Match 'ai-agents/claude/skills|\.claude/council|mcp__|council-critic|council-chair|Opus|Sonnet|Fable'
    }

    It 'does not retain obsolete flat council agents' {
        Test-Path (Join-Path $repo 'ai-agents/shared/agents/council-critic.md') | Should -BeFalse
        Test-Path (Join-Path $repo 'ai-agents/shared/agents/council-chair.md') | Should -BeFalse
    }
}
