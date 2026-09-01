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
# The whole hook is scoped to Hollard/Azure-DevOps-remote repos (mirroring
# git/templates/hooks/pre-commit's own scoping): it reads `git remote get-url origin` from its
# inherited cwd and allows everything outright when that fails or doesn't match. So every check
# below runs with the process cwd pushed into a throwaway repo whose origin is set accordingly —
# a Hollard-remote repo by default (Invoke-Hook's default -RepoDir), so the existing deny
# behaviour is exercised as before; a dedicated context covers the GitHub/no-origin allow cases.
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

    $script:HollardHttps = 'https://dev.azure.com/HollardInsuranceRetail/Proj/_git/Repo'
    $script:GitHubUrl = 'https://github.com/jinyeow/dotfiles.git'

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

    # Throwaway git repos to drive the `git remote get-url origin` scoping check, mirroring
    # tests/git-templates-ai-reference-hook.Tests.ps1's New-TestRepo helper.
    function New-TestRepo {
        param([string] $OriginUrl, [string] $NameHint = '')
        $suffix = if ($NameHint) { "$NameHint-$([guid]::NewGuid())" } else { [guid]::NewGuid() }
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ('no-claude-trailer-' + $suffix)
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        & git -C $root init -q . 2>&1 | Out-Null
        & git -C $root config user.email 'test@example.invalid' 2>&1 | Out-Null
        & git -C $root config user.name 'Test' 2>&1 | Out-Null
        if ($OriginUrl) {
            & git -C $root remote add origin $OriginUrl 2>&1 | Out-Null
        }
        return $root
    }

    $script:HollardRepo = New-TestRepo -OriginUrl $script:HollardHttps
    $script:GitHubRepo = New-TestRepo -OriginUrl $script:GitHubUrl
    $script:NoOriginRepo = New-TestRepo -OriginUrl $null
    # A Hollard-remote repo whose own path contains a space, to exercise a quoted multi-word
    # `-C "<path>"` value (this repo's own path contains a space too — see AGENTS.md).
    $script:HollardRepoWithSpace = New-TestRepo -OriginUrl $script:HollardHttps -NameHint 'Hollard Repo'

    # Drive the bash hook with a command string wrapped as the tool-call JSON on stdin, from
    # inside the given repo (default: the Hollard-remote repo, so scoped-in behaviour is the
    # default for the existing deny-focused tests).
    function Invoke-Hook {
        param(
            [string] $Command,
            [string] $HookPath = $script:Hook,
            [string] $RepoDir = $script:HollardRepo
        )
        $json = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        Push-Location $RepoDir
        try {
            return ($json | & $script:TestBash $HookPath 2>&1 | Out-String)
        } finally {
            Pop-Location
        }
    }
}

