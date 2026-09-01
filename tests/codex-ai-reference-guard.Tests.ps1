#Requires -Version 7
# Behavioural tests for codex/ai-reference-guard.sh — the Codex CLI PreToolUse hook that
# hard-blocks AI/Claude/Codex/Copilot/co-authored-by references from reaching a commit,
# PR, or Azure Boards item (issue #219, layer 4). Structured like
# codex-git-guardrails.Tests.ps1: drives the script directly with the hook's stdin JSON
# payload shape ({"tool_input":{"command":"..."}}), no live Codex CLI dependency.
#
# The script resolves its wordlist as a sibling file next to itself (mirroring the real
# ~/.codex/ai-reference-guard.sh + ~/.codex/banned-ai-terms.txt runtime layout), so these
# tests stage the script and the real wordlist (ai-agents/_shared/banned-ai-terms.txt)
# together in a temp dir rather than running the script from its repo location directly.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')

    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:SourceScript = Join-Path $script:RepoRoot 'codex/ai-reference-guard.sh'
    $script:SourceWordlist = Join-Path $script:RepoRoot 'ai-agents/_shared/banned-ai-terms.txt'
    $script:Bash = Resolve-TestBash
    if (-not $script:Bash) {
        throw 'codex-ai-reference-guard.Tests.ps1: no usable bash found, WSL launchers excluded — install Git for Windows'
    }

    # Staged dir mirrors the real runtime layout: script + wordlist as siblings.
    $script:StagedDir = Join-Path ([System.IO.Path]::GetTempPath()) "codex-ai-reference-guard-$PID"
    New-Item -ItemType Directory -Path $script:StagedDir -Force | Out-Null
    Copy-Item -LiteralPath $script:SourceScript -Destination (Join-Path $script:StagedDir 'ai-reference-guard.sh') -Force
    Copy-Item -LiteralPath $script:SourceWordlist -Destination (Join-Path $script:StagedDir 'banned-ai-terms.txt') -Force
    $script:HookScript = Join-Path $script:StagedDir 'ai-reference-guard.sh'

    # Separate staged dir with the script but no sibling wordlist, for the fail-closed case.
    $script:NoWordlistDir = Join-Path ([System.IO.Path]::GetTempPath()) "codex-ai-reference-guard-nowordlist-$PID"
    New-Item -ItemType Directory -Path $script:NoWordlistDir -Force | Out-Null
    Copy-Item -LiteralPath $script:SourceScript -Destination (Join-Path $script:NoWordlistDir 'ai-reference-guard.sh') -Force
    $script:NoWordlistHookScript = Join-Path $script:NoWordlistDir 'ai-reference-guard.sh'

    function Invoke-GuardrailHook {
        param([string] $Command, [string] $Script = $script:HookScript)
        $payload = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        $output = $payload | & $script:Bash $Script 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }

    function Invoke-GuardrailHookRawPayload {
        param([string] $Payload, [string] $Script = $script:HookScript)
        $output = $Payload | & $script:Bash $Script 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }

    # Stub bin dir prepended to PATH so both python3 and python fail deterministically,
    # forcing the hook into its grep/sed fallback tier regardless of the host's real Python.
    $script:NoPythonStubDir = Join-Path ([System.IO.Path]::GetTempPath()) "codex-ai-reference-guard-nopython-$PID"
    New-Item -ItemType Directory -Path $script:NoPythonStubDir -Force | Out-Null
    foreach ($stubName in @('python3', 'python')) {
        $stubPath = Join-Path $script:NoPythonStubDir $stubName
        Set-Content -Path $stubPath -Value "#!/bin/bash`nexit 1`n" -NoNewline
        & $script:Bash -c 'chmod +x "$1"' _ ($stubPath -replace '\\', '/')
    }

    # `PATH='<windows-style path>':"$PATH"` does NOT shadow anything in Git Bash: a raw
    # `C:\...` path contains its own `:` (after the drive letter), which the colon-split
    # PATH parser treats as a separate, bogus entry, so the real python3/python stay
    # resolvable. Convert the stub dir to Git Bash's own POSIX path form (cygpath -u,
    # e.g. `/c/Users/...`) first — verified empirically that only the POSIX form actually
    # shadows `command -v python3`/`python` in this environment.
    $script:NoPythonStubDirPosix = (& $script:Bash -c 'cygpath -u "$1"' _ $script:NoPythonStubDir).Trim()

    function Invoke-GuardrailHookNoPython {
        param([string] $Command)
        $payload = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        $output = $payload | & $script:Bash -c "PATH='$($script:NoPythonStubDirPosix)':`"`$PATH`" bash '$($script:HookScript)'" 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }
}

AfterAll {
    foreach ($dir in @($script:StagedDir, $script:NoWordlistDir, $script:NoPythonStubDir)) {
        if ($dir -and (Test-Path -LiteralPath $dir)) {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Ignore
        }
    }
}

