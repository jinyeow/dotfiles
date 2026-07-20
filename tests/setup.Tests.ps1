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
