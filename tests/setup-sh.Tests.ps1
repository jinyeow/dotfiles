#Requires -Version 7
# Pester tests for setup.sh (the Linux/WSL installer), run from pwsh via a child bash process.
# Complements tests/setup.Tests.ps1 (setup.ps1) and tests/setup-git.Tests.ps1 (git module).

BeforeAll {
    . (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')

    $script:Repo = Split-Path $PSScriptRoot -Parent
    $script:SetupSh = Join-Path $script:Repo 'setup.sh'
    $script:Bash = Resolve-TestBash
    if (-not $script:Bash) {
        throw 'setup-sh.Tests.ps1: no usable bash found, WSL launchers excluded — install Git for Windows'
    }

    # Converts a Windows path to MSYS/POSIX form (C:\Users\foo -> /c/Users/foo) for use as a bash
    # PATH entry. Pure PowerShell -replace, no external tool: on Linux hosts $Path is already
    # POSIX (no drive-letter prefix), so the regex simply doesn't match and the value passes
    # through unchanged.
    $script:ConvertToUnixPath = {
        param([Parameter(Mandatory)][string]$Path)
        $unix = $Path -replace '\\', '/'
        if ($unix -match '^([A-Za-z]):(.*)$') {
            $unix = "/$($Matches[1].ToLower())$($Matches[2])"
        }
        return $unix
    }
}

Describe 'setup.sh --clean-backups' {
    BeforeEach {
        $script:TmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-clean-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:TmpHome -Force | Out-Null
    }
    AfterEach {
        Remove-Item -Path $script:TmpHome -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'finds and removes .bak.TIMESTAMP files in HOME' {
        # Regression: `find "$dir" -maxdepth 1 \( -f -o -L \)` used invalid find predicates
        # (-f/-L are not primaries; only -type f/-type l are). find silently errored on every
        # call and the 2>/dev/null swallowed it, so --clean-backups always reported "No backup
        # files found." even with real .bak files sitting right there.
        $bak = Join-Path $script:TmpHome '.gitconfig.bak.20200101_010101'
        Set-Content -Path $bak -Value 'old config' -Encoding UTF8

        # Save/restore, not Remove-Item: the latter unconditionally unsets HOME instead of
        # putting back whatever it was before this test (regression - see the -DryRun test in
        # tests/setup.Tests.ps1, which needed its own isolation to survive an empty HOME leaked
        # from here in a full `Invoke-Pester -Path tests` run).
        $origHome = $env:HOME
        $env:HOME = $script:TmpHome
        try {
            $out = & $script:Bash $script:SetupSh --clean-backups --keep-backups 0 --max-backup-age-days 0 2>&1 | Out-String
        } finally {
            $env:HOME = $origHome
        }

        # --keep-backups 0 --max-backup-age-days 0 means "nothing to prune" (both disabled) —
        # use --keep-backups 1 with a second, older backup instead so a removal actually happens.
        $bak2 = Join-Path $script:TmpHome '.gitconfig.bak.20200101_020202'
        Set-Content -Path $bak2 -Value 'newer config' -Encoding UTF8

        $origHome = $env:HOME
        $env:HOME = $script:TmpHome
        try {
            $out = & $script:Bash $script:SetupSh --clean-backups --keep-backups 1 2>&1 | Out-String
        } finally {
            $env:HOME = $origHome
        }

        $out | Should -Not -Match 'No backup files found'
        $out | Should -Match 'Removed \(count\)'
        # The older of the two (…010101) must be gone; the newer (…020202) must survive.
        (Test-Path $bak) | Should -Be $false
        (Test-Path $bak2) | Should -Be $true
    }

    It 'in dry-run, lists backups as removable but keeps them on disk' {
        $bak = Join-Path $script:TmpHome '.gitconfig.bak.20200101_010101'
        $bak2 = Join-Path $script:TmpHome '.gitconfig.bak.20200101_020202'
        Set-Content -Path $bak -Value 'old config' -Encoding UTF8
        Set-Content -Path $bak2 -Value 'newer config' -Encoding UTF8

        $origHome = $env:HOME
        $env:HOME = $script:TmpHome
        try {
            $out = & $script:Bash $script:SetupSh --dry-run --clean-backups --keep-backups 1 2>&1 | Out-String
        } finally {
            $env:HOME = $origHome
        }

        $out | Should -Match '\[DRY RUN\] would remove \(count\)'
        (Test-Path $bak) | Should -Be $true
        (Test-Path $bak2) | Should -Be $true
    }
}

Describe 'setup.sh --dry-run' {
    It 'previews shared council skills for Pi without mutating the home' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-pi-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m pi --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            foreach ($name in @('council', 'council-code', 'council-business', 'council-plan', 'council-doc')) {
                $out | Should -Match "\.pi/agent/skills/$name -> .*ai-agents/skills/$name"
            }
            (Test-Path (Join-Path $tmpHome '.pi')) | Should -BeFalse
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'projects portable and Claude-native skills plus Claude support in dry-run' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-claude-layout-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $out | Should -Match '\.claude/skills/council -> .*ai-agents/skills/council'
            $out | Should -Match '\.claude/skills/codex-review -> .*claude/skills/codex-review'
            $out | Should -Match '\.claude/skills/_shared -> .*claude/skills/_shared'
            $out | Should -Not -Match '\.claude/skills/_shared -> .*ai-agents/_shared'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not create ~/.claude/skills when running the claude module in dry-run' {
        # Regression: `mkdir -p "$skills_dst"` ran unconditionally in install_claude, ahead of
        # any -DryRun check — the one place --dry-run mutated the filesystem.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $out | Should -Match '(Claude Code CLI is already installed|\[DRY RUN\] would install Claude Code CLI via)'
            (Test-Path (Join-Path $tmpHome '.claude')) | Should -Be $false
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'fails closed when native Claude bootstrap fails, without creating Claude state' {
        # The shimmed curl is injected via a PATH built and set *inside* the bash -c invocation,
        # not via the pwsh-supplied $env:PATH — bash.exe rebuilds PATH at startup (prepending
        # /mingw64/bin) when launched with a PATH env var from a non-MSYS parent, which would
        # otherwise let the real curl win regardless of shim ordering.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-claude-bootstrap-fail-' + [guid]::NewGuid())
        $shim = Join-Path $tmpHome 'bin'
        New-Item -ItemType Directory -Path $shim -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $shim 'curl') -Value "#!/usr/bin/env bash`nexit 42`n" -Encoding UTF8
        & $script:Bash -c 'chmod +x "$1"' _ ((Join-Path $shim 'curl') -replace '\\', '/')
        $shimUnix = & $script:ConvertToUnixPath $shim
        $shimPath = "${shimUnix}:/usr/bin:/bin"

        # Guard: confirm the shim actually wins before relying on it, so a host where it doesn't
        # fails loudly here instead of silently falling through to a real network call below.
        $resolved = (& $script:Bash -c 'PATH="$1" command -v curl' _ $shimPath | Out-String).Trim()
        $resolved | Should -Be "$shimUnix/curl"

        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash -c 'PATH="$1" bash "$2" -m claude' _ $shimPath $script:SetupSh 2>&1 | Out-String
            $out | Should -Match 'Claude Code CLI bootstrap failed'
            $out | Should -Match 'stopped before configuration or projection'
            (Test-Path (Join-Path $tmpHome '.claude')) | Should -Be $false
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'bootstraps Claude natively before projecting configuration' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-claude-bootstrap-ok-' + [guid]::NewGuid())
        $shim = Join-Path $tmpHome 'bin'
        New-Item -ItemType Directory -Path $shim -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $shim 'curl') -Value @'
#!/usr/bin/env bash
cat <<'INSTALL'
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
exit 0
CLAUDE
chmod +x "$HOME/.local/bin/claude"
INSTALL
'@ -Encoding UTF8
        & $script:Bash -c 'chmod +x "$1"' _ ((Join-Path $shim 'curl') -replace '\\', '/')
        $shimUnix = & $script:ConvertToUnixPath $shim
        $shimPath = "${shimUnix}:/usr/bin:/bin"

        $resolved = (& $script:Bash -c 'PATH="$1" command -v curl' _ $shimPath | Out-String).Trim()
        $resolved | Should -Be "$shimUnix/curl"

        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash -c 'PATH="$1" bash "$2" -m claude' _ $shimPath $script:SetupSh 2>&1 | Out-String
            $out | Should -Match 'Claude Code CLI installed'
            $out | Should -Match '\.claude/settings\.json'
            Test-Path (Join-Path $tmpHome '.claude/settings.json') | Should -BeTrue
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.sh Codex bootstrap boundary' {
    It 'previews the native bootstrap without mutating Codex state in dry-run' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-codex-bootstrap-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m codex --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $out | Should -Match '(codex is already installed|\[DRY RUN\] would install Codex CLI via)'
            (Test-Path (Join-Path $tmpHome '.codex')) | Should -Be $false
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'never runs codex login' {
        # 'codex login' appears only as documentation text inside an info message (manual,
        # never executed) — never as a bare command invocation.
        $source = Get-Content -LiteralPath $script:SetupSh -Raw
        $source | Should -Match 'run codex login'
        $source | Should -Not -Match '(?m)^\s*codex login'
    }

    It 'fails closed when native Codex bootstrap fails, without creating Codex state' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-codex-bootstrap-fail-' + [guid]::NewGuid())
        $shim = Join-Path $tmpHome 'bin'
        New-Item -ItemType Directory -Path $shim -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $shim 'curl') -Value "#!/usr/bin/env bash`nexit 42`n" -Encoding UTF8
        & $script:Bash -c 'chmod +x "$1"' _ ((Join-Path $shim 'curl') -replace '\\', '/')
        $shimUnix = & $script:ConvertToUnixPath $shim
        $shimPath = "${shimUnix}:/usr/bin:/bin"

        $resolved = (& $script:Bash -c 'PATH="$1" command -v curl' _ $shimPath | Out-String).Trim()
        $resolved | Should -Be "$shimUnix/curl"

        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash -c 'PATH="$1" bash "$2" -m codex' _ $shimPath $script:SetupSh 2>&1 | Out-String
            $out | Should -Match 'Codex CLI install failed'
            $out | Should -Match 'stopped before configuration or projection'
            (Test-Path (Join-Path $tmpHome '.codex')) | Should -Be $false
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'bootstraps Codex natively before projecting configuration' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-codex-bootstrap-ok-' + [guid]::NewGuid())
        $shim = Join-Path $tmpHome 'bin'
        New-Item -ItemType Directory -Path $shim -Force | Out-Null
        $shimUnix = & $script:ConvertToUnixPath $shim
        # The fake installer places `codex` directly into the shim dir (already on PATH for this
        # invocation), since find_codex_cli — unlike find_claude_cli — has no ~/.local/bin fallback.
        $curlBody = @"
#!/usr/bin/env bash
cat <<INSTALL
cat > "$shimUnix/codex" <<'CODEX'
#!/usr/bin/env bash
exit 0
CODEX
chmod +x "$shimUnix/codex"
INSTALL
"@
        Set-Content -LiteralPath (Join-Path $shim 'curl') -Value $curlBody -Encoding UTF8
        & $script:Bash -c 'chmod +x "$1"' _ ((Join-Path $shim 'curl') -replace '\\', '/')
        $shimPath = "${shimUnix}:/usr/bin:/bin"

        $resolved = (& $script:Bash -c 'PATH="$1" command -v curl' _ $shimPath | Out-String).Trim()
        $resolved | Should -Be "$shimUnix/curl"

        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash -c 'PATH="$1" bash "$2" -m codex' _ $shimPath $script:SetupSh 2>&1 | Out-String
            $out | Should -Match 'Codex CLI installed'
            $out | Should -Match '\.codex/config\.toml'
            $out | Should -Match '\.codex/AGENTS\.md'
            Test-Path (Join-Path $tmpHome '.codex/config.toml') | Should -BeTrue
            Test-Path (Join-Path $tmpHome '.codex/AGENTS.md') | Should -BeTrue
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.sh Codex MCP registration gating' {
    BeforeAll {
        $script:CodexMcpShim = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-codex-mcp-shim-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:CodexMcpShim -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:CodexMcpShim 'claude') -Value "#!/usr/bin/env bash`nexit 0`n" -Encoding UTF8
        & $script:Bash -c 'chmod +x "$1"' _ ((Join-Path $script:CodexMcpShim 'claude') -replace '\\', '/')
        $script:CodexMcpShimUnix = & $script:ConvertToUnixPath $script:CodexMcpShim
    }

    AfterAll {
        Remove-Item -Path $script:CodexMcpShim -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'skips registration when the claude CLI is present but the Claude settings file is missing' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-codex-mcp-nosettings-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $shimPath = "${script:CodexMcpShimUnix}:/usr/bin:/bin"
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash -c 'PATH="$1" bash "$2" -m codex --dry-run' _ $shimPath $script:SetupSh 2>&1 | Out-String
            $out | Should -Match 'Claude settings file not found — skipping MCP registration'
            $out | Should -Not -Match 'would register user-scope MCP: claude mcp add --scope user codex'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'previews registration only when both the claude CLI and the Claude settings file are present' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-codex-mcp-ok-' + [guid]::NewGuid())
        $claudeDir = Join-Path $tmpHome '.claude'
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $claudeDir 'settings.json') -Value '{}'
        $shimPath = "${script:CodexMcpShimUnix}:/usr/bin:/bin"
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash -c 'PATH="$1" bash "$2" -m codex --dry-run' _ $shimPath $script:SetupSh 2>&1 | Out-String
            $out | Should -Match '\[DRY RUN\] would register user-scope MCP: claude mcp add --scope user codex'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'skips registration when the claude CLI is not on PATH' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-codex-mcp-noclaude-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash -c 'PATH="/usr/bin:/bin" bash "$1" -m codex --dry-run' _ $script:SetupSh 2>&1 | Out-String
            $out | Should -Match 'claude CLI not found — skipping MCP registration'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.sh Codex skill projection' {
    It 'projects portable and Codex-native skills, excluding Claude-only skills' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-codex-skills-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m codex --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            foreach ($name in @('council', 'council-code', 'council-business', 'council-plan', 'council-doc')) {
                $out | Should -Match "\.codex/skills/$name -> .*ai-agents/skills/$name"
            }
            $out | Should -Not -Match '\.codex/skills/codex-review ->'
            $out | Should -Not -Match '\.codex/skills/handoff ->'
            $out | Should -Not -Match '\.codex/skills/git-guardrails-claude-code ->'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.sh module list — codex' {
    It 'runs codex as a recognized module in the "all" expansion' {
        $source = Get-Content -LiteralPath $script:SetupSh -Raw
        $moduleLine = ($source -split "`n" | Where-Object { $_ -match 'MODULES=\(neovim' })
        $moduleLine | Should -Match '\bcodex\b'
    }
}

