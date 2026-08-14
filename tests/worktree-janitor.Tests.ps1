Describe 'worktree-janitor skill' {
    BeforeAll {
        $repo = Split-Path $PSScriptRoot -Parent
        $skillPath = Join-Path $repo 'ai-agents/skills/worktree-janitor/SKILL.md'
    }

    It 'exists under the portable skill source area' {
        Test-Path $skillPath | Should -BeTrue
    }

    It 'carries frontmatter naming the skill with trigger phrasing and explicit negative triggers' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match '(?s)^---\s*\nname:\s*worktree-janitor\s*\n'
        $description = [regex]::Match($content, '(?s)description:\s*"(.*?)"\s*\n').Groups[1].Value
        $description | Should -Not -BeNullOrEmpty
        $description | Should -Match 'clean up (my )?worktrees'
        $description | Should -Match 'NOT for'
    }

    It 'cites the global AGENTS.md Git worktrees convention without claiming this repo''s own root AGENTS.md has that section' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Not -Match 'root `AGENTS\.md`'
        $content | Should -Match 'global `AGENTS\.md`'
        $content | Should -Match ([regex]::Escape('claude/AGENTS.md'))
    }

    It 'flags the az repos pr list --source-branch ref form as unverified against the installed CLI version' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match 'Unverified:.*--source-branch'
        $content | Should -Match 'locally installed'
    }

    It 'scans all worktrees via git worktree list in one sweep and excludes non-candidates' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match ([regex]::Escape('git worktree list'))
        $content | Should -Match 'bare'
        $content | Should -Match 'main'
        $content | Should -Match 'detached'
        $content | Should -Match ([regex]::Escape('.claude/worktrees/'))
    }

    It 'routes to gh pr list or az repos pr list based on the remote host per worktree' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match ([regex]::Escape('git remote get-url origin'))
        $content | Should -Match ([regex]::Escape('gh pr list --state merged --head "<branch>"'))
        $content | Should -Match ([regex]::Escape('az repos pr list --status completed'))
        $content | Should -Match ([regex]::Escape('--source-branch "<branch>"'))
        $content | Should -Match 'github\.com'
        $content | Should -Match 'dev\.azure\.com'
    }

    It 'verifies the matched PR head SHA against the branch tip before trusting a merged/completed PR signal' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match 'branch name only, not by commit'
        $content | Should -Match ([regex]::Escape('git rev-parse "refs/heads/<branch>"'))
        $content | Should -Not -Match ([regex]::Escape('git rev-parse "<branch>"'))
        $content | Should -Match 'stale'
    }

    It 'verifies merge-base ancestry before trusting git branch -d as a safety signal' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match ([regex]::Escape('git merge-base --is-ancestor "refs/heads/<branch>" "refs/heads/main"'))
        $content | Should -Not -Match ([regex]::Escape('--is-ancestor "<branch>" main'))
        $content | Should -Match 'not a sufficient safety signal'
    }

    It 'gates worktree removal on the main-ancestry check, not just the branch delete' {
        $content = Get-Content $skillPath -Raw
        $ancestorIndex = $content.IndexOf('merge-base --is-ancestor')
        $removeIndex = $content.IndexOf('git worktree remove')
        $ancestorIndex | Should -BeGreaterThan -1
        $removeIndex | Should -BeGreaterThan -1
        $ancestorIndex | Should -BeLessThan $removeIndex
    }

    It 'falls back to the project-brain STATUS.md when a worktree has no remote' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match 'No remote'
        $content | Should -Match '`project-brain`'
        $content | Should -Match 'STATUS\.md'
    }

    It 'requires the STATUS.md entry to explicitly name this branch and treats a stale entry as inconclusive' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match 'explicitly names this branch or this worktree'
        $content | Should -Match '7 days'
        $content | Should -Match 'stale'
    }

    It 'reports a dirty worktree-remove refusal to the user instead of forcing it' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match 'dirty'
        $content | Should -Match 'never escalate to `--force`'
    }

    It 'prompts for manual approval when neither signal is available' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match 'Neither signal exists'
        $content | Should -Match 'prompt for manual approval'
    }

    It 'fully automates worktree remove and git branch -d for non-squash-merged branches' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match ([regex]::Escape('git pull'))
        $content | Should -Match ([regex]::Escape('git worktree remove "<dir>"'))
        $content | Should -Match ([regex]::Escape('git branch -d "<branch>"'))
        $content | Should -Match 'fully automated'
    }

    It 'instructs quoting every dynamic path or branch name in both executed and printed commands' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match 'Quote every dynamic path or branch name'
    }

    It 'batches pending squash-merged branches into one printed git branch -D command, never runs it itself' {
        $content = Get-Content $skillPath -Raw
        $content | Should -Match ([regex]::Escape('git diff "refs/heads/main" "refs/heads/<branch>" --stat'))
        $content | Should -Not -Match ([regex]::Escape('git diff main "'))
        $content | Should -Match 'Do \*\*not\*\* run `git branch -D` yourself'
        $content | Should -Match ([regex]::Escape('git branch -D "branch-a" "branch-b" "branch-c"'))
    }

    It 'treats an empty squash-merge diff as safe to batch and a non-empty diff as unlanded divergence to stop on' {
        $content = Get-Content $skillPath -Raw
        # empty diff => safe/batch, stated without the "non-" prefix
        $content | Should -Match '(?<!non-)(?i)\bempty\b[^\n]{0,80}\b(safe|batch)'
        # non-empty diff => stop/surface to the user, real divergence -- not batched
        $content | Should -Match '(?i)non-empty[^\n]{0,80}\b(stop|surface|not batch|do not batch|divergence)'
    }

    It 'is registered in the root README skills table' {
        Get-Content (Join-Path $repo 'README.md') -Raw | Should -Match '`worktree-janitor`'
    }
}
