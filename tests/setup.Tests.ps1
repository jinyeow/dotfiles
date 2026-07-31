#Requires -Version 7
# Pester tests for setup.ps1 argument handling. Runs the installer as a child pwsh
# in -DryRun so it never mutates the machine.

BeforeAll {
    $script:SetupScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'setup.ps1'
}

Describe 'setup.ps1 argument validation' {
    It 'shows usage guidance and exits 1 when no -Module and no -CleanBackups are given' {
        # Regression: `$Module | Select-Object -Unique` collapsed the empty-array default to
        # $null, so the `$Module.Count` guard threw under StrictMode instead of printing usage.
        $output = & pwsh -NoProfile -File $script:SetupScript -DryRun 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $output | Should -Match 'Specify -Module'
        $output | Should -Not -Match "property 'Count' cannot be found"
    }
}

Describe 'setup.ps1 psmux module' {
    It 'runs the psmux module in -DryRun without error and prints its section header' {
        # Isolated on a throwaway USERPROFILE, like the -Backup test below. Without this, a
        # $env:USERPROFILE/$env:HOME left empty by another test file earlier in a full `Invoke-
        # Pester -Path tests` run (setup-sh.Tests.ps1's `Remove-Item Env:\HOME` clears HOME
        # instead of restoring its prior value) leaks in: setup.ps1's non-Windows fallback is
        # `$env:USERPROFILE = $HOME`, and an empty $HOME makes that a no-op, so Join-Path still
        # throws. Pinning USERPROFILE here makes the test self-contained regardless of run order.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-psmux-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module psmux -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '=== psmux'
            $output | Should -Not -Match "Unknown module 'psmux'"
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not forward-copy vendored plugins into a live ~/.psmux/plugins during -Backup' {
        # Regression: the plugin copy loop checked -DryRun but not -Backup, so `-Module psmux
        # -Backup` (a reverse live -> repo sync) still forward-copied repo -> live, mutating the
        # filesystem during what is supposed to be a read-from-live/write-to-repo run.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-psmux-backup-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module psmux -Backup 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Skipped \(vendored copy, no drift\)'
            (Test-Path (Join-Path $tmpHome '.psmux')) | Should -Be $false
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 zellij/yazi -Backup mode' {
    It 'does not create the Zellij config parent directory during -Backup' {
        # Regression: the parent-dir mkdir ahead of New-Junction only checked -DryRun, not
        # -Backup, even though New-Junction itself skips entirely under -Backup — so a -Backup
        # run still mutated the filesystem by creating an otherwise-unused empty directory.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-zellij-backup-' + [guid]::NewGuid())
        $appData = Join-Path $tmpHome 'AppData'
        $zellijParent = Join-Path $appData 'Zellij'
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP, $origAD = $env:USERPROFILE, $env:APPDATA
        try {
            $env:USERPROFILE = $tmpHome
            $env:APPDATA = $appData
            $output = & pwsh -NoProfile -File $script:SetupScript -Module zellij -Backup 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            # Assert on the Zellij parent specifically, not $appData: redirecting USERPROFILE to
            # $tmpHome means the child pwsh writes its own module cache to $appData\Local\Microsoft\
            # PowerShell on Windows, so $appData is not a clean signal. $appData\Zellij is exactly
            # the dir the guarded mkdir would create — the precise regression target.
            (Test-Path $zellijParent) | Should -Be $false
        } finally {
            $env:USERPROFILE = $origUP; $env:APPDATA = $origAD
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not create the yazi config parent directory during -Backup' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-yazi-backup-' + [guid]::NewGuid())
        $appData = Join-Path $tmpHome 'AppData'
        $yaziParent = Join-Path $appData 'yazi'
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP, $origAD = $env:USERPROFILE, $env:APPDATA
        try {
            $env:USERPROFILE = $tmpHome
            $env:APPDATA = $appData
            $output = & pwsh -NoProfile -File $script:SetupScript -Module yazi -Backup 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            # Assert on the yazi parent specifically, not $appData: the child pwsh writes its own
            # module cache under $appData\Local on Windows once USERPROFILE is redirected, so only
            # $appData\yazi (the dir the guarded mkdir would create) is the precise regression target.
            (Test-Path $yaziParent) | Should -Be $false
        } finally {
            $env:USERPROFILE = $origUP; $env:APPDATA = $origAD
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 dry-run directory-creation cosmetics' {
    It 'marks a not-yet-existing parent directory as [DRY RUN] rather than a bare "Created:"' {
        # Regression: Copy-Dotfile (and Install-Psmux's plugin-dir creation, covered by the
        # psmux -DryRun test above) printed "Created:    $dir" even under -DryRun, when nothing
        # was actually created — the message just lied. codex's config.toml/AGENTS.md copy is a
        # Copy-Dotfile call whose parent (~/.codex) does not exist yet in a fresh HOME.
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '\[DRY RUN\] would create:\s+\S*\.codex\b'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 codex module shared claude skills' {
    It 'junctions claude/skills subdirectories into ~/.codex/skills, minus the Claude-harness-coupled denylist' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-skills-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            # A shared skill and the _shared support dir (referenced via ../_shared) come across.
            # Patterns anchor on the "link -> target" separator so `tdd` can't false-match a
            # future `tdd-something` skill (`\b` treats the hyphen as a word boundary).
            $output | Should -Match '\[DRY RUN\] junction .*\.codex\\skills\\tdd ->'
            $output | Should -Match '\[DRY RUN\] junction .*\.codex\\skills\\_shared ->'
            # Skills coupled to the Claude Code harness stay out of Codex.
            $output | Should -Not -Match '\.codex\\skills\\codex-review ->'
            $output | Should -Not -Match '\.codex\\skills\\handoff ->'
            $output | Should -Not -Match '\.codex\\skills\\git-guardrails-claude-code ->'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'junctions only the Codex-native flavour when a codex/skills name collides with a shared skill' -Skip:(-not $IsWindows) {
        # A name in both sources must yield ONE junction (the codex/skills one) — junctioning
        # the shared dir first and letting the native one replace it would back up and re-create
        # the junction on every run, accumulating stale .bak.* junctions.
        $repoRoot = Split-Path $script:SetupScript -Parent
        $codexSkillsDir = Join-Path $repoRoot 'codex\skills'
        $createdParent = -not (Test-Path $codexSkillsDir)
        $fixture = Join-Path $codexSkillsDir 'tdd'
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-codex-collision-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $fixture, $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module codex -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '\.codex\\skills\\tdd -> .*codex\\skills\\tdd'
            $output | Should -Not -Match '\.codex\\skills\\tdd -> .*claude\\skills\\tdd'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $fixture -Recurse -Force -ErrorAction SilentlyContinue
            if ($createdParent) { Remove-Item -Path $codexSkillsDir -Force -ErrorAction SilentlyContinue }
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 claude module output styles' {
    It 'junctions claude/output-styles into ~/.claude/output-styles' -Skip:(-not $IsWindows) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-claude-styles-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module claude -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '\[DRY RUN\] junction .*\.claude\\output-styles'
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 herdr module' {
    It 'dry-run links config.toml and, when herdr + an agent are present, wires the integration' {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('setup-herdr-dryrun-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tmpHome -Force | Out-Null
        $origUP = $env:USERPROFILE
        try {
            $env:USERPROFILE = $tmpHome
            $output = & pwsh -NoProfile -File $script:SetupScript -Module herdr -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '\[DRY RUN\] symlink .*herdr[\\/]config\.toml'
            # The agent-integration wiring only runs when herdr itself is on PATH; assert its
            # dry-run line only then, so CI (which has no herdr) still exercises the symlink path.
            if (Get-Command -Name herdr -ErrorAction Ignore) {
                foreach ($agent in @('claude', 'codex')) {
                    if (Get-Command -Name $agent -ErrorAction Ignore) {
                        $output | Should -Match "\[DRY RUN\] herdr integration install $agent"
                    }
                }
            }
        } finally {
            $env:USERPROFILE = $origUP
            Remove-Item -Path $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'setup.ps1 langservers module' {
    It 'names all three npm language-server packages in a dry run' {
        # The dry run must state which packages this module OWNS, not what this machine happens
        # to have — the per-binary presence check lives after the -DryRun branch on purpose, so
        # this assertion stays deterministic once the servers are actually installed here.
        $output = & pwsh -NoProfile -File $script:SetupScript -Module langservers -DryRun 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'volta install vscode-langservers-extracted'
        $output | Should -Match 'volta install yaml-language-server'
        $output | Should -Match 'volta install azure-pipelines-language-server'
        $output | Should -Not -Match "Unknown module 'langservers'"
    }

    It 'warns and skips rather than failing when the Node toolchain manager is absent' {
        # Simulating a missing toolchain means REPLACING PATH with an empty directory, not
        # shimming something into it (you cannot shim absence). pwsh itself then no longer
        # resolves from PATH, so the child is launched by absolute path from $PSHOME.
        $emptyDir = Join-Path ([IO.Path]::GetTempPath()) ('setup-langservers-nopath-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $pwshName = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
        $pwshExe = Join-Path $PSHOME $pwshName
        $origPath = $env:PATH
        try {
            $env:PATH = $emptyDir
            $output = & $pwshExe -NoProfile -File $script:SetupScript -Module langservers 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'volta not found'
        } finally {
            $env:PATH = $origPath
            Remove-Item -Path $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # The two tests above both return before the install loop (one at the -DryRun branch, one at
    # the volta guard), so without these the loop itself — the package/binary pairing, the
    # already-installed skip, and the per-package exit-code check — is never executed by the suite.
    # Driven against a fake `volta` on a stripped PATH, the same shim technique tests/psmux.Tests.ps1
    # uses for save.ps1. Stripping PATH also hides the real language-server binaries, so the
    # presence check falls through to the install branch on a machine where they ARE installed.
    Context 'install loop, driven against a shimmed volta' -Skip:(-not $IsWindows) {
        BeforeAll {
            $script:PwshExe = Join-Path $PSHOME 'pwsh.exe'
            $script:Packages = @(
                'vscode-langservers-extracted'
                'yaml-language-server'
                'azure-pipelines-language-server'
            )

            # Writes a volta.cmd that exits with $ExitCode and echoes the args it was handed, so a
            # test can assert WHICH package each invocation got, not merely that something ran.
            # Must be declared `function script:` inside BeforeAll — a bare `function` in a Context
            # body is not in scope for its It blocks under Pester 5.
            function script:New-VoltaShim ([int]$ExitCode) {
                $dir = Join-Path ([IO.Path]::GetTempPath()) ('setup-langservers-shim-' + [guid]::NewGuid())
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Set-Content -Path (Join-Path $dir 'volta.cmd') -Encoding ASCII -Value @"
@echo off
echo SHIM-CALLED %*
exit /b $ExitCode
"@
                return $dir
            }
        }

        It 'installs each package by name and reports success when volta exits 0' {
            $shimDir = New-VoltaShim -ExitCode 0
            $origPath = $env:PATH
            try {
                $env:PATH = $shimDir
                $output = & $script:PwshExe -NoProfile -File $script:SetupScript -Module langservers 2>&1 | Out-String
                $LASTEXITCODE | Should -Be 0
                foreach ($package in $script:Packages) {
                    $output | Should -Match "SHIM-CALLED install $([regex]::Escape($package))"
                    $output | Should -Match "installed $([regex]::Escape($package))"
                }
                $output | Should -Not -Match 'failed \(exit'
            } finally {
                $env:PATH = $origPath
                Remove-Item -Path $shimDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'reports each package that fails rather than reporting overall success' {
            # Story 14: a partial failure must be visible. A non-zero volta exit has to reach the
            # else branch and name the package — not be swallowed, and not abort the remaining ones.
            $shimDir = New-VoltaShim -ExitCode 1
            $origPath = $env:PATH
            try {
                $env:PATH = $shimDir
                $output = & $script:PwshExe -NoProfile -File $script:SetupScript -Module langservers 2>&1 | Out-String
                foreach ($package in $script:Packages) {
                    $output | Should -Match "volta install $([regex]::Escape($package)) failed \(exit 1\)"
                }
                $output | Should -Not -Match 'Language server: installed'
            } finally {
                $env:PATH = $origPath
                Remove-Item -Path $shimDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'setup.ps1 -Module all' {
    It 'runs the full module set in -DryRun without error (Windows-only)' -Skip:(-not $IsWindows) {
        # Non-Windows hits [Environment]::GetFolderPath('MyDocuments') returning an empty string
        # inside Install-PowerShell, which throws even under -DryRun (Join-Path with an empty
        # base path) — a genuine Windows-only API gap, not something -DryRun is meant to paper
        # over. Verified locally on Linux: `Join-Path: Cannot bind argument to parameter 'Path'
        # because it is an empty string.` So this smoke test only runs on windows-latest, which
        # is where the full module set is meant to work end to end.
        $output = & pwsh -NoProfile -File $script:SetupScript -Module all -DryRun 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Not -Match 'Unknown module'
    }

    It 'runs langservers after winget (whose curated set carries Volta) and before herdr' -Skip:(-not $IsWindows) {
        # Two ordering constraints, both enforced here rather than left to a comment: langservers
        # depends on Volta, which is part of the winget module's curated package set, and herdr must
        # stay LAST (it writes hook registrations through a settings.json the claude module
        # symlinks into the repo).
        $output = & pwsh -NoProfile -File $script:SetupScript -Module all -DryRun 2>&1 | Out-String
        $winget      = $output.IndexOf('=== winget packages')
        $langservers = $output.IndexOf('=== Language servers')
        $herdr       = $output.IndexOf('=== Herdr')
        $winget      | Should -BeGreaterThan -1
        $langservers | Should -BeGreaterThan $winget
        $herdr       | Should -BeGreaterThan $langservers
    }
}

Describe 'New-FileSymlink failure recovery' {
    BeforeAll {
        # -Module bogus keeps the top-level script from exiting early (`$Module.Count` is 1) and
        # does no real filesystem work (falls to the `default` unknown-module warn branch), so
        # it's safe to dot-source in-process to pull New-FileSymlink / Backup-Existing into this
        # Describe's scope without running any of the actual install modules.
        . $script:SetupScript -Module bogus *>$null
    }

    BeforeEach {
        $script:Tmp = Join-Path ([IO.Path]::GetTempPath()) ('symlink-restore-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null
        $script:Link = Join-Path $script:Tmp 'live.conf'
        $script:Target = Join-Path $script:Tmp 'target.conf'
        Set-Content -Path $script:Link -Value 'ORIGINAL CONTENT' -Encoding UTF8
        Set-Content -Path $script:Target -Value 'TARGET CONTENT' -Encoding UTF8
    }
    AfterEach {
        Remove-Item -Path $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'restores the original file when New-Item -ItemType SymbolicLink fails' {
        # Regression: Backup-Existing renamed the live file away BEFORE the symlink attempt.
        # When New-Item then failed (e.g. no Developer Mode on Windows), the user's real config
        # was left renamed to a .bak file with nothing in its place.
        Mock New-Item {
            throw 'A required privilege is not held by the client (simulated: no Developer Mode)'
        } -ParameterFilter { $ItemType -eq 'SymbolicLink' }

        New-FileSymlink -Link $script:Link -Target $script:Target

        (Test-Path -LiteralPath $script:Link) | Should -Be $true
        (Get-Content -LiteralPath $script:Link -Raw).Trim() | Should -Be 'ORIGINAL CONTENT'
        # No stray .bak file should be left behind once restored.
        @(Get-ChildItem -Path $script:Tmp -Filter '*.bak.*') | Should -BeNullOrEmpty
    }
}
