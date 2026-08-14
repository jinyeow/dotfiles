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

    It 'keeps the review-support contract portable-projected, plus a separate source-only copy' {
        # #115: dimensions.md / findings-schema.md / review-rubric.md / reviewer-models.md live at
        # the portable ai-agents/skills/_shared/ (projected with the review skills below) — the
        # Claude-scoped claude/skills/_shared/ no longer exists. ai-agents/_shared/ (no `skills/`
        # segment) is a separate, unrelated, source-only copy that predates the split and is not
        # projected — the two must not be confused.
        $portableSkillsShared = Join-Path $portable '_shared'
        foreach ($name in @('dimensions.md', 'findings-schema.md', 'review-rubric.md', 'reviewer-models.md')) {
            Test-Path (Join-Path $portableSkillsShared $name) | Should -BeTrue
        }
        # ai-agents/_shared/ (source-only, unrelated) predates the #101 skill split and never
        # picked up reviewer-models.md — only the three original files.
        foreach ($name in @('dimensions.md', 'findings-schema.md', 'review-rubric.md')) {
            Test-Path (Join-Path $portableSupport $name) | Should -BeTrue
        }
        Test-Path (Join-Path $portableSkillsShared 'SKILL.md') | Should -BeFalse
        Test-Path (Join-Path $portableSupport 'SKILL.md') | Should -BeFalse
        Test-Path (Join-Path $claude '_shared') | Should -BeFalse
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
        $portableSkills = Join-Path $repo 'ai-agents/skills'
        $quickReview = Get-Content (Join-Path $portableSkills 'quick-review/SKILL.md') -Raw -ErrorAction SilentlyContinue
        $deepReview = Get-Content (Join-Path $portableSkills 'deep-review/SKILL.md') -Raw
        $loop = Get-Content (Join-Path $portableSkills 'review-fix-loop/SKILL.md') -Raw
        $fixFindings = Get-Content (Join-Path $portableSkills 'fix-findings/SKILL.md') -Raw
        $reviewerModels = Get-Content (Join-Path $portableSkills '_shared/reviewer-models.md') -Raw -ErrorAction SilentlyContinue
        $deepReviewReference = Get-Content (Join-Path $portableSkills 'deep-review/REFERENCE.md') -Raw
        $claudeAdapter = Get-Content (Join-Path $repo 'claude/CLAUDE.md') -Raw
    }

    It 'owns quick-review as a portable skill classified in SKILL-OWNERSHIP (#115)' {
        Test-Path (Join-Path $portableSkills 'quick-review/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $claudeSkills 'quick-review') | Should -BeFalse
        Get-Content (Join-Path $repo 'ai-agents/SKILL-OWNERSHIP.md') -Raw | Should -Match '`quick-review`'
    }

    It 'owns deep-review, review-fix-loop, and fix-findings as portable skills (#115)' {
        foreach ($name in @('deep-review', 'review-fix-loop', 'fix-findings')) {
            Test-Path (Join-Path $portableSkills "$name/SKILL.md") | Should -BeTrue
            Test-Path (Join-Path $claudeSkills $name) | Should -BeFalse
        }
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

    It 'flags --reviewers as unsupported on Codex CLI on the reviewer skills Args tables and the loop' {
        foreach ($content in @($quickReview, $deepReviewReference, $loop)) {
            $content | Should -Match ([regex]::Escape('unsupported on Codex CLI'))
        }
    }

    It 'keeps --reviewers away from fixer model selection' {
        $fixFindings | Should -Match ([regex]::Escape('`--reviewers` argument does not apply here'))
        $reviewerModels | Should -Match 'Reviewer-only'
        $reviewerModels | Should -Match 'never\s+touches fixer model selection'
    }

    It 'pins fixer models to the current allowed set in the fixer-dispatching skills and the Claude adapter' {
        foreach ($content in @($loop, $fixFindings, $claudeAdapter)) {
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

        # deep-review calls Codex twice (fan out + the verify second voice); both call sites carry it.
        foreach ($token in @('approval-policy: never', 'sandbox: read-only')) {
            [regex]::Matches($deepReview, [regex]::Escape($token)).Count | Should -BeGreaterOrEqual 2
        }
    }

    It 'records quick-review in the routing and standing-consent surfaces' {
        Get-Content (Join-Path $claudeSkills 'router/SKILL.md') -Raw | Should -Match 'quick-review'
        Get-Content (Join-Path $repo 'claude/CLAUDE.md') -Raw | Should -Match 'quick-review'
        Get-Content (Join-Path $repo 'claude/README.md') -Raw | Should -Match 'quick-review'
        Get-Content (Join-Path $repo 'README.md') -Raw | Should -Match 'quick-review'
    }
}

Describe 'techdebt skill' {
    BeforeAll {
        $repo = Split-Path $PSScriptRoot -Parent
        $skillDir = Join-Path $repo 'ai-agents/skills/techdebt'
        $skillPath = Join-Path $skillDir 'SKILL.md'
        $techdebt = Get-Content $skillPath -Raw
    }

    It 'exists under the portable skill source area' {
        Test-Path $skillPath | Should -BeTrue
    }

    It 'carries frontmatter with a name and a description that names its boundary' {
        $techdebt | Should -Match '(?s)^---\s*\nname:\s*techdebt\s*\n'
        $description = [regex]::Match($techdebt, '(?s)description:\s*(.*?)\s*\n---').Groups[1].Value
        $description | Should -Not -BeNullOrEmpty
        $description | Should -Match 'improve-codebase-architecture'
    }

    It 'points to TOOLS.md and the file resolves with a tool-evidence label per category, stated once' {
        $techdebt | Should -Match ([regex]::Escape('[TOOLS.md](TOOLS.md)'))
        $toolsPath = Join-Path $skillDir 'TOOLS.md'
        Test-Path $toolsPath | Should -BeTrue
        $tools = Get-Content $toolsPath -Raw
        foreach ($label in @('tool-backed', 'grep-native', 'skip when absent')) {
            $tools | Should -Match ([regex]::Escape($label))
        }
        # category-level policy (what counts as debt, what to verify) lives once in SKILL.md;
        # TOOLS.md carries only stack-command mappings, not a restated copy of the rule
        $tools | Should -Not -Match 'not a security review'
        $tools | Should -Not -Match 'genuinely duplicated business logic'
    }

    It 'skips categories with no available stack tool instead of approximating with grep' {
        $techdebt | Should -Match 'skipped'
        $techdebt | Should -Match 'Not assessed'
    }

    It 'hands off approved findings to to-tickets rather than drafting tickets itself' {
        $techdebt | Should -Match ([regex]::Escape('../to-tickets/SKILL.md'))
        Test-Path (Join-Path $repo 'ai-agents/skills/to-tickets/SKILL.md') | Should -BeTrue
        $techdebt | Should -Match 'Pass only the findings the user approves'
    }
}

Describe 'to-pullrequest skill' {
    BeforeAll {
        $repo = Split-Path $PSScriptRoot -Parent
        $skillPath = Join-Path $repo 'ai-agents/skills/to-pullrequest/SKILL.md'
        $toPullrequest = Get-Content $skillPath -Raw
    }

    It 'exists under the portable skill source area' {
        Test-Path $skillPath | Should -BeTrue
    }

    It 'auto-fires on pull-request phrasing and carries explicit negative triggers' {
        $description = [regex]::Match($toPullrequest, '(?s)description:\s*"(.*?)"\s*\n').Groups[1].Value
        $description | Should -Match 'open a PR'
        $description | Should -Match 'create a pull request'
        $description | Should -Match 'NOT for reviewing an existing PR'
        $description | Should -Match 'NOT for merging'
    }

    It 'routes the drafted title/body through write before calling gh or az' {
        $toPullrequest | Should -Match 'the `write` skill'
        $toPullrequest | Should -Match ([regex]::Escape('gh pr create'))
        $toPullrequest | Should -Match ([regex]::Escape('az repos pr create'))
    }

    It 'implements the branch guard, dirty-tree guard, and draft-vs-ready step' {
        $toPullrequest | Should -Match 'Branch guard'
        $toPullrequest | Should -Match 'Git worktrees'
        $toPullrequest | Should -Match 'Dirty-tree guard'
        $toPullrequest | Should -Match 'Draft vs ready'
        $toPullrequest | Should -Match ([regex]::Escape('--draft'))
    }

    It 'passes the PR body by temp file, never inline' {
        $toPullrequest | Should -Match ([regex]::Escape('--body-file'))
        $toPullrequest | Should -Not -Match '--body\s+"[^"]*\n'
    }

    It 'links GitHub issues via body text and Azure DevOps work items via the --work-items flag' {
        $toPullrequest | Should -Match 'Fixes #N'
        $toPullrequest | Should -Match 'Closes #N'
        $toPullrequest | Should -Match ([regex]::Escape('--work-items'))
    }

    It 'declares CI/merge-gate readiness, review-thread resolution, and auto-complete out of scope' {
        $toPullrequest | Should -Match 'out of scope'
        $toPullrequest | Should -Match 'CI/merge-gate'
        $toPullrequest | Should -Match 'auto-complete'
    }
}
