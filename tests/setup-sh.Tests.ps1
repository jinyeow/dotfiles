#Requires -Version 7
# Pester tests for setup.sh (the Linux/WSL installer), run from pwsh via a child bash process.
# Complements tests/setup.Tests.ps1 (setup.ps1) and tests/setup-git.Tests.ps1 (git module).

BeforeAll {
    $script:Repo = Split-Path $PSScriptRoot -Parent
    $script:SetupSh = Join-Path $script:Repo 'setup.sh'
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

        $env:HOME = $script:TmpHome
        try {
            $out = & bash $script:SetupSh --clean-backups --keep-backups 0 --max-backup-age-days 0 2>&1 | Out-String
        } finally {
            Remove-Item Env:\HOME -ErrorAction SilentlyContinue
        }

        # --keep-backups 0 --max-backup-age-days 0 means "nothing to prune" (both disabled) —
        # use --keep-backups 1 with a second, older backup instead so a removal actually happens.
        $bak2 = Join-Path $script:TmpHome '.gitconfig.bak.20200101_020202'
        Set-Content -Path $bak2 -Value 'newer config' -Encoding UTF8

        $env:HOME = $script:TmpHome
        try {
            $out = & bash $script:SetupSh --clean-backups --keep-backups 1 2>&1 | Out-String
        } finally {
            Remove-Item Env:\HOME -ErrorAction SilentlyContinue
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

        $env:HOME = $script:TmpHome
        try {
            $out = & bash $script:SetupSh --dry-run --clean-backups --keep-backups 1 2>&1 | Out-String
        } finally {
            Remove-Item Env:\HOME -ErrorAction SilentlyContinue
        }

        $out | Should -Match '\[DRY RUN\] would remove \(count\)'
        (Test-Path $bak) | Should -Be $true
        (Test-Path $bak2) | Should -Be $true
    }
}

Describe 'setup.sh --dry-run' {
    It 'does not create ~/.claude/skills when running the claude module in dry-run' {
        # Regression: `mkdir -p "$skills_dst"` ran unconditionally in install_claude, ahead of
        # any -DryRun check — the one place --dry-run mutated the filesystem.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-sh-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        try {
            $env:HOME = $tmpHome
            $out = & bash $script:SetupSh -m claude --dry-run 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            (Test-Path (Join-Path $tmpHome '.claude')) | Should -Be $false
        } finally {
            Remove-Item Env:\HOME -ErrorAction SilentlyContinue
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
        try {
            $env:HOME = $tmpHome
            $out = & bash $script:SetupSh -m lazygit,windowsterminal --dry-run 2>&1 | Out-String
            $out | Should -Not -Match "Unknown module 'lazygit'"
            $out | Should -Not -Match "Unknown module 'windowsterminal'"
            $out | Should -Match '=== Lazygit ==='
        } finally {
            Remove-Item Env:\HOME -ErrorAction SilentlyContinue
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
