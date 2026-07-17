#Requires -Version 7
# Behavioural tests for claude/warn-hardcoded-secrets.ps1 — the PostToolUse(Edit|Write) hook
# that warns (via additionalContext) when written content looks like a hardcoded secret.
# Drives the real hook with tool-call JSON on stdin and asserts on the emitted context.
#
# Key properties pinned here:
#   - a real-looking assigned secret warns
#   - a private-key block warns
#   - quoted PLACEHOLDER values ($env:, ${{ secrets }}, {{ vault }}) do NOT warn
#   - the output reports rule NAMES only, never the matched secret value

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Hook = Join-Path $script:RepoRoot 'claude/warn-hardcoded-secrets.ps1'

    function Invoke-Hook {
        param([string] $Payload)
        return ($Payload | & pwsh -NoProfile -File $script:Hook 2>&1 | Out-String)
    }
    # Written content (Write tool shape) wrapped as tool-call JSON.
    function Invoke-HookContent {
        param([string] $Content, [string] $FilePath = 'config.txt')
        $json = @{ tool_input = @{ file_path = $FilePath; content = $Content } } | ConvertTo-Json -Compress
        return (Invoke-Hook -Payload $json)
    }
}

Describe 'claude/warn-hardcoded-secrets.ps1' {
    Context 'warns on real secrets' {
        It 'warns on an assigned api key' {
            $out = Invoke-HookContent -Content 'api_key = "sk-abcdef123456789"'
            $out | Should -Match 'assigned credential'
        }
        It 'warns on a bare .env-style secret token' {
            $out = Invoke-HookContent -Content 'SECRET=sk-live-abc123def456ghi'
            $out | Should -Match 'assigned credential'
        }
        It 'warns on a private key block' {
            $out = Invoke-HookContent -Content "-----BEGIN RSA PRIVATE KEY-----`nMIIabc`n-----END RSA PRIVATE KEY-----"
            $out | Should -Match 'private key block'
        }
    }

    Context 'placeholders do NOT warn' {
        It 'does not warn on <Content>' -TestCases @(
            @{ Content = 'token: "${{ secrets.GITHUB_TOKEN }}"' }
            @{ Content = 'password: "$env:DB_PASS"' }
            @{ Content = 'api_key: "{{ vault }}"' }
        ) {
            param($Content)
            # The quoted-value branch must mirror the bare branch's `$`/`{` exclusion so a
            # templated placeholder is not flagged as a hardcoded secret.
            $out = Invoke-HookContent -Content $Content
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'never leaks the value' {
        It 'reports rule names only, not the matched secret' {
            $secret = 'sk-supersecret-value-99887766'
            $out = Invoke-HookContent -Content "token = `"$secret`""
            $out | Should -Match 'assigned credential'
            $out | Should -Not -Match ([regex]::Escape($secret))
        }
    }

    Context 'fails open' {
        It 'no-ops on empty stdin' {
            (Invoke-Hook -Payload '').Trim() | Should -BeNullOrEmpty
        }
        It 'no-ops when content has no secret' {
            (Invoke-HookContent -Content 'host = localhost').Trim() | Should -BeNullOrEmpty
        }
    }
}
