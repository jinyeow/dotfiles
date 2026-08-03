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
        $skills = @(
            Get-ChildItem $shared -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }
            Get-ChildItem $claude -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }
        )
        $skills | Should -Not -BeNullOrEmpty
        foreach ($skill in $skills) {
            $ownership | Should -Match ([regex]::Escape(('`{0}`' -f $skill.Name)))
            Test-Path (Join-Path $skill.FullName 'SKILL.md') | Should -BeTrue
        }
        (@($skills.Name) | Sort-Object -Unique).Count | Should -Be $skills.Count
    }

    It 'keeps shared skills free of runtime-specific source references' {
        $hits = Get-ChildItem $shared -Recurse -File | Select-String -Pattern 'claude/skills|codex/skills|~/.claude|~/.codex'
        $hits | Should -BeNullOrEmpty
    }
}
