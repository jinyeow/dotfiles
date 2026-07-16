#Requires -Version 7
# Behavioural tests for claude/warn-reasoning-extraction.ps1 — the UserPromptSubmit +
# PreToolUse(Edit|Write) hook that flags reasoning-extraction phrasing (lever 5). Drives the
# real hook with hook JSON on stdin and asserts on the emitted output.
#
# Properties pinned here:
#   - a bare phrase on UserPromptSubmit emits additionalContext
#   - a phrase QUOTED in prose (docs banning it) does not fire (quoted-substring scrub)
#   - a negation-guarded phrase ("never explain ...") does not fire
#   - an ESCAPED-quote phrase does not false-trigger (escape-aware double-quote scrub)

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $script:RepoRoot 'claude/warn-reasoning-extraction.ps1'

    function Invoke-Hook {
        param([string] $Payload)
        return ($Payload | & pwsh -NoProfile -File $script:Hook 2>&1 | Out-String)
    }
    function Invoke-Prompt {
        param([string] $Prompt)
        $json = @{ hook_event_name = 'UserPromptSubmit'; prompt = $Prompt } | ConvertTo-Json -Compress
        return (Invoke-Hook -Payload $json)
    }
}

Describe 'claude/warn-reasoning-extraction.ps1 (UserPromptSubmit)' {
    It 'warns on a bare reasoning-extraction phrase' {
        $out = Invoke-Prompt -Prompt 'Please explain your reasoning step by step for this fix.'
        $out | Should -Match 'reasoning_extraction'
    }

    It 'does not warn when the phrase is quoted in prose (banning it)' {
        # Docs that quote the phrase to describe or forbid it must not self-trigger.
        $out = Invoke-Prompt -Prompt 'Do not use "explain your reasoning step by step" in prompts.'
        $out.Trim() | Should -BeNullOrEmpty
    }

    It 'does not warn on a negation-guarded phrase' {
        $out = Invoke-Prompt -Prompt 'never explain your reasoning step by step to the user'
        $out.Trim() | Should -BeNullOrEmpty
    }

    It 'does not false-trigger on a phrase inside an escaped-quote string' {
        # A quoted string that itself contains an escaped-quoted phrase. The old scrub
        # `"[^"]*"` terminates at the first \" and re-exposes the phrase, false-firing; the
        # escape-aware scrub `"(?:\\.|[^"\\])*"` consumes the whole string so it stays hidden.
        $out = Invoke-Prompt -Prompt 'Consider "the note \"explain your reasoning step by step\" here" carefully.'
        $out.Trim() | Should -BeNullOrEmpty
    }

    It 'no-ops on empty stdin' {
        (Invoke-Hook -Payload '').Trim() | Should -BeNullOrEmpty
    }
}
