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

    function Invoke-GuardrailHookRawPayload {
        param([string] $Payload)
        $stderr = $null
        $output = $Payload | & $script:Bash $script:HookScript 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }

    # Stub bin dir prepended to PATH so both python3 and python fail deterministically,
    # forcing the hook into its grep/sed fallback tier regardless of the host's real Python.
    $script:NoPythonStubDir = Join-Path ([System.IO.Path]::GetTempPath()) "codex-git-guardrails-nopython-$PID"
    New-Item -ItemType Directory -Path $script:NoPythonStubDir -Force | Out-Null
    foreach ($stubName in @('python3', 'python')) {
        $stubPath = Join-Path $script:NoPythonStubDir $stubName
        Set-Content -Path $stubPath -Value "#!/bin/bash`nexit 1`n" -NoNewline
        & $script:Bash -c 'chmod +x "$1"' _ ($stubPath -replace '\\', '/')
    }

    function Invoke-GuardrailHookNoPython {
        param([string] $Command)
        $payload = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        $stderr = $null
        $output = $payload | & $script:Bash -c "PATH='$($script:NoPythonStubDir)':`"`$PATH`" '$($script:HookScript)'" 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }

    function Invoke-GuardrailHookNoPythonRawPayload {
        param([string] $Payload)
        $stderr = $null
        $output = $Payload | & $script:Bash -c "PATH='$($script:NoPythonStubDir)':`"`$PATH`" '$($script:HookScript)'" 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }
}

AfterAll {
    if ($script:NoPythonStubDir -and (Test-Path -LiteralPath $script:NoPythonStubDir)) {
        Remove-Item -LiteralPath $script:NoPythonStubDir -Recurse -Force -ErrorAction Ignore
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

    It 'allows an empty payload object' {
        $result = Invoke-GuardrailHookRawPayload -Payload '{}'
        $result.ExitCode | Should -Be 0
    }

    It 'allows a payload with tool_input but no command' {
        $result = Invoke-GuardrailHookRawPayload -Payload '{"tool_input":{}}'
        $result.ExitCode | Should -Be 0
    }

    It 'allows unparseable, non-JSON input' {
        $result = Invoke-GuardrailHookRawPayload -Payload 'not json at all'
        $result.ExitCode | Should -Be 0
    }

    Context 'grep/sed fallback tier (python unavailable)' {
        It 'blocks git push via the fallback extraction' {
            $result = Invoke-GuardrailHookNoPython -Command 'git push origin main'
            $result.ExitCode | Should -Be 2
        }

        It 'allows git status via the fallback extraction' {
            $result = Invoke-GuardrailHookNoPython -Command 'git status'
            $result.ExitCode | Should -Be 0
        }

        It 'allows a command-less payload via the fallback extraction' {
            $result = Invoke-GuardrailHookNoPythonRawPayload -Payload '{"tool_input":{}}'
            $result.ExitCode | Should -Be 0
        }
    }
}
