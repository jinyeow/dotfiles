#Requires -Version 7
# Behavioural tests for claude/no-claude-session-trailer.sh — the PreToolUse(Bash|PowerShell)
# deny hook that blocks a `git commit` carrying the `Claude-Session:` trailer. It is a bash
# script (jq + grep), so the tests drive it through `bash` with tool-call JSON on stdin.
#
# The suite needs bash + jq (as the hook does); it skips rather than false-green when absent.

$script:HasBash = [bool](Get-Command bash -ErrorAction SilentlyContinue) -and
    [bool](Get-Command jq -ErrorAction SilentlyContinue)

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $script:RepoRoot 'claude/no-claude-session-trailer.sh'

    # Drive the bash hook with a command string wrapped as the tool-call JSON on stdin.
    function Invoke-Hook {
        param([string] $Command)
        $json = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        return ($json | & bash $script:Hook 2>&1 | Out-String)
    }
}

Describe 'claude/no-claude-session-trailer.sh' -Skip:(-not $script:HasBash) {
    Context 'denies a git commit carrying the trailer' {
        It 'denies a plain commit with the trailer' {
            $out = Invoke-Hook -Command "git commit -m `"msg`n`nClaude-Session: https://x`""
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `git -C <path> commit` with the trailer' {
            # The old flag group matched only flag WORDS, so a global flag with an argument
            # (-C <path>) slipped between git and commit and evaded the deny.
            $out = Invoke-Hook -Command "git -C /tmp/x commit -m `"Claude-Session: https://x`""
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `git -c k=v commit` with the trailer' {
            $out = Invoke-Hook -Command "git -c user.name=x commit -m `"Claude-Session: y`""
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'allows otherwise' {
        It 'allows a commit without the trailer' {
            $out = Invoke-Hook -Command 'git commit -m "a normal message"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows `git -C <path> commit` without the trailer' {
            $out = Invoke-Hook -Command 'git -C /tmp/x commit -m "normal"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows a non-commit command that merely mentions the string' {
            $out = Invoke-Hook -Command 'echo Claude-Session: url'
            $out.Trim() | Should -BeNullOrEmpty
        }
    }
}
