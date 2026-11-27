#Requires -Version 7
# Behavioural tests for claude/block-destructive-vcs.ps1 — the PreToolUse deny hook that
# deterministically blocks destructive git commands. Drives the real hook with tool-call
# JSON on stdin (exactly as Claude Code does) and asserts on the emitted decision.
#
# The hook's documented properties this suite pins:
#   - canonical destructive forms are denied (push --force, reset --hard, clean -f/-fd, branch -D,
#     checkout ., restore .)
#   - safe siblings are allowed (--force-with-lease, --force-if-includes, branch -d,
#     restore --staged ., checkout of a named path or branch)
#   - a destructive phrase QUOTED in a commit message must not false-deny (quoted-substring scrub)
#   - an escaped-quote message must not get mangled into a false deny
#   - a quoted flag (git push "--force") must NOT bypass the deny — the shell expands it identically
#   - non-git commands pass through; malformed/empty stdin fails open
#   - a deny reason includes the raw command as `! <command>`, so it can be handed back for
#     the user to copy and run themselves via Claude Code's `!` shell passthrough

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $script:RepoRoot 'claude/block-destructive-vcs.ps1'

    # Drives the hook with a raw stdin payload (string). Returns stdout as one string.
    function Invoke-Hook
    {
        param([string] $Payload)
        return ($Payload | & pwsh -NoProfile -File $script:Hook 2>&1 | Out-String)
    }

    # Convenience: wrap a command string as the tool-call JSON the hook parses.
    function Invoke-HookCmd
    {
        param([string] $Command)
        $json = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        return (Invoke-Hook -Payload $json)
    }
}

