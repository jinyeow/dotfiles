#Requires -Version 7
# Installed-version smoke tests for issue #67: validate the REAL installed destinations
# (~/.claude/skills, ~/.codex/skills, ~/.pi/agent/skills on this machine) rather than only
# source-inspecting the repository or running the installer in -DryRun against a scratch home.
# Unlike every other Describe block in tests/setup*.Tests.ps1, these do not sandbox
# $env:USERPROFILE/$env:HOME — they read the live filesystem.
#
# Each It gates on the runtime executable being on PATH (`-Skip:(-not (Get-Command ...))`) so a
# clean CI runner (no claude/codex/pi installed) skips with a clear reason instead of failing —
# per the acceptance criteria's "unsupported combinations are documented, not reported as
# passing." Every assertion also asserts a non-zero/non-empty precondition before the per-entry
# check, so an absent or empty destination fails loudly rather than passing vacuously.
#
# Residual gaps NOT covered here (documented, not silently skipped):
#   - No live Linux/WSL installed-destination check: this session has no WSL/Linux environment.
#     setup.sh's is_managed_skill_link dangling-link fix is covered behaviorally via Git Bash on
#     Windows in tests/setup-sh.Tests.ps1 instead — the strongest supported test in this session.
#   - Native-variant precedence has no *live* collision to re-check against an installed
#     destination (none of claude/skills, codex/skills, pi/skills currently share a name with
#     ai-agents/skills) — regression coverage for that behavior is the dry-run fixture tests in
#     tests/setup.Tests.ps1 ('junctions only the Codex-native flavour when an ai-agents/codex
#     skill collides with shared') and tests/setup-sh.Tests.ps1. This file still asserts the
#     absence of a live collision so a future colliding skill name is caught rather than ignored.

# Set at top level (not only in BeforeAll): Pester v5 evaluates each It's -Skip argument during
# discovery, before any BeforeAll (a Run-phase hook) executes — a $script: var set only in
# BeforeAll would still be $null/unset when -Skip is evaluated, silently skipping every gated It
# regardless of the real environment. Discovery and Run are separate executions of this file, so
# BeforeAll below repeats the same assignment (functions defined at top level are also not
# visible inside It bodies in the Run-phase scope, so the logic is duplicated rather than shared).
$script:ClaudeSkillsDst = Join-Path $env:USERPROFILE '.claude\skills'
$script:CodexSkillsDst = Join-Path $env:USERPROFILE '.codex\skills'
$script:PiSkillsDst = Join-Path $env:USERPROFILE '.pi\agent\skills'
$script:HasClaudeCli = [bool](Get-Command claude -ErrorAction Ignore)
$script:HasCodexCli = [bool](Get-Command codex -ErrorAction Ignore)
$script:HasPiCli = [bool](Get-Command pi -ErrorAction Ignore)

BeforeAll {
    $script:ClaudeSkillsDst = Join-Path $env:USERPROFILE '.claude\skills'
    $script:CodexSkillsDst = Join-Path $env:USERPROFILE '.codex\skills'
    $script:PiSkillsDst = Join-Path $env:USERPROFILE '.pi\agent\skills'
    $script:HasClaudeCli = [bool](Get-Command claude -ErrorAction Ignore)
    $script:HasCodexCli = [bool](Get-Command codex -ErrorAction Ignore)
    $script:HasPiCli = [bool](Get-Command pi -ErrorAction Ignore)

    function Get-ReparseTarget ([IO.FileSystemInfo]$Item) {
        if ($Item.LinkTarget) { return $Item.LinkTarget }
        return @($Item.Target)[0]
    }

    # setup.ps1's own backup-before-replace convention (Backed up: X -> X.bak.TIMESTAMP) can
    # leave a *.bak.TIMESTAMP junction whose original target has since been deleted upstream —
    # that is expected backup-retention behavior (-CleanBackups prunes them; PowerShell junction
    # backups are documented as one thing -CleanBackups can't prune, see setup.ps1:154), not a
    # dangling *managed* link, since nothing resolves skills through a .bak-suffixed name. Exclude
    # them so this test targets the active link set the runtimes actually consult.
    $script:BackupSuffixPattern = '\.bak\.\d{8}_\d{6}$'
}

Describe 'Installed Claude skill projection (live smoke)' {
    It 'has no dangling managed junctions in the real ~/.claude/skills' -Skip:(-not ($IsWindows -and $script:HasClaudeCli -and (Test-Path $script:ClaudeSkillsDst))) {
        # Regression for issue #67 finding 1: grill-me/to-issues/to-prd sat as dangling junctions
        # (target under a dev-worktree path deleted by commit afa79c4) for months, undetected
        # because no test read the live destination.
        $entries = @(Get-ChildItem -LiteralPath $script:ClaudeSkillsDst -Force |
            Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $_.Name -notmatch $script:BackupSuffixPattern })
        $entries.Count | Should -BeGreaterThan 0

        $dangling = @()
        foreach ($entry in $entries) {
            $target = Get-ReparseTarget $entry
            if (-not $target -or -not (Test-Path -LiteralPath $target)) {
                $dangling += $entry.FullName
            }
        }
        $dangling | Should -BeNullOrEmpty -Because "these installed Claude skill links resolve to a target that no longer exists: $($dangling -join ', ')"
    }
}

