#Requires -Version 7
# Behavioural tests for codex/block-dangerous-git.sh — the Codex CLI PreToolUse hook
# ported from claude/skills/git-guardrails-claude-code/scripts/block-dangerous-git.sh
# (issue #170). Drives the script directly with the hook's stdin JSON payload shape
# ({"tool_input":{"command":"..."}}), the same way ctags-hook.Tests.ps1 drives a bash
# hook script — no live Codex CLI dependency, so this covers the script's own logic.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')

    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:HookScript = Join-Path $script:RepoRoot 'codex/block-dangerous-git.sh'
    $script:Bash = Resolve-TestBash
    if (-not $script:Bash) {
        throw 'codex-git-guardrails.Tests.ps1: no usable bash found, WSL launchers excluded — install Git for Windows'
    }

    function Invoke-GuardrailHook {
        param([string] $Command)
        $payload = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        $stderr = $null
        $output = $payload | & $script:Bash $script:HookScript 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }
}

Describe 'codex/block-dangerous-git.sh' {
    It 'blocks git push' {
        $result = Invoke-GuardrailHook -Command 'git push origin main'
        $result.ExitCode | Should -Be 2
        $result.Output | Should -Match 'BLOCKED'
    }

    It 'blocks git push --force' {
        $result = Invoke-GuardrailHook -Command 'git push --force origin main'
        $result.ExitCode | Should -Be 2
    }

    It 'blocks git reset --hard' {
        $result = Invoke-GuardrailHook -Command 'git reset --hard HEAD~1'
        $result.ExitCode | Should -Be 2
    }

    It 'blocks git clean -fd' {
        $result = Invoke-GuardrailHook -Command 'git clean -fd'
        $result.ExitCode | Should -Be 2
    }

    It 'blocks git branch -D' {
        $result = Invoke-GuardrailHook -Command 'git branch -D feature/old'
        $result.ExitCode | Should -Be 2
    }

    It 'blocks git checkout .' {
        $result = Invoke-GuardrailHook -Command 'git checkout .'
        $result.ExitCode | Should -Be 2
    }

    It 'blocks git restore .' {
        $result = Invoke-GuardrailHook -Command 'git restore .'
        $result.ExitCode | Should -Be 2
    }

    It 'allows git status' {
        $result = Invoke-GuardrailHook -Command 'git status'
        $result.ExitCode | Should -Be 0
    }

    It 'allows git log' {
        $result = Invoke-GuardrailHook -Command 'git log --oneline'
        $result.ExitCode | Should -Be 0
    }
}
