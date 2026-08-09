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

Describe 'review skill split' {
    BeforeAll {
        $repo = Split-Path $PSScriptRoot -Parent
        $claudeSkills = Join-Path $repo 'claude/skills'
        $quickReview = Get-Content (Join-Path $claudeSkills 'quick-review/SKILL.md') -Raw -ErrorAction SilentlyContinue
        $deepReview = Get-Content (Join-Path $claudeSkills 'deep-review/SKILL.md') -Raw
        $loop = Get-Content (Join-Path $claudeSkills 'review-fix-loop/SKILL.md') -Raw
        $fixFindings = Get-Content (Join-Path $claudeSkills 'fix-findings/SKILL.md') -Raw
        $reviewerModels = Get-Content (Join-Path $claudeSkills '_shared/reviewer-models.md') -Raw -ErrorAction SilentlyContinue
    }

    It 'owns quick-review as a Claude-native skill classified in SKILL-OWNERSHIP' {
        Test-Path (Join-Path $claudeSkills 'quick-review/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $repo 'ai-agents/skills/quick-review') | Should -BeFalse
        Get-Content (Join-Path $repo 'ai-agents/SKILL-OWNERSHIP.md') -Raw | Should -Match '`quick-review`'
    }

    It 'folds quick-review onto the existing dimension labels and the shared pipeline' {
        foreach ($dimension in @('correctness', 'conventions', 'tests')) {
            $quickReview | Should -Match "``$dimension``"
        }
        $quickReview | Should -Match ([regex]::Escape('../_shared/findings-schema.md'))
        $quickReview | Should -Match ([regex]::Escape('../_shared/dimensions.md'))
        $quickReview | Should -Not -Match "dimension``?: ``?quick"
    }

    It 'defaults review-fix-loop to quick-review with an opt-in deep flag' {
        $loop | Should -Match 'quick-review'
        $loop | Should -Match ([regex]::Escape('--deep'))
        $loop | Should -Match ([regex]::Escape('quick-review → fix-findings'))
        $deepReview | Should -Match 'opt-in'
    }

    It 'routes routine review phrasing to quick-review, not deep-review' {
        $quickDescription = [regex]::Match($quickReview, '(?s)^---.*?description:(.*?)\n---').Groups[1].Value
        $deepDescription = [regex]::Match($deepReview, '(?s)^---.*?description:(.*?)\n---').Groups[1].Value
        $quickDescription | Should -Match 'default'
        $quickDescription | Should -Match 'review the diff'
        $deepDescription | Should -Not -Match 'review and fix'
        $deepDescription | Should -Match 'quick-review, the default'
    }

    It 'documents --reviewers on the reviewer skills and the loop, resolving the sol alias' {
        foreach ($content in @($quickReview, $loop, $deepReview)) {
            $content | Should -Match ([regex]::Escape('--reviewers'))
        }
        $reviewerModels | Should -Match 'gpt-5\.6-sol'
        $reviewerModels | Should -Match 'model_reasoning_effort'
        $reviewerModels | Should -Match 'reviewer'
    }

    It 'keeps --reviewers away from fixer model selection' {
        $fixFindings | Should -Match ([regex]::Escape('`--reviewers` argument does not apply here'))
        $reviewerModels | Should -Match 'Reviewer-only'
        $reviewerModels | Should -Match 'never\s+touches fixer model selection'
    }

    It 'pins fixer models to the current allowed set in both fixer-dispatching skills' {
        foreach ($content in @($loop, $fixFindings)) {
            $content | Should -Match 'Opus 4\.8'
            $content | Should -Match 'Sonnet 5'
            $content | Should -Match 'never Opus 5'
            $content | Should -Match 'never Fable'
        }
    }

    It 'sets the Codex sandbox and approval policy per call in both reviewer skills' {
        foreach ($content in @($quickReview, $deepReview)) {
            $content | Should -Match ([regex]::Escape('approval-policy: never'))
            $content | Should -Match ([regex]::Escape('sandbox: read-only'))
        }
    }

    It 'records quick-review in the routing and standing-consent surfaces' {
        Get-Content (Join-Path $claudeSkills 'router/SKILL.md') -Raw | Should -Match 'quick-review'
        Get-Content (Join-Path $repo 'claude/CLAUDE.md') -Raw | Should -Match 'quick-review'
        Get-Content (Join-Path $repo 'claude/README.md') -Raw | Should -Match 'quick-review'
        Get-Content (Join-Path $repo 'README.md') -Raw | Should -Match 'quick-review'
    }
}