Describe 'claude/block-destructive-vcs.ps1' {
    Context 'canonical denies' {
        It 'denies <Command>' -TestCases @(
            @{ Command = 'git push --force' }
            @{ Command = 'git push -f origin main' }
            @{ Command = 'git reset --hard HEAD~1' }
            @{ Command = 'git clean -f' }
            @{ Command = 'git clean -fd' }
            @{ Command = 'git branch -D feature' }
            @{ Command = 'git checkout .' }
            @{ Command = 'git checkout -- .' }
            @{ Command = 'git restore .' }
            @{ Command = 'git restore --source=HEAD . && git status' }
        ) {
            param($Command)
            $out = Invoke-HookCmd -Command $Command
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'safe siblings allowed' {
        It 'allows <Command>' -TestCases @(
            @{ Command = 'git push --force-with-lease' }
            @{ Command = 'git push --force-with-lease --force-if-includes' }
            @{ Command = 'git branch -d feature' }
            @{ Command = 'git restore --staged .' }
            @{ Command = 'git checkout ./src/file.ps1' }
            @{ Command = 'git add . && git checkout main' }
            @{ Command = 'git status' }
            @{ Command = 'ls -la' }
            @{ Command = 'grep -R "reset --hard" .' }
        ) {
            param($Command)
            $out = Invoke-HookCmd -Command $Command
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'quoted-message false-deny guards' {
        It 'allows a destructive phrase inside a commit -m message' {
            $out = Invoke-HookCmd -Command 'git commit -m "reset --hard was avoided"'
            $out.Trim() | Should -BeNullOrEmpty
        }

        It 'allows an escaped-quote commit message that embeds a destructive phrase' {
            # The old scrub `"[^"]*"` treats \" as a terminator, mangling this into a bare
            # `reset --hard` and false-denying. An escape-aware scrub keeps it whole.
            $out = Invoke-HookCmd -Command 'git commit -m "say \"reset --hard\" here"'
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'quoted-flag bypass is closed' {
        It 'denies <Command>' -TestCases @(
            @{ Command = 'git push "--force"' }
            @{ Command = 'git reset "--hard" HEAD' }
            @{ Command = 'git clean "-fd"' }
            @{ Command = 'git branch "-D" feature' }
        ) {
            param($Command)
            # A quoted flag expands identically in the shell, so the deny must still fire.
            $out = Invoke-HookCmd -Command $Command
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'deny reason includes the runnable command' {
        It 'includes "! <command>" in the reason for a denied command' {
            $out = Invoke-HookCmd -Command 'git reset --hard HEAD~1'
            $out | Should -Match ([regex]::Escape('! git reset --hard HEAD~1'))
        }
    }

    Context 'refspec force-push and whole-tree discard bypasses are closed' {
        It 'denies <Command>' -TestCases @(
            @{ Command = 'git push origin +main' }
            @{ Command = 'git push origin +HEAD:main' }
            @{ Command = 'git push origin "+main"' }
            @{ Command = 'git restore .' }
            @{ Command = 'git restore -- .' }
            @{ Command = 'git restore --staged --worktree .' }
            @{ Command = 'git checkout -- .' }
            @{ Command = 'git checkout .' }
            @{ Command = 'git checkout HEAD -- .' }
            @{ Command = 'git checkout -- "."' }
        ) {
            param($Command)
            $out = Invoke-HookCmd -Command $Command
            $out | Should -Match '"permissionDecision":"deny"'
        }

        It 'allows <Command>' -TestCases @(
            @{ Command = 'git push origin main' }
            @{ Command = 'git stash push -u' }
            @{ Command = 'git restore --staged .' }
            @{ Command = 'git restore file.txt' }
            @{ Command = 'git checkout main' }
            @{ Command = 'git checkout .gitignore' }
            @{ Command = 'git commit -m "+1 restore ."' }
        ) {
            param($Command)
            $out = Invoke-HookCmd -Command $Command
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'shared rules file' {
        BeforeAll {
            $script:SharedRules = Join-Path $script:RepoRoot 'ai-agents/_shared/destructive-git-rules.json'

            # Installs a copy of the hook in its own directory, optionally with a sibling rules
            # file, mirroring the ~/.claude install layout (script + sibling data file).
            function New-HookCopy
            {
                param([string] $Name, [string] $RulesJson)
                $dir = Join-Path $TestDrive $Name
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Copy-Item -LiteralPath $script:Hook -Destination $dir
                if ($RulesJson)
                {
                    Set-Content -LiteralPath (Join-Path $dir 'destructive-git-rules.json') -Value $RulesJson -NoNewline
                }
                return (Join-Path $dir 'block-destructive-vcs.ps1')
            }

            function Invoke-HookCopy
            {
                param([string] $HookPath, [string] $Command)
                $json = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
                $savedDotfiles = $env:DOTFILES
                $env:DOTFILES = $null
                try
                {
                    return ($json | & pwsh -NoProfile -File $HookPath 2>&1 | Out-String)
                }
                finally
                {
                    $env:DOTFILES = $savedDotfiles
                }
            }
        }

        It 'reads its rules from the shared data file, not a hardcoded list' {
            $rules = @{
                keepQuoted = '^-{1,2}[A-Za-z][A-Za-z-]*$'
                rules = @(@{
                        id = 'fixture'; runtimes = @('claude'); pattern = '\bgit\b[^\n;|&]*\bfixture-marker\b'
                        reason = 'fixture rule fired'
                    })
            } | ConvertTo-Json -Depth 5
            $hookPath = New-HookCopy -Name 'fixture-rules' -RulesJson $rules
            Invoke-HookCopy -HookPath $hookPath -Command 'git fixture-marker' | Should -Match 'fixture rule fired'
            # The fixture omits reset-hard, so the hardcoded-list era behaviour is gone.
            (Invoke-HookCopy -HookPath $hookPath -Command 'git reset --hard').Trim() | Should -BeNullOrEmpty
        }

        It 'skips rules scoped to other runtimes' {
            $rules = @{
                keepQuoted = '^$'
                rules = @(@{ id = 'codex-only'; runtimes = @('codex', 'pi'); pattern = '\bgit\b'; reason = 'x' })
            } | ConvertTo-Json -Depth 5
            $hookPath = New-HookCopy -Name 'other-runtime' -RulesJson $rules
            (Invoke-HookCopy -HookPath $hookPath -Command 'git status').Trim() | Should -BeNullOrEmpty
        }

        It 'fails closed for a git command when the rules file is missing' {
            $hookPath = New-HookCopy -Name 'no-rules'
            $out = Invoke-HookCopy -HookPath $hookPath -Command 'git status'
            $out | Should -Match '"permissionDecision":"deny"'
            $out | Should -Match 'destructive-git-rules\.json'
        }

        It 'still allows a non-git command when the rules file is missing' {
            $hookPath = New-HookCopy -Name 'no-rules-nongit'
            (Invoke-HookCopy -HookPath $hookPath -Command 'ls -la').Trim() | Should -BeNullOrEmpty
        }

        It 'fails closed for a git command when the rules file is malformed' {
            $hookPath = New-HookCopy -Name 'bad-rules' -RulesJson '{not json'
            Invoke-HookCopy -HookPath $hookPath -Command 'git status' | Should -Match '"permissionDecision":"deny"'
        }

        It 'fails closed for a git command when rules is <Case>' -TestCases @(
            @{ Case = 'null'; RulesJson = '{"keepQuoted":"^x$","rules":null}' }
            @{ Case = 'empty'; RulesJson = '{"keepQuoted":"^x$","rules":[]}' }
            @{ Case = 'missing'; RulesJson = '{"keepQuoted":"^x$"}' }
            @{ Case = 'a string'; RulesJson = '{"keepQuoted":"^x$","rules":"oops"}' }
        ) {
            param($Case, $RulesJson)
            $hookPath = New-HookCopy -Name "bad-shape-$($Case -replace ' ', '-')" -RulesJson $RulesJson
            Invoke-HookCopy -HookPath $hookPath -Command 'git push --force origin main' |
                Should -Match '"permissionDecision":"deny"'
        }

        It 'the repository copy of the shared rules file exists and parses' {
            $parsed = Get-Content -LiteralPath $script:SharedRules -Raw | ConvertFrom-Json
            @($parsed.rules).Count | Should -BeGreaterThan 0
        }
    }

    Context 'in-process pwsh-in-bash check (one hook process per Bash call)' {
        It 'denies PowerShell sent to the Bash tool' {
            $json = @{ tool_name = 'Bash'; tool_input = @{ command = 'Get-ChildItem -Path .' } } | ConvertTo-Json -Compress
            Invoke-Hook -Payload $json | Should -Match 'looks like PowerShell'
        }

        It 'does not apply the pwsh-in-bash check to the PowerShell tool' {
            $json = @{ tool_name = 'PowerShell'; tool_input = @{ command = 'Get-ChildItem -Path .' } } | ConvertTo-Json -Compress
            (Invoke-Hook -Payload $json).Trim() | Should -BeNullOrEmpty
        }

        It 'reports the destructive-git deny ahead of the pwsh-in-bash check' {
            $json = @{ tool_name = 'Bash'; tool_input = @{ command = 'git reset --hard; Get-ChildItem' } } | ConvertTo-Json -Compress
            Invoke-Hook -Payload $json | Should -Match 'git reset --hard'
        }
    }

    Context 'fails open' {
        It 'allows on empty stdin' {
            (Invoke-Hook -Payload '').Trim() | Should -BeNullOrEmpty
        }
        It 'allows on malformed JSON' {
            (Invoke-Hook -Payload '{not json').Trim() | Should -BeNullOrEmpty
        }
        It 'allows when command field is absent' {
            (Invoke-Hook -Payload '{"tool_input":{}}').Trim() | Should -BeNullOrEmpty
        }
    }
}
