#Requires -Version 7
# Behavioural tests for claude/lint-powershell.ps1 — the PostToolUse hook that lints an
# edited PowerShell file and feeds violations back as `additionalContext`.
#
# What matters here is RULESET DISCOVERY. The hook is only useful if it lints with the
# same ruleset CI uses; when it falls back to PSSA defaults it reports rules the repo
# deliberately excludes, and every one of those is a false positive the agent then
# "fixes". So each test drives the real hook over a throwaway tree and asserts on what
# the hook emits, not on how it searched.
#
# Needs PSScriptAnalyzer (the hook no-ops without it), so the suite skips rather than
# false-green. Computed at DISCOVERY time — Describe's -Skip: is evaluated then, so this
# cannot live in BeforeAll (which runs later, leaving the flag unset and silently
# skipping every test).
$script:HasPSSA = [bool](Get-Module -ListAvailable -Name PSScriptAnalyzer)

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $script:RepoRoot 'claude/lint-powershell.ps1'

    # A ruleset excluding exactly the rule the fixture script trips. Purpose-built rather
    # than a copy of the repo's own: the contract under test is "did the hook find and
    # apply the nearest settings file", not which rules this repo happens to exclude.
    $script:Settings = "@{ Severity = @('Error','Warning'); ExcludeRules = @('PSAvoidUsingWriteHost') }"

    # Builds <Root>/sub/edited.ps1, which trips PSAvoidUsingWriteHost. Returns its path.
    # Dropping a ruleset is Add-Ruleset's job, deliberately kept separate: a $SettingsDir
    # parameter here would bind $null to '' and silently place the ruleset at the root,
    # turning the no-ruleset case into a root-ruleset case.
    function New-LintTree {
        param([string] $Root)

        $sub = Join-Path $Root 'sub'
        New-Item -ItemType Directory -Path $sub -Force | Out-Null

        $edited = Join-Path $sub 'edited.ps1'
        Set-Content -LiteralPath $edited -Value "Write-Host 'hi'" -Encoding UTF8
        return $edited
    }

    function Add-Ruleset {
        param([string] $Dir)

        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $Dir 'PSScriptAnalyzerSettings.psd1') `
            -Value $script:Settings -Encoding UTF8
    }

    # Drives the hook exactly as Claude Code does: tool-call JSON on stdin.
    function Invoke-LintHook {
        param([string] $FilePath)
        $json = @{ tool_input = @{ file_path = $FilePath } } | ConvertTo-Json -Compress
        return ($json | & pwsh -NoProfile -File $script:Hook 2>&1 | Out-String)
    }

    function New-TempRoot {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('lintbook-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        return $root
    }
}

Describe 'claude/lint-powershell.ps1 ruleset discovery' -Skip:(-not $script:HasPSSA) {
    It 'reports a violation when no ruleset is present' {
        # Guards the other two tests from passing for the wrong reason: proves the fixture
        # really does trip a rule, so silence below means "ruleset applied", not "hook
        # never ran". Without this an inert hook would green the whole suite.
        $root = New-TempRoot
        try {
            $edited = New-LintTree -Root $root
            $out = Invoke-LintHook -FilePath $edited

            $out | Should -Match 'PSAvoidUsingWriteHost' -Because 'PSSA defaults flag Write-Host, so the fixture is a real violation'
        } finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'honours a ruleset in .vscode/' {
        $root = New-TempRoot
        try {
            $edited = New-LintTree -Root $root
            Add-Ruleset -Dir (Join-Path $root '.vscode')
            $out = Invoke-LintHook -FilePath $edited

            $out.Trim() | Should -BeNullOrEmpty -Because 'the ruleset excludes the only rule the fixture trips'
        } finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'honours a ruleset at the project root' {
        # THE BUG: this repo keeps PSScriptAnalyzerSettings.psd1 at the root — that is the
        # file CI passes (ci.yml: -Settings ./PSScriptAnalyzerSettings.psd1). The hook only
        # ever looked for `.vscode/PSScriptAnalyzerSettings.psd1`, so it silently linted
        # with defaults and false-flagged rules this repo excludes (Write-Host on
        # git/work-hooks/policy.ps1 was the recurring one).
        $root = New-TempRoot
        try {
            $edited = New-LintTree -Root $root
            Add-Ruleset -Dir $root
            $out = Invoke-LintHook -FilePath $edited

            $out.Trim() | Should -BeNullOrEmpty -Because 'a root ruleset is what CI uses and the hook must match it'
        } finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