# These focused dry-run fixtures cover the destructive managed/unmanaged decisions without
# invoking Pi's real package installer or mutating a runtime home. Non-dry-run Pi bootstrap and
# package behavior remains outside this suite; it requires an installed/authenticated runtime.
# Hosts that cannot create POSIX symlinks skip these fixtures rather than testing copy emulation.
Describe 'setup.sh relative-link migration safety' {
    BeforeAll {
        $script:CanCreateSymlink = $false
        $probeDir = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-link-probe-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
        try {
            & $script:Bash -c 'ln -s target "$1/link"' _ ($probeDir -replace '\\', '/') 2>$null
            $script:CanCreateSymlink = $LASTEXITCODE -eq 0
        } finally {
            Remove-Item -Path $probeDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'recognizes a relative managed Pi skills link against its link parent' -Skip:(-not $script:CanCreateSymlink) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-pi-managed-' + [guid]::NewGuid())
        $skills = Join-Path $tmpHome '.pi/agent/skills'
        New-Item -ItemType Directory -Path (Split-Path $skills -Parent) -Force | Out-Null
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$(realpath --relative-to="$(dirname "$2")" "$1")" "$2"' _ `
                ((Join-Path $script:Repo 'pi/skills') -replace '\\', '/') ($skills -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m pi --dry-run 2>&1 | Out-String
            $out | Should -Match 'remove managed Pi skills link'
            $out | Should -Not -Match 'Pi skills link is unmanaged'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'preserves an unmanaged relative Pi skills link' -Skip:(-not $script:CanCreateSymlink) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-pi-unmanaged-' + [guid]::NewGuid())
        $foreign = Join-Path $tmpHome 'foreign-skills'
        $skills = Join-Path $tmpHome '.pi/agent/skills'
        New-Item -ItemType Directory -Path $foreign, (Split-Path $skills -Parent) -Force | Out-Null
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$(realpath --relative-to="$(dirname "$2")" "$1")" "$2"' _ `
                ($foreign -replace '\\', '/') ($skills -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m pi --dry-run 2>&1 | Out-String
            $out | Should -Match 'Pi skills link is unmanaged; preserving it'
            $out | Should -Not -Match 'remove managed Pi skills link'
            $out | Should -Not -Match '\.pi/agent/(settings\.json|extensions|prompts|themes)'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'preserves an unmanaged Claude skill directory instead of planning a replacement' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-claude-unmanaged-dir-' + [guid]::NewGuid())
        $link = Join-Path $tmpHome '.claude/skills/council'
        New-Item -ItemType Directory -Path $link -Force | Out-Null
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $out | Should -Match 'Preserved unmanaged Claude skill: .*\.claude/skills/council'
            $out | Should -Not -Match '\[DRY RUN\] symlink .*\.claude/skills/council ->'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'preserves an external Claude skill link instead of planning a replacement' -Skip:(-not $script:CanCreateSymlink) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-claude-external-' + [guid]::NewGuid())
        $foreign = Join-Path $tmpHome 'foreign-council'
        $link = Join-Path $tmpHome '.claude/skills/council'
        New-Item -ItemType Directory -Path $foreign, (Split-Path $link -Parent) -Force | Out-Null
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$1" "$2"' _ ($foreign -replace '\\', '/') ($link -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $out | Should -Match 'Preserved unmanaged Claude skill link: .*\.claude/skills/council'
            $out | Should -Not -Match '\[DRY RUN\] symlink .*\.claude/skills/council ->'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'warns distinctly when a preserved unmanaged skill link target is missing (dangling)' -Skip:(-not $script:CanCreateSymlink) {
        # Regression for issue #67 finding 1: a symlink whose target was never under a managed
        # or historical skill root (an ad-hoc/dev-worktree path) is "unmanaged — preserve", which
        # is indistinguishable from a legitimate user link even when the target no longer exists.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-claude-dangling-' + [guid]::NewGuid())
        $foreignParent = Join-Path $tmpHome 'foreign-dev-worktree'
        $foreign = Join-Path $foreignParent 'council'
        $link = Join-Path $tmpHome '.claude/skills/council'
        New-Item -ItemType Directory -Path $foreign, (Split-Path $link -Parent) -Force | Out-Null
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$1" "$2"' _ ($foreign -replace '\\', '/') ($link -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            Remove-Item -LiteralPath $foreignParent -Recurse -Force
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $out | Should -Match 'Preserved unmanaged Claude skill link \(target missing\): .*\.claude/skills/council'
            $out | Should -Not -Match '\[DRY RUN\] symlink .*\.claude/skills/council ->'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'migrates a legacy claude/skills link to the current projection' -Skip:(-not $script:CanCreateSymlink) {
        # Released installs symlinked ~/.claude/skills/<name> at the old top-level claude/skills
        # source. Those links are repository-managed and must be replaced by the current
        # ai-agents projection, not preserved as dangling unmanaged links.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-claude-legacy-' + [guid]::NewGuid())
        $link = Join-Path $tmpHome '.claude/skills/council'
        New-Item -ItemType Directory -Path (Split-Path $link -Parent) -Force | Out-Null
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$1" "$2"' _ `
                ((Join-Path $script:Repo 'ai-agents/claude/skills/council') -replace '\\', '/') ($link -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $out | Should -Not -Match 'Preserved unmanaged Claude skill link: .*\.claude/skills/council'
            $out | Should -Match '\[DRY RUN\] symlink .*\.claude/skills/council -> .*ai-agents/skills/council'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'removes an obsolete legacy claude/skills link but preserves unmanaged entries' -Skip:(-not $script:CanCreateSymlink) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-claude-legacy-obsolete-' + [guid]::NewGuid())
        $skillsDir = Join-Path $tmpHome '.claude/skills'
        $foreign = Join-Path $tmpHome 'foreign-skill'
        New-Item -ItemType Directory -Path $skillsDir, $foreign -Force | Out-Null
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$1" "$2"' _ `
                ((Join-Path $script:Repo 'ai-agents/claude/skills/legacy-only') -replace '\\', '/') ((Join-Path $skillsDir 'legacy-only') -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            & $script:Bash -c 'ln -s "$1" "$2"' _ `
                ($foreign -replace '\\', '/') ((Join-Path $skillsDir 'unmanaged') -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $out | Should -Match 'remove obsolete Claude skill link.*legacy-only'
            $out | Should -Not -Match 'remove obsolete Claude skill link.*unmanaged'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not classify a link under the Codex-only historical root ai-agents/codex/skills as managed' -Skip:(-not $script:CanCreateSymlink) {
        # Regression for issue #71: Claude's own installer (current or historical) never wrote
        # into ai-agents/codex/skills — that root belongs only to Codex's projection history.
        # A link that happens to resolve under it must stay untouched by Claude's cleanup, not
        # be silently removed as "obsolete managed".
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-claude-codexroot-' + [guid]::NewGuid())
        $skillsDir = Join-Path $tmpHome '.claude/skills'
        $codexOnlySkill = Join-Path $script:Repo 'ai-agents/codex/skills/legacy-only'
        New-Item -ItemType Directory -Path $skillsDir, $codexOnlySkill -Force | Out-Null
        $link = Join-Path $skillsDir 'legacy-only'
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$1" "$2"' _ `
                ($codexOnlySkill -replace '\\', '/') ($link -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $out | Should -Not -Match 'remove obsolete Claude skill link.*legacy-only'
            Test-Path -LiteralPath $link | Should -BeTrue
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path (Join-Path $script:Repo 'ai-agents/codex/skills') -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not classify a link under a same-basename-prefix sibling root as managed' -Skip:(-not $script:CanCreateSymlink) {
        # Regression guard: string-prefix matching without a trailing separator would let
        # ai-agents/skills-extra be misclassified as inside ai-agents/skills. is_managed_skill_link
        # matches "$resolved_root/"* so a sibling directory prefix alone must not qualify.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-claude-prefixguard-' + [guid]::NewGuid())
        $skillsDir = Join-Path $tmpHome '.claude/skills'
        $siblingSkill = Join-Path $script:Repo 'ai-agents/skills-extra/legacy-only'
        New-Item -ItemType Directory -Path $skillsDir, $siblingSkill -Force | Out-Null
        $link = Join-Path $skillsDir 'legacy-only'
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$1" "$2"' _ `
                ($siblingSkill -replace '\\', '/') ($link -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $out | Should -Not -Match 'remove obsolete Claude skill link.*legacy-only'
            Test-Path -LiteralPath $link | Should -BeTrue
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path (Join-Path $script:Repo 'ai-agents/skills-extra') -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'resolves an existing relative council link instead of planning a replacement' -Skip:(-not $script:CanCreateSymlink) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-council-relative-' + [guid]::NewGuid())
        $link = Join-Path $tmpHome '.claude/skills/council'
        New-Item -ItemType Directory -Path (Split-Path $link -Parent) -Force | Out-Null
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$(realpath --relative-to="$(dirname "$2")" "$1")" "$2"' _ `
                ((Join-Path $script:Repo 'ai-agents/skills/council') -replace '\\', '/') ($link -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $out | Should -Match 'Up to date: .*\.claude/skills/council(?:\r?\n|$)'
            $out | Should -Not -Match '\[DRY RUN\] symlink .*\.claude/skills/council ->'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.sh Claude agent directory migration' {
    It 'preserves a user-owned agents directory' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-agents-owned-' + [guid]::NewGuid())
        $agents = Join-Path $tmpHome '.claude/agents'
        New-Item -ItemType Directory -Path $agents -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $agents 'custom.md') -Value 'user-owned'
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $out | Should -Match 'Preserved unmanaged directory: .*\.claude/agents'
            $out | Should -Not -Match '\[DRY RUN\] symlink .*\.claude/agents ->'
            Get-Content -LiteralPath (Join-Path $agents 'custom.md') | Should -Be 'user-owned'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'preserves an external agents link' -Skip:(-not $script:CanCreateSymlink) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-agents-external-' + [guid]::NewGuid())
        $foreign = Join-Path $tmpHome 'foreign-agents'
        $link = Join-Path $tmpHome '.claude/agents'
        New-Item -ItemType Directory -Path $foreign, (Split-Path $link -Parent) -Force | Out-Null
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$1" "$2"' _ ($foreign -replace '\\\\', '/') ($link -replace '\\\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $out | Should -Match 'Preserved unmanaged directory link: .*\.claude/agents'
            $out | Should -Not -Match '\[DRY RUN\] symlink .*\.claude/agents ->'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'previews migration of a dangling historical agents link' -Skip:(-not $script:CanCreateSymlink) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-agents-historical-' + [guid]::NewGuid())
        $link = Join-Path $tmpHome '.claude/agents'
        $historical = Join-Path $script:Repo 'ai-agents/shared/agents'
        New-Item -ItemType Directory -Path (Split-Path $link -Parent) -Force | Out-Null
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$1" "$2"' _ ($historical -replace '\\\\', '/') ($link -replace '\\\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $out | Should -Match '\[DRY RUN\] symlink .*\.claude/agents -> .*ai-agents/agents'
            $out | Should -Not -Match 'Preserved unmanaged directory link'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'recognizes the original claude/agents source as a historical root' {
        # Regression for issue #67: a live machine's ~/.claude/agents link can predate even
        # ai-agents/shared/agents — the very first agents source was claude/agents, before the
        # #54 ai-agents-module migration. That target no longer exists, so a link still pointing
        # at it must be recognized as historical (repairable), not silently preserved forever.
        $source = Get-Content -LiteralPath $script:SetupSh -Raw
        $source | Should -Match 'DOTFILES/claude/agents'
    }

    It 'warns distinctly when a preserved unmanaged agents link target is missing (dangling)' -Skip:(-not $script:CanCreateSymlink) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-agents-dangling-' + [guid]::NewGuid())
        $foreignParent = Join-Path $tmpHome 'foreign-dev-worktree'
        $foreign = Join-Path $foreignParent 'agents'
        $link = Join-Path $tmpHome '.claude/agents'
        New-Item -ItemType Directory -Path $foreign, (Split-Path $link -Parent) -Force | Out-Null
        $origHome = $env:HOME
        try {
            & $script:Bash -c 'ln -s "$1" "$2"' _ ($foreign -replace '\\', '/') ($link -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            Remove-Item -LiteralPath $foreignParent -Recurse -Force
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $out | Should -Match 'Preserved unmanaged directory link \(target missing\): .*\.claude/agents'
            $out | Should -Not -Match '\[DRY RUN\] symlink .*\.claude/agents ->'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.sh module list' {
    It 'advertises lazygit and windowsterminal in the header comment and usage text' {
        # Regression: the dispatcher (case statement) supports lazygit/windowsterminal, but the
        # header comment and usage() text never mentioned them.
        $header = (Get-Content $script:SetupSh -TotalCount 8)[-1]
        $header | Should -Match 'lazygit'
        $header | Should -Match 'windowsterminal'

        $out = & $script:Bash $script:SetupSh --help 2>&1 | Out-String
        $out | Should -Match 'lazygit'
        $out | Should -Match 'windowsterminal'
    }

    It 'runs lazygit and windowsterminal as recognized modules (no "Unknown module")' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-modules-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & $script:Bash $script:SetupSh -m lazygit,windowsterminal --dry-run 2>&1 | Out-String
            $out | Should -Not -Match "Unknown module 'lazygit'"
            $out | Should -Not -Match "Unknown module 'windowsterminal'"
            $out | Should -Match '=== Lazygit ==='
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
