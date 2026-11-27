#Requires -Version 7
# Behavioural tests for codex/block-dangerous-git.sh — the Codex CLI PreToolUse hook
# (issue #170), which reads ai-agents/_shared/destructive-git-rules.json. Drives the script
# directly with the hook's stdin JSON payload shape ({"tool_input":{"command":"..."}}),
# the same way ctags-hook.Tests.ps1 drives a bash hook script — no live Codex CLI
# dependency, so this covers the script's own logic.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    . (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')

    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:HookScript = Join-Path $script:RepoRoot 'codex/block-dangerous-git.sh'
    $script:Bash = Resolve-TestBash
    if (-not $script:Bash)
    {
        throw 'codex-git-guardrails.Tests.ps1: no usable bash found, WSL launchers excluded — install Git for Windows'
    }

    function Invoke-GuardrailHook
    {
        param([string] $Command)
        $payload = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        $stderr = $null
        $output = $payload | & $script:Bash $script:HookScript 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output = ($output -join "`n")
        }
    }

    function Invoke-GuardrailHookRawPayload
    {
        param([string] $Payload)
        $stderr = $null
        $output = $Payload | & $script:Bash $script:HookScript 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output = ($output -join "`n")
        }
    }

    # Stub bin dir prepended to PATH so both python3 and python fail deterministically,
    # forcing the hook into its grep/sed fallback tier regardless of the host's real Python.
    $script:NoPythonStubDir = Join-Path ([System.IO.Path]::GetTempPath()) "codex-git-guardrails-nopython-$PID"
    New-Item -ItemType Directory -Path $script:NoPythonStubDir -Force | Out-Null
    foreach ($stubName in @('python3', 'python'))
    {
        $stubPath = Join-Path $script:NoPythonStubDir $stubName
        Set-Content -Path $stubPath -Value "#!/bin/bash`nexit 1`n" -NoNewline
        & $script:Bash -c 'chmod +x "$1"' _ ($stubPath -replace '\\', '/')
    }

    function Invoke-GuardrailHookNoPython
    {
        param([string] $Command)
        $payload = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        $stderr = $null
        $output = $payload | & $script:Bash -c "PATH='$($script:NoPythonStubDir)':`"`$PATH`" bash '$($script:HookScript)'" 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output = ($output -join "`n")
        }
    }

    function Invoke-GuardrailHookNoPythonRawPayload
    {
        param([string] $Payload)
        $stderr = $null
        $output = $Payload | & $script:Bash -c "PATH='$($script:NoPythonStubDir)':`"`$PATH`" bash '$($script:HookScript)'" 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output = ($output -join "`n")
        }
    }
}

AfterAll {
    if ($script:NoPythonStubDir -and (Test-Path -LiteralPath $script:NoPythonStubDir))
    {
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

    Context 'refspec force-push and whole-tree discard bypasses' {
        It 'blocks <Command>' -TestCases @(
            @{ Command = 'git push origin +main' }
            @{ Command = 'git restore .' }
            @{ Command = 'git restore -- .' }
            @{ Command = 'git checkout -- .' }
            @{ Command = 'git checkout HEAD -- .' }
            @{ Command = 'git reset "--hard" HEAD' }
        ) {
            param($Command)
            $result = Invoke-GuardrailHook -Command $Command
            $result.ExitCode | Should -Be 2
            $result.Output | Should -Match 'Reason: Blocked'
        }

        It 'allows <Command>' -TestCases @(
            @{ Command = 'git restore --staged .' }
            @{ Command = 'git restore file.txt' }
            @{ Command = 'git checkout main' }
            @{ Command = 'git checkout .gitignore' }
            @{ Command = 'git stash push -u' }
            @{ Command = 'git commit -m "please reset --hard now"' }
        ) {
            param($Command)
            $result = Invoke-GuardrailHook -Command $Command
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'shared rules file' {
        BeforeAll {
            # Copies the hook into its own directory, optionally with a sibling rules file —
            # the ~/.codex install layout (script + sibling data file).
            function New-HookCopy
            {
                param([string] $Name, [string] $RulesJson)
                $dir = Join-Path $TestDrive $Name
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Copy-Item -LiteralPath $script:HookScript -Destination $dir
                if ($RulesJson)
                {
                    Set-Content -LiteralPath (Join-Path $dir 'destructive-git-rules.json') -Value $RulesJson -NoNewline
                }
                return (Join-Path $dir 'block-dangerous-git.sh')
            }

            function Invoke-HookCopy
            {
                param([string] $HookPath, [string] $Command)
                $payload = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
                $output = $payload | & $script:Bash -c 'unset DOTFILES; bash "$1"' _ ($HookPath -replace '\\', '/') 2>&1
                return [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
            }
        }

        It 'reads its rules from the shared data file, not a hardcoded list' {
            $rules = @{
                keepQuoted = '^$'
                rules = @(@{ id = 'fixture'; runtimes = @('codex'); pattern = '\bgit\b[^\n;|&]*\bfixture-marker\b'; reason = 'fixture rule fired' })
            } | ConvertTo-Json -Depth 5
            $hookPath = New-HookCopy -Name 'fixture-rules' -RulesJson $rules
            $hit = Invoke-HookCopy -HookPath $hookPath -Command 'git fixture-marker'
            $hit.ExitCode | Should -Be 2
            $hit.Output | Should -Match 'fixture rule fired'
            (Invoke-HookCopy -HookPath $hookPath -Command 'git push origin main').ExitCode | Should -Be 0
        }

        It 'skips rules scoped to other runtimes' {
            $rules = @{
                keepQuoted = '^$'
                rules = @(@{ id = 'claude-only'; runtimes = @('claude'); pattern = '\bgit\b'; reason = 'x' })
            } | ConvertTo-Json -Depth 5
            $hookPath = New-HookCopy -Name 'other-runtime' -RulesJson $rules
            (Invoke-HookCopy -HookPath $hookPath -Command 'git status').ExitCode | Should -Be 0
        }

        It 'fails closed for a git command when the rules file is missing' {
            $hookPath = New-HookCopy -Name 'no-rules'
            $result = Invoke-HookCopy -HookPath $hookPath -Command 'git status'
            $result.ExitCode | Should -Be 2
            $result.Output | Should -Match 'destructive-git-rules\.json'
        }

        It 'still allows a non-git command when the rules file is missing' {
            $hookPath = New-HookCopy -Name 'no-rules-nongit'
            (Invoke-HookCopy -HookPath $hookPath -Command 'ls -la').ExitCode | Should -Be 0
        }

        It 'fails closed for a git command when the rules file is malformed' {
            $hookPath = New-HookCopy -Name 'bad-rules' -RulesJson '{not json'
            (Invoke-HookCopy -HookPath $hookPath -Command 'git status').ExitCode | Should -Be 2
        }
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
