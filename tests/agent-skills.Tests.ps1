BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
}

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
        foreach ($path in @($portable, $portableSupport, $claude, $codex, $pi, $agents))
        {
            Test-Path $path | Should -BeTrue
        }
        foreach ($path in @('ai-agents/shared/skills', 'ai-agents/claude/skills', 'ai-agents/codex/skills'))
        {
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

    It 'owns the council skill only in the portable source area' {
        Test-Path (Join-Path $portable 'council/SKILL.md') | Should -BeTrue
        Test-Path (Join-Path $claude 'council') | Should -BeFalse
        Test-Path (Join-Path $codex 'council') | Should -BeFalse
        Test-Path (Join-Path $pi 'council') | Should -BeFalse
    }

    It 'keeps the review-support contract portable-projected only' {
        # #115: lenses.md / findings-schema.md / review-rubric.md / reviewer-models.md live at
        # the portable ai-agents/skills/_shared/ (projected with the review skills below) — the
        # Claude-scoped claude/skills/_shared/ no longer exists. ai-agents/_shared/ (no `skills/`
        # segment) holds only the hooks' banned-ai-terms.txt wordlist; the stale review-contract
        # copy that used to sit beside it is gone and must not come back.
        $portableSkillsShared = Join-Path $portable '_shared'
        foreach ($name in @('lenses.md', 'findings-schema.md', 'review-rubric.md', 'reviewer-models.md'))
        {
            Test-Path (Join-Path $portableSkillsShared $name) | Should -BeTrue
        }
        foreach ($name in @('lenses.md', 'findings-schema.md', 'review-rubric.md'))
        {
            Test-Path (Join-Path $portableSupport $name) | Should -BeFalse
        }
        Test-Path (Join-Path $portableSkillsShared 'SKILL.md') | Should -BeFalse
        Test-Path (Join-Path $portableSupport 'SKILL.md') | Should -BeFalse
        Test-Path (Join-Path $claude '_shared') | Should -BeFalse
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

Describe 'review skills' {
    BeforeAll {
        $repo = Split-Path $PSScriptRoot -Parent
        $claudeSkills = Join-Path $repo 'claude/skills'
        $portableSkills = Join-Path $repo 'ai-agents/skills'
        $codeReview = Get-Content (Join-Path $portableSkills 'code-review/SKILL.md') -Raw
        $loop = Get-Content (Join-Path $portableSkills 'review-to-green/SKILL.md') -Raw
        $fixFindings = Get-Content (Join-Path $portableSkills 'fix-findings/SKILL.md') -Raw
        $lenses = Get-Content (Join-Path $portableSkills '_shared/lenses.md') -Raw
        $rubric = Get-Content (Join-Path $portableSkills '_shared/review-rubric.md') -Raw
        $schema = Get-Content (Join-Path $portableSkills '_shared/findings-schema.md') -Raw
        $reviewerModels = Get-Content (Join-Path $portableSkills '_shared/reviewer-models.md') -Raw
        $claudeAdapter = Get-Content (Join-Path $repo 'claude/CLAUDE.md') -Raw
    }

    It 'owns code-review, review-to-green, and fix-findings as portable skills' {
        foreach ($name in @('code-review', 'review-to-green', 'fix-findings'))
        {
            Test-Path (Join-Path $portableSkills "$name/SKILL.md") | Should -BeTrue
            Test-Path (Join-Path $portableSkills "$name/agents/openai.yaml") | Should -BeTrue
            Test-Path (Join-Path $claudeSkills $name) | Should -BeFalse
        }
        Get-Content (Join-Path $repo 'ai-agents/SKILL-OWNERSHIP.md') -Raw | Should -Match '`review-to-green`'
    }

    It 'names the upstream code-review commit and links the shared contracts' {
        $codeReview | Should -Match '(?s)^---\s*\nname:\s*code-review\s*\n'
        $codeReview | Should -Match ([regex]::Escape('mattpocock/skills `code-review` at commit `6f7f783`'))
        foreach ($contract in @('lenses.md', 'review-rubric.md', 'findings-schema.md'))
        {
            $codeReview | Should -Match ([regex]::Escape("../_shared/$contract"))
        }
    }

    It 'validates every finding and reports what was not covered' {
        $codeReview | Should -Match 'validation subagent'
        $codeReview | Should -Match 'not_reproduced'
        $codeReview | Should -Match 'Not covered'
        $codeReview | Should -Match 'Ready to merge'
        $codeReview | Should -Match 'Not ready: N blocking findings'
    }

    It 'rates severity as likelihood x impact with a blocking rule' {
        foreach ($row in @('| HIGH | HIGH | HIGH | MED |', '| MED | HIGH | MED | LOW |', '| LOW | MED | LOW | LOW |'))
        {
            $rubric | Should -Match ([regex]::Escape($row))
        }
        $rubric | Should -Match 'blocking'
        $rubric | Should -Match 'Do not flag'
        $rubric | Should -Not -MatchExactly 'CLEANUP'
    }

    It 'gives the named smell baseline to the Standards lens' {
        $standardsCharter = [regex]::Match($lenses, '(?s)### Standards\s*\n(.*?)\n### ').Groups[1].Value
        $standardsCharter | Should -Match 'smell baseline'
        $standardsCharter | Should -Match 'judgement call'
        $rubric | Should -Match 'Named smell baseline'
        $rubric | Should -Match 'Refused Bequest'
    }

    It 'records likelihood, impact, and the fixer and loop statuses in the findings schema' {
        foreach ($token in @('`likelihood`', '`impact`', '`blocking`', '`validated`', '`rejected`', '`parked`', '`reviewed_range`', '`fix_lines_added`'))
        {
            $schema | Should -Match ([regex]::Escape($token))
        }
        $schema | Should -Not -Match 'adversarial_verified'
        $schema | Should -Not -Match '`confidence`'
    }

    It 'checks each finding before fixing and keeps fixes minimal' {
        $fixFindings | Should -Match 'Check before fixing'
        $fixFindings | Should -Match '`rejected`'
        $fixFindings | Should -Match 'Minimal fix'
        $fixFindings | Should -Match 'needs redesign'
    }

    It 'bounds review-to-green with a cap of 5 and scope, size budget, and oscillation rails' {
        $loop | Should -Match '(?s)^---\s*\nname:\s*review-to-green\s*\n'
        $loop | Should -Match ([regex]::Escape('--cap 5'))
        $loop | Should -Match 'default 5'
        foreach ($rail in @('scope', 'size budget', 'reappearance', 'oscillation', 'no progress'))
        {
            $loop | Should -Match "\|\s*$rail\s*\|"
        }
        $loop | Should -Not -Match ([regex]::Escape('--reviewers'))
        $loop | Should -Not -Match ([regex]::Escape('--floor'))
    }

    It 'centralizes the fixer model pin at _shared/reviewer-models.md and points every dispatching doc at it' {
        # Canonical home carries the literal policy.
        $reviewerModels | Should -Match 'Fixer pin'
        $reviewerModels | Should -Match 'Default: `sonnet`'
        $reviewerModels | Should -Match '`opus` for a hard'
        $reviewerModels | Should -Not -Match 'Opus 4\.8'
        $reviewerModels | Should -Match 'Never `fable`|never `fable`'
        $reviewerModels | Should -Not -Match ([regex]::Escape('--reviewers'))

        # Every dispatching doc points at the canonical home instead of restating the pin.
        foreach ($content in @($loop, $fixFindings))
        {
            $content | Should -Match ([regex]::Escape('_shared/reviewer-models.md'))
            $content | Should -Match 'Fixer pin'
            $content | Should -Not -Match 'Opus 4\.8'
        }
        $claudeAdapter | Should -Match ([regex]::Escape('ai-agents/skills/_shared/reviewer-models.md'))
        $claudeAdapter | Should -Match 'Fixer pin'
        $claudeAdapter | Should -Not -Match 'Opus 4\.8'
    }

    It 'sets the Codex sandbox and approval policy per call in reviewer-models.md' {
        $reviewerModels | Should -Match ([regex]::Escape('approval-policy: never'))
        $reviewerModels | Should -Match ([regex]::Escape('sandbox: read-only'))
        $codeReview | Should -Match ([regex]::Escape('../_shared/reviewer-models.md'))
    }

    It 'records review-to-green in the routing and standing-consent surfaces' {
        Get-Content (Join-Path $claudeSkills 'router/SKILL.md') -Raw | Should -Match 'review-to-green'
        Get-Content (Join-Path $repo 'claude/CLAUDE.md') -Raw | Should -Match 'review-to-green'
        Get-Content (Join-Path $repo 'claude/README.md') -Raw | Should -Match 'review-to-green'
        Get-Content (Join-Path $repo 'README.md') -Raw | Should -Match 'review-to-green'
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
        foreach ($label in @('tool-backed', 'grep-native', 'skip when absent'))
        {
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

    It 'drafts a body from BODY-TEMPLATE.md when the repository has no PR template' {
        $toPullrequest | Should -Match ([regex]::Escape('[BODY-TEMPLATE.md](BODY-TEMPLATE.md)'))
        $template = Get-Content (Join-Path (Split-Path $skillPath -Parent) 'BODY-TEMPLATE.md') -Raw
        foreach ($section in @('## Summary', '## Evidence', '## Merge Danger'))
        {
            $template | Should -Match ([regex]::Escape($section))
        }
        $template | Should -Match 'Dex Horthy'
    }

    It 'declares CI/merge-gate readiness, review-thread resolution, and auto-complete out of scope' {
        $toPullrequest | Should -Match 'out of scope'
        $toPullrequest | Should -Match 'CI/merge-gate'
        $toPullrequest | Should -Match 'auto-complete'
    }
}
