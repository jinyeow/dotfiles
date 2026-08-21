#Requires -Version 7
# Behavioural tests for claude/block-destructive-vcs.ps1 — the PreToolUse deny hook that
# deterministically blocks destructive git commands. Drives the real hook with tool-call
# JSON on stdin (exactly as Claude Code does) and asserts on the emitted decision.
#
# The hook's documented properties this suite pins:
#   - canonical destructive forms are denied (push --force, reset --hard, clean -f/-fd, branch -D)
#   - safe siblings are allowed (--force-with-lease, --force-if-includes, branch -d)
#   - a destructive phrase QUOTED in a commit message must not false-deny (quoted-substring scrub)
#   - an escaped-quote message must not get mangled into a false deny
#   - a quoted flag (git push "--force") must NOT bypass the deny — the shell expands it identically
#   - non-git commands pass through; malformed/empty stdin fails open
#   - a deny reason includes the raw command as `! <command>`, so it can be handed back for
#     the user to copy and run themselves via Claude Code's `!` shell passthrough

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $script:RepoRoot 'claude/block-destructive-vcs.ps1'

    # Drives the hook with a raw stdin payload (string). Returns stdout as one string.
    function Invoke-Hook {
        param([string] $Payload)
        return ($Payload | & pwsh -NoProfile -File $script:Hook 2>&1 | Out-String)
    }

    # Convenience: wrap a command string as the tool-call JSON the hook parses.
    function Invoke-HookCmd {
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