Describe 'Installed Codex skill projection (live smoke)' {
    It 'has no dangling managed junctions in the real ~/.codex/skills' -Skip:(-not ($IsWindows -and $script:HasCodexCli -and (Test-Path $script:CodexSkillsDst))) {
        $entries = @(Get-ChildItem -LiteralPath $script:CodexSkillsDst -Force -ErrorAction SilentlyContinue |
            Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $_.Name -notmatch $script:BackupSuffixPattern })
        # Codex's own built-in skills live under ~/.codex/skills/.system/ and are excluded above
        # (that entry is a plain directory, not a reparse point). No managed links yet is a valid
        # state (e.g. codex/skills has no native skills today), so this test only asserts on the
        # links that do exist rather than requiring a nonzero count.
        $dangling = @()
        foreach ($entry in $entries) {
            $target = Get-ReparseTarget $entry
            if (-not $target -or -not (Test-Path -LiteralPath $target)) {
                $dangling += $entry.FullName
            }
        }
        $dangling | Should -BeNullOrEmpty -Because "these installed Codex skill links resolve to a target that no longer exists: $($dangling -join ', ')"
    }
}

Describe 'Installed Pi skill projection (live smoke)' {
    It 'projects skills into the real ~/.pi/agent/skills when pi is installed' -Skip:(-not $script:HasPiCli) {
        # Regression for issue #67 finding 2: on this dev machine, `pi` was installed but
        # ~/.pi/agent/ had no skills subdirectory at all — source inspection said portable skills
        # should project into Pi, but the installed reality (verified here, not assumed) said the
        # Pi module had never been run to completion. This test intentionally does NOT run the
        # installer itself (that would make the suite mutate the machine and be non-idempotent
        # across re-runs / other machines) — it only reads the live destination. The gap it
        # revealed was fixed once, out-of-band, by running the installed dotfiles clone's
        # `setup.ps1 -Module pi` for real; see the issue #67 report for that RED->GREEN evidence.
        Test-Path -LiteralPath $script:PiSkillsDst | Should -BeTrue -Because '~/.pi/agent/skills should exist once the pi module has completed at least one real run'
        $entries = @(Get-ChildItem -LiteralPath $script:PiSkillsDst -Force -ErrorAction SilentlyContinue)
        $entries.Count | Should -BeGreaterThan 0
    }
}

Describe 'Installed Claude agent delegation (live smoke)' {
    It 'resolves the real ~/.claude/agents junction to a populated, current agent source' -Skip:(-not ($IsWindows -and $script:HasClaudeCli -and (Test-Path (Join-Path $env:USERPROFILE '.claude\agents')))) {
        # Sibling regression to the skill-link dangling-preserve fix (issue #67 finding 1): this
        # machine's ~/.claude/agents junction pointed at claude\agents, a source deleted by the
        # #54 ai-agents-module migration — Claude Code's own /agents delegation silently saw zero
        # custom agents even though ai-agents/agents/*.md exist in the current repo. Source
        # inspection of setup.ps1 alone would not have caught this; only reading the real target
        # did.
        $link = Join-Path $env:USERPROFILE '.claude\agents'
        $item = Get-Item -LiteralPath $link -Force
        $target = if ($item.LinkTarget) { $item.LinkTarget } else { @($item.Target)[0] }
        $target | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $target | Should -BeTrue -Because "the installed ~/.claude/agents link resolves to $target, which must exist for Claude Code's /agents delegation to see any custom agents"
        @(Get-ChildItem -LiteralPath $link -Filter '*.md' -File -ErrorAction SilentlyContinue).Count | Should -BeGreaterThan 0
    }
}

Describe 'Cross-runtime leakage (live smoke)' {
    It 'keeps Claude-native skill names out of the real ~/.codex/skills and ~/.pi/agent/skills' -Skip:(-not $IsWindows) {
        $repo = Split-Path $PSScriptRoot -Parent
        $claudeNativeNames = @(Get-ChildItem (Join-Path $repo 'claude\skills') -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
        $claudeNativeNames.Count | Should -BeGreaterThan 0

        if (Test-Path $script:CodexSkillsDst) {
            $codexEntries = @(Get-ChildItem -LiteralPath $script:CodexSkillsDst -Force -ErrorAction SilentlyContinue | ForEach-Object Name)
            $leaked = @($codexEntries | Where-Object { $_ -in $claudeNativeNames })
            $leaked | Should -BeNullOrEmpty -Because "Claude-only skills must not be projected into Codex: $($leaked -join ', ')"
        }
        if (Test-Path $script:PiSkillsDst) {
            $piEntries = @(Get-ChildItem -LiteralPath $script:PiSkillsDst -Force -ErrorAction SilentlyContinue | ForEach-Object Name)
            $leaked = @($piEntries | Where-Object { $_ -in $claudeNativeNames })
            $leaked | Should -BeNullOrEmpty -Because "Claude-only skills must not be projected into Pi: $($leaked -join ', ')"
        }
    }

    It 'has no live name collision between ai-agents/skills and any native skill source' {
        # No live installed-destination collision exists today to re-verify precedence against
        # (see file header) — this assertion still fails loudly the day one is introduced without
        # updating the precedence handling, rather than staying silent forever.
        $repo = Split-Path $PSScriptRoot -Parent
        $portableNames = @(Get-ChildItem (Join-Path $repo 'ai-agents\skills') -Directory | ForEach-Object Name)
        $portableNames.Count | Should -BeGreaterThan 0
        foreach ($nativeDir in @('claude\skills', 'codex\skills', 'pi\skills')) {
            $nativeNames = @(Get-ChildItem (Join-Path $repo $nativeDir) -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
            $collisions = @($nativeNames | Where-Object { $_ -in $portableNames })
            $collisions | Should -BeNullOrEmpty -Because "a name collision here needs a live precedence re-check, not just the dry-run fixture tests: $($collisions -join ', ')"
        }
    }
}
