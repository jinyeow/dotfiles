#Requires -Version 7
# Pester tests for setup.sh (the Linux/WSL installer), run from pwsh via a child bash process.
# Complements tests/setup.Tests.ps1 (setup.ps1) and tests/setup-git.Tests.ps1 (git module).

BeforeAll {
    $script:Repo = Split-Path $PSScriptRoot -Parent
    $script:SetupSh = Join-Path $script:Repo 'setup.sh'
    $script:Bash = (Get-Command bash -ErrorAction Stop).Source
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
            $out = & bash $script:SetupSh --clean-backups --keep-backups 0 --max-backup-age-days 0 2>&1 | Out-String
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
            $out = & bash $script:SetupSh --clean-backups --keep-backups 1 2>&1 | Out-String
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
            $out = & bash $script:SetupSh --dry-run --clean-backups --keep-backups 1 2>&1 | Out-String
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
            $out = & bash $script:SetupSh -m pi --dry-run 2>&1 | Out-String
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
            $out = & bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
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
            $out = & bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $out | Should -Match '(Claude Code CLI is already installed|\[DRY RUN\] would install Claude Code CLI via)'
            (Test-Path (Join-Path $tmpHome '.claude')) | Should -Be $false
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'fails closed when native Claude bootstrap fails, without creating Claude state' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-claude-bootstrap-fail-' + [guid]::NewGuid())
        $shim = Join-Path $tmpHome 'bin'
        New-Item -ItemType Directory -Path $shim -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $shim 'curl') -Value "#!/usr/bin/env bash`nexit 42`n" -Encoding UTF8
        & $script:Bash -c 'chmod +x "$1"' _ ((Join-Path $shim 'curl') -replace '\\', '/')
        $origHome = $env:HOME
        $origPath = $env:PATH
        try {
            $env:HOME = $tmpHome
            $env:PATH = (($shim -replace '\\', '/') + ':/usr/bin:/bin')
            $out = & $script:Bash $script:SetupSh -m claude 2>&1 | Out-String
            $out | Should -Match 'Claude Code CLI bootstrap failed'
            $out | Should -Match 'stopped before configuration or projection'
            (Test-Path (Join-Path $tmpHome '.claude')) | Should -Be $false
        } finally {
            $env:HOME = $origHome
            $env:PATH = $origPath
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
        $origHome = $env:HOME
        $origPath = $env:PATH
        try {
            $env:HOME = $tmpHome
            $env:PATH = (($shim -replace '\\', '/') + ':/usr/bin:/bin')
            $out = & $script:Bash $script:SetupSh -m claude 2>&1 | Out-String
            $out | Should -Match 'Claude Code CLI installed'
            $out | Should -Match '\.claude/settings\.json'
            Test-Path (Join-Path $tmpHome '.claude/settings.json') | Should -BeTrue
        } finally {
            $env:HOME = $origHome
            $env:PATH = $origPath
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
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
            & bash -c 'ln -s target "$1/link"' _ ($probeDir -replace '\\', '/') 2>$null
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
            & bash -c 'ln -s "$(realpath --relative-to="$(dirname "$2")" "$1")" "$2"' _ `
                ((Join-Path $script:Repo 'pi/skills') -replace '\\', '/') ($skills -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & bash $script:SetupSh -m pi --dry-run 2>&1 | Out-String
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
            & bash -c 'ln -s "$(realpath --relative-to="$(dirname "$2")" "$1")" "$2"' _ `
                ($foreign -replace '\\', '/') ($skills -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & bash $script:SetupSh -m pi --dry-run 2>&1 | Out-String
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
            $out = & bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
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
            & bash -c 'ln -s "$1" "$2"' _ ($foreign -replace '\\', '/') ($link -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $out | Should -Match 'Preserved unmanaged Claude skill link: .*\.claude/skills/council'
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
            & bash -c 'ln -s "$1" "$2"' _ `
                ((Join-Path $script:Repo 'ai-agents/claude/skills/council') -replace '\\', '/') ($link -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
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
            & bash -c 'ln -s "$1" "$2"' _ `
                ((Join-Path $script:Repo 'ai-agents/claude/skills/legacy-only') -replace '\\', '/') ((Join-Path $skillsDir 'legacy-only') -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            & bash -c 'ln -s "$1" "$2"' _ `
                ($foreign -replace '\\', '/') ((Join-Path $skillsDir 'unmanaged') -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $out | Should -Match 'remove obsolete Claude skill link.*legacy-only'
            $out | Should -Not -Match 'remove obsolete Claude skill link.*unmanaged'
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'resolves an existing relative council link instead of planning a replacement' -Skip:(-not $script:CanCreateSymlink) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-council-relative-' + [guid]::NewGuid())
        $link = Join-Path $tmpHome '.claude/skills/council'
        New-Item -ItemType Directory -Path (Split-Path $link -Parent) -Force | Out-Null
        $origHome = $env:HOME
        try {
            & bash -c 'ln -s "$(realpath --relative-to="$(dirname "$2")" "$1")" "$2"' _ `
                ((Join-Path $script:Repo 'ai-agents/skills/council') -replace '\\', '/') ($link -replace '\\', '/')
            $LASTEXITCODE | Should -Be 0
            $env:HOME = $tmpHome
            $out = & bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $out | Should -Match 'Up to date: .*\.claude/skills/council(?:\r?\n|$)'
            $out | Should -Not -Match '\[DRY RUN\] symlink .*\.claude/skills/council ->'
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

        $out = & bash $script:SetupSh --help 2>&1 | Out-String
        $out | Should -Match 'lazygit'
        $out | Should -Match 'windowsterminal'
    }

    It 'runs lazygit and windowsterminal as recognized modules (no "Unknown module")' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-modules-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origHome = $env:HOME
        try {
            $env:HOME = $tmpHome
            $out = & bash $script:SetupSh -m lazygit,windowsterminal --dry-run 2>&1 | Out-String
            $out | Should -Not -Match "Unknown module 'lazygit'"
            $out | Should -Not -Match "Unknown module 'windowsterminal'"
            $out | Should -Match '=== Lazygit ==='
        } finally {
            $env:HOME = $origHome
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
