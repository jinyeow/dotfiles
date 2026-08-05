Describe 'agent skill source layout' {
    BeforeAll {
        $repo = Split-Path $PSScriptRoot -Parent
        $portable = Join-Path $repo 'ai-agents/skills'
        $portableSupport = Join-Path $repo 'ai-agents/_shared'
        $claude = Join-Path $repo 'claude/skills'
        $codex = Join-Path $repo 'codex/skills'
        $pi = Join-Path $repo 'pi/skills'
        $agents = Join-Path $repo 'ai-agents/agents'
    }

    It 'has the approved current source directories and no superseded trees' {
        foreach ($path in @($portable, $portableSupport, $claude, $codex, $pi, $agents)) {
            Test-Path $path | Should -BeTrue
        }
        foreach ($path in @('ai-agents/shared/skills', 'ai-agents/claude/skills', 'ai-agents/codex/skills')) {
            Test-Path (Join-Path $repo $path) | Should -BeFalse
        }
    }

    It 'classifies every current skill in exactly one runtime source area' {
        $ownership = Get-Content (Join-Path $repo 'ai-agents/SKILL-OWNERSHIP.md') -Raw
        $portableNames = @(Get-ChildItem $portable -Directory | Select-Object -ExpandProperty Name)
        $claudeNames = @(Get-ChildItem $claude -Directory | Select-Object -ExpandProperty Name)
        $codexNames = @(Get-ChildItem $codex -Directory | Select-Object -ExpandProperty Name)
        $piNames = @(Get-ChildItem $pi -Directory | Select-Object -ExpandProperty Name)
        $ownership | Should -Match '## Portable \(`ai-agents/skills/`\)'
        $ownership | Should -Match '## Claude-native \(`claude/skills/`\)'
        $ownership | Should -Match '## Codex-native \(`codex/skills/`\)'
        $ownership | Should -Match '## Pi-native \(`pi/skills/`\)'
        $portableNames.Count | Should -BeGreaterThan 0
        $claudeNames.Count | Should -BeGreaterThan 0
        (@($portableNames + $claudeNames + $codexNames + $piNames) | Sort-Object -Unique).Count |
            Should -Be (@($portableNames + $claudeNames + $codexNames + $piNames).Count)
    }

    It 'stores custom agents in the canonical agent source area' {
        Test-Path $agents | Should -BeTrue
        @(Get-ChildItem $agents -File -Filter '*.md').Count | Should -BeGreaterThan 0
        Test-Path (Join-Path $repo 'ai-agents/shared/agents') | Should -BeFalse
        Test-Path (Join-Path $repo 'claude/agents') | Should -BeFalse
    }

    It 'keeps portable skills and support free of prohibited Claude-only source references' {
        $hits = Get-ChildItem $portable, $portableSupport -Recurse -File |
            Select-String -Pattern 'ai-agents/(shared|claude|codex)/skills'
        $hits | Should -BeNullOrEmpty
    }

    It 'owns council skills only in the portable source area' {
        foreach ($name in @('council', 'council-code', 'council-business', 'council-plan', 'council-doc')) {
            Test-Path (Join-Path $portable "$name/SKILL.md") | Should -BeTrue
            Test-Path (Join-Path $claude $name) | Should -BeFalse
            Test-Path (Join-Path $codex $name) | Should -BeFalse
            Test-Path (Join-Path $pi $name) | Should -BeFalse
        }
    }

    It 'keeps Claude support projected and portable support source-only' {
        foreach ($name in @('dimensions.md', 'findings-schema.md', 'review-rubric.md')) {
            Test-Path (Join-Path $claude "_shared/$name") | Should -BeTrue
            Test-Path (Join-Path $portableSupport $name) | Should -BeTrue
        }
        Test-Path (Join-Path $portableSupport 'SKILL.md') | Should -BeFalse
    }

    It 'keeps council aliases thin and linked to the portable contract' {
        foreach ($name in @('council-code', 'council-business', 'council-plan', 'council-doc')) {
            $aliasPath = Join-Path $portable "$name/SKILL.md"
            $content = Get-Content $aliasPath -Raw
            $contractLink = [regex]::Match($content, '\]\((\.\./council/SKILL\.md)\)').Groups[1].Value
            $contractLink | Should -Not -BeNullOrEmpty
            Test-Path (Join-Path (Split-Path $aliasPath -Parent) $contractLink) | Should -BeTrue
            $content | Should -Match 'Pass through'
            $content | Should -Not -Match '(?s)NORMALIZE.*CAPABILITIES.*SELECT'
        }
    }

    It 'defines runtime-neutral council contracts' {
        $council = Join-Path $portable 'council'
        $content = Get-Content (Join-Path $council 'SKILL.md') -Raw
        Test-Path (Join-Path $council 'references/critic-contract.md') | Should -BeTrue
        Test-Path (Join-Path $council 'references/chair-contract.md') | Should -BeTrue
        Test-Path (Join-Path $council 'references/codex-charter.md') | Should -BeTrue
        $content | Should -Match 'default mode is \*\*quick\*\*'
        $content | Should -Match 'call cap of \*\*12\*\*'
        $content | Should -Not -Match 'ai-agents/(shared|claude)/skills|\.claude/council|mcp__|Opus|Sonnet|Fable'
    }

    It 'does not retain obsolete flat council agents' {
        Test-Path (Join-Path $repo 'ai-agents/agents/council-critic.md') | Should -BeFalse
        Test-Path (Join-Path $repo 'ai-agents/agents/council-chair.md') | Should -BeFalse
    }
}