AfterAll {
    foreach ($dir in @($script:InstalledDir, $script:NoWordlistDir, $script:HollardRepo, $script:GitHubRepo, $script:NoOriginRepo, $script:HollardRepoWithSpace)) {
        if ($dir -and (Test-Path -LiteralPath $dir)) {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
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
            # argument can't slip between git and commit and evade the deny. Uses the real
            # Hollard-remote repo as the -C target: -C now also drives the repo-scoping check
            # (see the `git -C` scoping context below), so a decoy path with no real origin
            # would be scoped out before the wordlist check ever ran.
            $hollardPath = $script:HollardRepo -replace '\\', '/'
            $out = Invoke-Hook -Command "git -C $hollardPath commit -m `"Co-Authored-By: Claude`""
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

    Context 'denies the SKIP_* env-var bypass of layer 2''s git hooks, independent of the wordlist' {
        It 'denies `SKIP_AI_REFERENCE_SCAN=1 git commit`' {
            $out = Invoke-Hook -Command 'SKIP_AI_REFERENCE_SCAN=1 git commit -m "clean message"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `SKIP_GITLEAKS=1 git commit`' {
            $out = Invoke-Hook -Command 'SKIP_GITLEAKS=1 git commit -m "clean message"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies a quoted `SKIP_GITLEAKS="1"` value (the unquoted-only evasion)' {
            $out = Invoke-Hook -Command 'SKIP_GITLEAKS="1" git commit -m "clean message"'
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
            # Uses the real Hollard-remote repo as the -C target so this exercises the clean
            # wordlist path in scope, not an out-of-scope allow via a decoy -C target.
            $hollardPath = $script:HollardRepo -replace '\\', '/'
            $out = Invoke-Hook -Command "git -C $hollardPath commit -m `"normal`""
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

    Context 'recognizes additional message-bearing flag shapes' {
        It 'denies git commit -am with a banned term (the clustered short-flag form)' {
            $out = Invoke-Hook -Command 'git commit -am "Co-Authored-By: Claude"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'allows git commit -am with a clean message' {
            $out = Invoke-Hook -Command 'git commit -am "a normal message"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'denies az boards work-item update --discussion with a banned term' {
            $out = Invoke-Hook -Command 'az boards work-item update --id 1 --discussion "Co-Authored-By: Claude"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies az boards work-item comment add --text with a banned term' {
            $out = Invoke-Hook -Command 'az boards work-item comment add --id 1 --text "written by AI"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `az devops invoke --query-parameters key=value` carrying a banned term (key=value shape)' {
            $out = Invoke-Hook -Command 'az devops invoke --area wit --resource comments --query-parameters text="thanks Claude"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'drops the blanket quoted-span scan (flag-value extraction only)' {
        It 'allows a clean commit whose unrelated quoted flag value would trip a blanket scan' {
            # `-c "claude"` is quoted content unrelated to the commit message — a blanket scan of
            # every quoted span (dropped by this fix) would previously false-positive on it. Uses
            # `-c` rather than `-C` here since `-C` now also drives the repo-scoping check (see
            # the `git -C` scoping context above), which this test isn't exercising.
            $out = Invoke-Hook -Command 'git -c "claude" commit -m "fix"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'denies when the banned term is genuinely in the message, alongside an unrelated quoted flag value' {
            $out = Invoke-Hook -Command 'git -c "claude" commit -m "Co-Authored-By: Claude"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'escape-aware quoted-value extraction' {
        It 'denies a banned term inside an escaped inner-quoted -m value' {
            $out = Invoke-Hook -Command 'git commit -m "say \"Claude\" less please"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'scopes -n and SKIP_* checks to the same shell segment as the guarded subcommand' {
        It 'allows a chained `git commit ... && git log -n 1` (unrelated -n on a different segment)' {
            $out = Invoke-Hook -Command 'git commit -m "fix" && git log -n 1'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows a chained `git commit ... && git push -n origin main` (dry-run -n on a different segment)' {
            $out = Invoke-Hook -Command 'git commit -m "fix" && git push -n origin main'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows `SKIP_GITLEAKS=1` prefixed to an unrelated command chained before a clean git commit' {
            $out = Invoke-Hook -Command 'SKIP_GITLEAKS=1 rg foo && git commit -m "clean message"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows `SKIP_GITLEAKS=1` prefixed to an unrelated command with no commit anywhere' {
            $out = Invoke-Hook -Command 'SKIP_GITLEAKS=1 rg foo && git log -n 1'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows a command that merely mentions SKIP_GITLEAKS=1 in unrelated prose' {
            $out = Invoke-Hook -Command "rg 'SKIP_GITLEAKS=1' README.md"
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'repo scoping (Hollard/Azure DevOps remotes only)' {
        It 'allows a banned commit term in a GitHub-remote repo (out of scope)' {
            $out = Invoke-Hook -Command 'git commit -m "Co-Authored-By: Claude"' -RepoDir $script:GitHubRepo
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows a banned commit term when there is no origin remote at all' {
            $out = Invoke-Hook -Command 'git commit -m "Co-Authored-By: Claude"' -RepoDir $script:NoOriginRepo
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows `git commit --no-verify` in a GitHub-remote repo (out of scope)' {
            $out = Invoke-Hook -Command 'git commit -m "clean message" --no-verify' -RepoDir $script:GitHubRepo
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'allows `SKIP_GITLEAKS=1 git commit` in a GitHub-remote repo (out of scope)' {
            $out = Invoke-Hook -Command 'SKIP_GITLEAKS=1 git commit -m "clean message"' -RepoDir $script:GitHubRepo
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'still denies a banned commit term in a Hollard-remote repo' {
            $out = Invoke-Hook -Command 'git commit -m "Co-Authored-By: Claude"' -RepoDir $script:HollardRepo
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'scopes via `git -C <path>` to the target repo''s origin, not the inherited cwd (out-of-scope cwd, in-scope -C target)' {
            $hollardPath = $script:HollardRepo -replace '\\', '/'
            $out = Invoke-Hook -Command "git -C $hollardPath commit --no-verify -m `"Generated with Claude`"" -RepoDir $script:GitHubRepo
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'scopes via `git -C <path>` and allows when the -C target is out of scope (in-scope cwd, out-of-scope -C target)' {
            $githubPath = $script:GitHubRepo -replace '\\', '/'
            $out = Invoke-Hook -Command "git -C $githubPath commit -m `"Generated with Claude`"" -RepoDir $script:HollardRepo
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'clustered short-flag evasion of the -n (no-verify) deny' {
        It 'denies `git commit -nm "..."` (clustered -n and -m short flags)' {
            $out = Invoke-Hook -Command 'git commit -nm "Generated with Claude"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `git commit -nm "..."` for the -n bypass specifically, even with a clean message' {
            $out = Invoke-Hook -Command 'git commit -nm "clean message"'
            $out | Should -Match '"permissionDecision":"deny"'
            $out | Should -Match 'no-verify'
        }
        It 'still denies `git commit -am` with a banned term (clustering fix does not regress -am)' {
            $out = Invoke-Hook -Command 'git commit -am "Co-Authored-By: Claude"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'still allows `git commit -am` with a clean message (clustering fix does not regress -am)' {
            $out = Invoke-Hook -Command 'git commit -am "a normal message"'
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'quoted `-C <path>` value is unquoted before the origin lookup (cycle-4 regression)' {
        It 'denies `git -C "." commit -nm "..."` run from a Hollard-origin cwd (quoted "." -C path)' {
            # Before the fix, the extracted -C value kept its literal quotes (".\""), the
            # `git -C '".\"' remote get-url origin` lookup failed, and the `|| exit 0` fallback
            # let the whole command through — skipping the -n (--no-verify) deny below.
            $out = Invoke-Hook -Command 'git -C "." commit -nm "Generated with Claude"' -RepoDir $script:HollardRepo
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `git -C "." commit --no-verify -m "clean"` run from a Hollard-origin cwd (quoted "." -C path)' {
            $out = Invoke-Hook -Command 'git -C "." commit --no-verify -m "clean"' -RepoDir $script:HollardRepo
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'still denies `git -C . commit -m "..."` with an unquoted "." -C path (control, no regression)' {
            $out = Invoke-Hook -Command 'git -C . commit -m "Generated with Claude"' -RepoDir $script:HollardRepo
            $out | Should -Match '"permissionDecision":"deny"'
        }
    }

    Context 'quoted multi-word `-C "path-with-a-space"` value (flag_group argument capture)' {
        It 'denies `git -C "path-with-a-space" commit -nm "..."` (no-verify, quoted multi-word -C value)' {
            $hollardSpacePath = $script:HollardRepoWithSpace -replace '\\', '/'
            $out = Invoke-Hook -Command "git -C `"$hollardSpacePath`" commit -nm `"Generated with Claude`"" -RepoDir $script:GitHubRepo
            $out | Should -Match '"permissionDecision":"deny"'
            $out | Should -Match 'no-verify'
        }
        It 'denies `git -C "path-with-a-space" commit -m "..."` (wordlist, quoted multi-word -C value)' {
            $hollardSpacePath = $script:HollardRepoWithSpace -replace '\\', '/'
            $out = Invoke-Hook -Command "git -C `"$hollardSpacePath`" commit -m `"Generated with Claude`"" -RepoDir $script:GitHubRepo
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'allows `git -C "path-with-a-space" commit -m "..."` with a clean message (no false positive)' {
            $hollardSpacePath = $script:HollardRepoWithSpace -replace '\\', '/'
            $out = Invoke-Hook -Command "git -C `"$hollardSpacePath`" commit -m `"a normal message`"" -RepoDir $script:GitHubRepo
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'export persists the SKIP-var bypass forward across shell segments' {
        It 'denies `export SKIP_AI_REFERENCE_SCAN=1 && git commit ...` (export persists forward, not segment-bound)' {
            $out = Invoke-Hook -Command 'export SKIP_AI_REFERENCE_SCAN=1 && git commit -m "clean message"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `export SKIP_GITLEAKS=1 && git commit ...`' {
            $out = Invoke-Hook -Command 'export SKIP_GITLEAKS=1 && git commit -m "clean message"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'still allows a commit message that merely mentions SKIP_GITLEAKS=1 in prose (assignment-shape anchor holds)' {
            $out = Invoke-Hook -Command 'git commit -m "mentions SKIP_GITLEAKS=1 in a message about our hooks"'
            $out.Trim() | Should -BeNullOrEmpty
        }
        It 'still allows a non-exported prefix assignment chained before an unrelated clean commit (unchanged segment-bound behavior)' {
            $out = Invoke-Hook -Command 'SKIP_GITLEAKS=1 rg foo && git commit -m "clean message"'
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'gh pr create/edit short flags -t/-b' {
        It 'denies `gh pr create -t "..." -b "..."` with a banned term in -b' {
            $out = Invoke-Hook -Command 'gh pr create -t "fix" -b "Generated with Claude Code"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'denies `gh pr edit 123 -t "..."` with a banned term in -t' {
            $out = Invoke-Hook -Command 'gh pr edit 123 -t "Reviewed by Codex"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'allows `gh pr create -t "..." -b "..."` with a clean title/body' {
            $out = Invoke-Hook -Command 'gh pr create -t "fix" -b "normal description"'
            $out.Trim() | Should -BeNullOrEmpty
        }
    }

    Context 'multi-value --fields/--route-parameters/--query-parameters key=value runs' {
        It 'denies a banned term in the SECOND key=value pair after --fields' {
            $out = Invoke-Hook -Command 'az boards work-item update --fields System.Title=ok "System.Description=Thanks Claude"'
            $out | Should -Match '"permissionDecision":"deny"'
        }
        It 'allows a clean multi-pair --fields run' {
            $out = Invoke-Hook -Command 'az boards work-item update --fields System.Title=ok System.Description=fine'
            $out.Trim() | Should -BeNullOrEmpty
        }
    }
}