Describe 'codex/ai-reference-guard.sh' {
    Context 'git commit' {
        It 'blocks git commit with a banned term' {
            $result = Invoke-GuardrailHook -Command 'git commit -m "fix bug, thanks Claude"'
            $result.ExitCode | Should -Be 2
            $result.Output | Should -Match 'BLOCKED'
        }

        It 'allows git commit without a banned term' {
            $result = Invoke-GuardrailHook -Command 'git commit -m "fix bug"'
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'gh pr create / gh pr edit' {
        It 'blocks gh pr create with a Co-Authored-By trailer' {
            $result = Invoke-GuardrailHook -Command 'gh pr create --title "x" --body "Co-Authored-By: Claude <noreply@anthropic.com>"'
            $result.ExitCode | Should -Be 2
        }

        It 'allows gh pr create without a banned term' {
            $result = Invoke-GuardrailHook -Command 'gh pr create --title "x" --body "fixes the bug"'
            $result.ExitCode | Should -Be 0
        }

        It 'blocks gh pr edit with a banned term' {
            $result = Invoke-GuardrailHook -Command 'gh pr edit 42 --body "reviewed with Codex"'
            $result.ExitCode | Should -Be 2
        }

        It 'allows gh pr edit without a banned term' {
            $result = Invoke-GuardrailHook -Command 'gh pr edit 42 --body "addresses review comments"'
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'az repos pr create / az repos pr update' {
        It 'blocks az repos pr create with a banned term' {
            $result = Invoke-GuardrailHook -Command 'az repos pr create --title "x" --description "built by Anthropic"'
            $result.ExitCode | Should -Be 2
        }

        It 'allows az repos pr create without a banned term' {
            $result = Invoke-GuardrailHook -Command 'az repos pr create --title "x" --description "fixes bug"'
            $result.ExitCode | Should -Be 0
        }

        It 'blocks az repos pr update with a banned term' {
            $result = Invoke-GuardrailHook -Command 'az repos pr update --id 1 --description "drafted by Claude"'
            $result.ExitCode | Should -Be 2
        }

        It 'allows az repos pr update without a banned term' {
            $result = Invoke-GuardrailHook -Command 'az repos pr update --id 1 --description "fixes bug"'
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'az boards' {
        It 'blocks az boards work-item update with a banned term' {
            $result = Invoke-GuardrailHook -Command 'az boards work-item update --id 1 --fields "System.Description=drafted by Claude"'
            $result.ExitCode | Should -Be 2
        }

        It 'allows az boards work-item update without a banned term' {
            $result = Invoke-GuardrailHook -Command 'az boards work-item update --id 1 --fields "System.Description=fixes bug"'
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'az devops invoke' {
        It 'blocks az devops invoke with a banned term' {
            # The wordlist scan is scoped to message-bearing argument VALUES (finding 1),
            # not the whole command, so the banned term must sit in a scanned flag's
            # value (--route-parameters here) rather than a trailing shell comment —
            # a comment is never sent anywhere by the command itself.
            $result = Invoke-GuardrailHook -Command 'az devops invoke --area wit --resource workitems --route-parameters "comment=Co-Authored-By: Claude" --http-method PATCH --in-file body.json'
            $result.ExitCode | Should -Be 2
        }

        It 'allows az devops invoke without a banned term' {
            $result = Invoke-GuardrailHook -Command 'az devops invoke --area wit --resource workitems --route-parameters id=1 --http-method PATCH --in-file body.json'
            $result.ExitCode | Should -Be 0
        }
    }

    Context '--no-verify / -n bypass (unconditional, no wordlist match required)' {
        It 'blocks git commit --no-verify' {
            $result = Invoke-GuardrailHook -Command 'git commit -m "fix bug" --no-verify'
            $result.ExitCode | Should -Be 2
            $result.Output | Should -Match 'BLOCKED'
        }

        It 'blocks git commit -n' {
            $result = Invoke-GuardrailHook -Command 'git commit -m "fix bug" -n'
            $result.ExitCode | Should -Be 2
        }

        It 'blocks git push --no-verify' {
            $result = Invoke-GuardrailHook -Command 'git push --no-verify origin main'
            $result.ExitCode | Should -Be 2
        }

        It 'allows git commit without --no-verify or -n' {
            $result = Invoke-GuardrailHook -Command 'git commit -m "fix bug"'
            $result.ExitCode | Should -Be 0
        }

        It 'allows git push without --no-verify' {
            $result = Invoke-GuardrailHook -Command 'git push origin main'
            $result.ExitCode | Should -Be 0
        }

        It 'allows a chained command where -n belongs to a different subcommand, not commit' {
            $result = Invoke-GuardrailHook -Command 'git commit -m "fix bug" && git log -n 1'
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'prose mentioning a banned term in an unrelated command' {
        It 'allows a non-commit/PR/board command that merely mentions Claude' {
            $result = Invoke-GuardrailHook -Command 'echo "ask claude about this later"'
            $result.ExitCode | Should -Be 0
        }

        It 'allows git status even when it mentions a banned term' {
            $result = Invoke-GuardrailHook -Command 'git status # asked Claude for help understanding this'
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'missing wordlist (fail closed)' {
        It 'blocks with exit 2 when the sibling wordlist file is missing' {
            $payload = @{ tool_input = @{ command = 'git commit -m "fix bug"' } } | ConvertTo-Json -Compress
            $output = $payload | & $script:Bash $script:NoWordlistHookScript 2>&1
            $LASTEXITCODE | Should -Be 2
            ($output -join "`n") | Should -Match 'BLOCKED'
        }
    }

    Context 'malformed / empty payload (fail open)' {
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
    }

    Context 'grep/sed fallback tier (python unavailable)' {
        It 'blocks git commit with a banned term via the fallback extraction' {
            $result = Invoke-GuardrailHookNoPython -Command 'git commit -m "fix bug, thanks Claude"'
            $result.ExitCode | Should -Be 2
        }

        It 'allows git commit without a banned term via the fallback extraction' {
            $result = Invoke-GuardrailHookNoPython -Command 'git commit -m "fix bug"'
            $result.ExitCode | Should -Be 0
        }

        It 'blocks git commit --no-verify via the fallback extraction' {
            $result = Invoke-GuardrailHookNoPython -Command 'git commit -m "fix bug" --no-verify'
            $result.ExitCode | Should -Be 2
        }

        It 'proves the PATH stub actually shadows python3/python (sanity check for the tier below)' {
            # If this ever stops holding (e.g. the stub-shadow trick breaks again on a
            # different host), the two tests below would silently pass via the real
            # python tier instead of the grep/sed fallback they are named for.
            $probe = "PATH='$($script:NoPythonStubDirPosix)':`"`$PATH`" bash -c 'command -v python3; command -v python'"
            $resolved = & $script:Bash -c $probe 2>&1
            $resolved | Should -Match ([regex]::Escape($script:NoPythonStubDirPosix))
            $resolved | Should -Not -Match 'WindowsApps|Python3\d\d'
        }

        # Finding 3 regression: the fallback tier's naive `[^"]*`-based JSON "command"
        # extraction stopped at the FIRST literal `"` — including one that is only a
        # JSON-escaped `\"` inside the bash command's own double-quoted -m message — so
        # a message with an internal escaped quote was silently truncated before the
        # banned term, and the scan passed even though the term was present. Bypasses
        # Invoke-GuardrailHookNoPython's JSON-building `ConvertTo-Json` (which would
        # re-encode away the exact escaping shape under test) and drives the fallback
        # tier with a literal, hand-built JSON payload instead, so this test is robust
        # regardless of whether the PATH-shadow trick above holds on a given host.
        It 'blocks (via the fallback tier) a double-quoted -m message with an internal escaped quote and a banned term' {
            $rawPayload = '{"tool_input":{"command":"git commit -m \"she said \\\"hi\\\" and thanks Claude\""}}'
            $probeCommand = "PATH='$($script:NoPythonStubDirPosix)':`"`$PATH`" bash '$($script:HookScript)'"
            $output = $rawPayload | & $script:Bash -c $probeCommand 2>&1
            $LASTEXITCODE | Should -Be 2
            ($output -join "`n") | Should -Match 'BLOCKED'
        }
    }

    Context 'wordlist scan scoped to message-bearing argument values (finding 1)' {
        It 'allows staging/committing this very script without self-blocking on the path' {
            # `\bCodex\b` (word-boundary bounded) matches the literal word inside the
            # path segment `codex/ai-reference-guard.sh` when the wordlist is scanned
            # against the whole command instead of just the -m content.
            $result = Invoke-GuardrailHook -Command 'git add codex/ai-reference-guard.sh && git commit -m "clean message"'
            $result.ExitCode | Should -Be 0
        }

        It 'allows staging/committing claude/settings.json without self-blocking on the path' {
            $result = Invoke-GuardrailHook -Command 'git add claude/settings.json && git commit -m "clean message"'
            $result.ExitCode | Should -Be 0
        }

        It 'still blocks a genuinely banned term inside the actual -m content alongside a clean path' {
            $result = Invoke-GuardrailHook -Command 'git add codex/ai-reference-guard.sh && git commit -m "thanks Claude for the help"'
            $result.ExitCode | Should -Be 2
        }

        It 'still blocks a banned term inside az boards --fields value content' {
            $result = Invoke-GuardrailHook -Command 'az boards work-item update --id 1 --fields "System.Description=drafted by Claude"'
            $result.ExitCode | Should -Be 2
        }

        It 'still blocks a banned term inside az devops invoke --route-parameters value content' {
            $result = Invoke-GuardrailHook -Command 'az devops invoke --area wit --resource workitems --route-parameters "comment=thanks Claude" --http-method PATCH --in-file body.json'
            $result.ExitCode | Should -Be 2
        }
    }
}
