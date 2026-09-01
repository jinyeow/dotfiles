#Requires -Version 7
# Behavioural tests for claude/no-claude-session-trailer.sh — the PreToolUse(Bash|PowerShell)
# hard-block hook (issue #219, layer 3) that denies a command matching one of the guarded
# shapes (git commit, PR create/update, Azure Boards update) when it also contains a banned
# AI/attribution term from the shared wordlist, plus an unconditional deny on git's
# `--no-verify` flag / `-n` short form (the layer-2 git-hooks bypass). It is a bash script
# (jq + grep), so the tests drive it through `bash` with tool-call JSON on stdin.
#
# The hook resolves the wordlist as a sibling file next to its own runtime path
# (~/.claude/banned-ai-terms.txt at the installed destination). To exercise that resolution
# faithfully without touching the installed destination, each test copies the script plus the
# shared wordlist into an isolated temp directory (mimicking the sibling layout) and invokes it
# from there; the fail-closed test uses a temp directory with the script only.
#
# The suite needs bash + jq (as the hook does); it skips rather than false-green when absent.

. (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')
$script:HasBash = [bool](Resolve-TestBash) -and
    [bool](Get-Command jq -ErrorAction SilentlyContinue)

BeforeAll {
    . (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')
    $script:TestBash = Resolve-TestBash
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:HookSource = Join-Path $script:RepoRoot 'claude/no-claude-session-trailer.sh'
    $script:WordlistSource = Join-Path $script:RepoRoot 'ai-agents/_shared/banned-ai-terms.txt'

    # Sibling layout (hook + wordlist together), mimicking ~/.claude/.
    $script:InstalledDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:InstalledDir -Force | Out-Null
    Copy-Item -LiteralPath $script:HookSource -Destination (Join-Path $script:InstalledDir 'no-claude-session-trailer.sh')
    Copy-Item -LiteralPath $script:WordlistSource -Destination (Join-Path $script:InstalledDir 'banned-ai-terms.txt')
    $script:Hook = Join-Path $script:InstalledDir 'no-claude-session-trailer.sh'

    # Hook-only layout (no sibling wordlist), for the fail-closed case.
    $script:NoWordlistDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:NoWordlistDir -Force | Out-Null
    Copy-Item -LiteralPath $script:HookSource -Destination (Join-Path $script:NoWordlistDir 'no-claude-session-trailer.sh')
    $script:HookNoWordlist = Join-Path $script:NoWordlistDir 'no-claude-session-trailer.sh'

    # Drive the bash hook with a command string wrapped as the tool-call JSON on stdin.
    function Invoke-Hook {
        param([string] $Command, [string] $HookPath = $script:Hook)
        $json = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        return ($json | & $script:TestBash $HookPath 2>&1 | Out-String)
    }
}

AfterAll {
    if ($script:InstalledDir -and (Test-Path -LiteralPath $script:InstalledDir)) {
        Remove-Item -LiteralPath $script:InstalledDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($script:NoWordlistDir -and (Test-Path -LiteralPath $script:NoWordlistDir)) {
        Remove-Item -LiteralPath $script:NoWordlistDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'claude/no-claude-session-trailer.sh' -Skip:(-not $script:HasBash) {
    Context 'denies a git commit carrying a banned term' {
        It 'denies a plain commit with the Co-Authored-By trailer' {
            $out = Invoke-Hook -Command 'git commit -m "msg" -m "Co-Authored-By: Claude <noreply@anthropic.com>"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `git -C <path> commit` with a banned term' {
            # The flag group allows each global flag to carry an argument (-C <path>): a unit is
            # `-flag` optionally followed by one non-flag argument token, so a flag WITH an
            # argument can't slip between git and commit and evade the deny.
            $out = Invoke-Hook -Command 'git -C /tmp/x commit -m "Co-Authored-By: Claude"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `git -c k=v commit` with a banned term' {
            $out = Invoke-Hook -Command 'git -c user.name=x commit -m "written by AI"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies a commit carrying the generated-with marker' {
            $out = Invoke-Hook -Command 'git commit -m "feat: x" -m "Generated with Claude Code"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'denies PR create/update carrying a banned term' {
        It 'denies `gh pr create` with a banned term' {
            $out = Invoke-Hook -Command 'gh pr create --title x --body "Generated with Claude Code"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `gh pr edit` with a banned term' {
            $out = Invoke-Hook -Command 'gh pr edit 123 --body "Reviewed by Codex"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `az repos pr create` with a banned term' {
            $out = Invoke-Hook -Command 'az repos pr create --title x --description "written by AI"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `az repos pr update` with a banned term' {
            $out = Invoke-Hook -Command 'az repos pr update --id 1 --description "Co-Authored-By: Claude"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'denies Azure Boards updates carrying a banned term (the real failure case)' {
        It 'denies `az boards work-item update` with a banned term' {
            $out = Invoke-Hook -Command 'az boards work-item update --id 1 --discussion "Reviewed by Codex"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `az boards work-item comment add` with a banned term' {
            $out = Invoke-Hook -Command 'az boards work-item comment add --id 1 --text "Fable+Codex review attribution"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `az devops invoke` (the generic Boards REST passthrough) with a banned term' {
            $out = Invoke-Hook -Command 'az devops invoke --area wit --resource comments --route-parameters project=x --http-method POST --query-parameters text="thanks Claude"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'denies git --no-verify outright, independent of the wordlist' {
        It 'denies `git commit --no-verify` with a clean message' {
            $out = Invoke-Hook -Command 'git commit -m "clean message" --no-verify'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `git commit -n` (the --no-verify short form) with a clean message' {
            $out = Invoke-Hook -Command 'git commit -n -m "clean message"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `git push --no-verify`' {
            $out = Invoke-Hook -Command 'git push --no-verify origin main'
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'fails closed when the wordlist is missing' {
        It 'denies with a clear reason naming the missing wordlist path' {
            $out = Invoke-Hook -Command 'git commit -m "clean message"' -HookPath $script:HookNoWordlist
            $out | Should -Match '"permissionDecision":"deny"'
            $out | Should -Match 'wordlist is missing or unreadable'
        }
    }

    Context 'allows otherwise' {
        It 'allows a clean commit' {
            $out = Invoke-Hook -Command 'git commit -m "a normal message"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows `git -C <path> commit` without a banned term' {
            $out = Invoke-Hook -Command 'git -C /tmp/x commit -m "normal"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows a clean PR create' {
            $out = Invoke-Hook -Command 'gh pr create --title x --body "normal description"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows a clean Azure Boards update' {
            $out = Invoke-Hook -Command 'az boards work-item update --id 1 --discussion "looks good"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows a non-commit command that merely mentions a banned term in prose' {
            $out = Invoke-Hook -Command 'echo this script uses the Claude API'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows an unrelated `-n` flag on a non-git command' {
            $out = Invoke-Hook -Command 'grep -n foo bar.txt'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows a clean commit whose command line merely contains a claude/ path segment' {
            # \bClaude\b word-boundary matches the literal "claude" inside a path like
            # claude/settings.json — the wordlist must scan message content only, not the
            # whole raw command (which would self-block routine commits in this repo).
            $out = Invoke-Hook -Command 'git add claude/settings.json && git commit -m "fix"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows a clean commit whose command line contains a codex/ path segment' {
            $out = Invoke-Hook -Command 'git add codex/ai-reference-guard.sh && git commit -m "fix"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows `git push -n` (dry-run, not --no-verify)' {
            $out = Invoke-Hook -Command 'git push -n origin main'
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'scopes the wordlist match to message content, not the whole raw command' {
        It 'denies a banned term inside the actual commit message even with a claude/ path segment present' {
            $out = Invoke-Hook -Command 'git add claude/settings.json && git commit -m "Co-Authored-By: Claude"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies a multi-line commit message carrying the trailer on a later line' {
            $out = Invoke-Hook -Command "git commit -m `"feat: x`n`nCo-Authored-By: Claude`""
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies an unquoted banned term in a -m value' {
            $out = Invoke-Hook -Command 'git commit -m Co-Authored-By:Claude'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies an unquoted banned term in a --body value' {
            $out = Invoke-Hook -Command 'gh pr create --title x --body AI-generated'
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }
}
