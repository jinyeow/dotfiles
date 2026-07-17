#Requires -Version 7
# Pester tests for setup.ps1's bat module, focused on Catppuccin theme provisioning
# (Install-Bat / Install-BatCatppuccinTheme). Runs the installer as a child pwsh process
# driven by a fake `bat` on PATH, so these never touch a real bat install or the network.
#
# Deliberately NOT covered here: the successful-download path (Invoke-WebRequest actually
# fetching the .tmTheme files and the resulting `bat cache --build`) — that needs real network
# access to raw.githubusercontent.com, which CI/sandboxed environments may not have. The
# dry-run/backup/no-bat guards and the "already present -> no download, no cache rebuild"
# skip logic are all reachable without network and are what's pinned here.

BeforeAll {
    $script:SetupScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'setup.ps1'

    # Writes a fake `bat` onto PATH (an extensionless shebang script off Windows, a .cmd on
    # Windows — same split tests/setup-git.Tests.ps1 uses for its `git` shim, since there is
    # no PATHEXT resolution for a bare `bat` off Windows). It answers `bat --config-dir` with
    # $env:BAT_SHIM_CONFIGDIR and appends every invocation's args to $env:BAT_SHIM_LOG, so a
    # test can assert whether `bat cache --build` ran without needing a real bat.
    function script:New-BatShim ([string]$ShimDir) {
        New-Item -ItemType Directory -Path $ShimDir -Force | Out-Null
        if ($IsWindows) {
            $body = @'
@echo off
if "%~1"=="--config-dir" (
    echo %BAT_SHIM_CONFIGDIR%
    exit /b 0
)
echo %* >> "%BAT_SHIM_LOG%"
exit /b 0
'@
            Set-Content -Path (Join-Path $ShimDir 'bat.cmd') -Value $body -Encoding ASCII
        } else {
            $shimPath = Join-Path $ShimDir 'bat'
            $body = @'
#!/bin/sh
if [ "$1" = "--config-dir" ]; then
    echo "$BAT_SHIM_CONFIGDIR"
    exit 0
fi
echo "$@" >> "$BAT_SHIM_LOG"
exit 0
'@
            Set-Content -Path $shimPath -Value $body -Encoding ASCII
            chmod +x $shimPath
        }
    }

    # Strips any directory containing a `bat`/`bat.cmd`/`bat.exe` from PATH, so the
    # "bat not found" guard test is not at the mercy of whether the host machine has bat.
    function script:Get-PathWithoutBat {
        $sep = [IO.Path]::PathSeparator
        ($env:PATH -split [regex]::Escape($sep)) | Where-Object {
            -not (Test-Path (Join-Path $_ 'bat')) -and
            -not (Test-Path (Join-Path $_ 'bat.cmd')) -and
            -not (Test-Path (Join-Path $_ 'bat.exe'))
        } | Join-String -Separator $sep
    }
}

Describe 'setup.ps1 bat module' {
    BeforeEach {
        $script:OrigPath = $env:PATH
        $script:ShimDir = Join-Path ([IO.Path]::GetTempPath()) ('bat-shim-' + [guid]::NewGuid())
        $script:ConfigDir = Join-Path ([IO.Path]::GetTempPath()) ('bat-config-' + [guid]::NewGuid())
        $script:LogFile = Join-Path ([IO.Path]::GetTempPath()) ('bat-log-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null
        New-Item -ItemType File -Path $script:LogFile -Force | Out-Null
        New-BatShim -ShimDir $script:ShimDir

        $env:BAT_SHIM_CONFIGDIR = $script:ConfigDir
        $env:BAT_SHIM_LOG = $script:LogFile
    }
    AfterEach {
        $env:PATH = $script:OrigPath
        Remove-Item Env:\BAT_SHIM_CONFIGDIR, Env:\BAT_SHIM_LOG -ErrorAction SilentlyContinue
        Remove-Item -Path $script:ShimDir, $script:ConfigDir, $script:LogFile -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'warns and does not attempt theme provisioning when bat is not on PATH' {
        $env:PATH = Get-PathWithoutBat
        $output = & pwsh -NoProfile -File $script:SetupScript -Module bat -DryRun 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match '=== bat'
        $output | Should -Match 'bat not found'
        $output | Should -Not -Match 'Catppuccin'
        (Get-Content -Path $script:LogFile -Raw -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
    }

    It 'skips theme provisioning entirely under -Backup' {
        $env:PATH = $script:ShimDir + [IO.Path]::PathSeparator + $env:PATH
        $output = & pwsh -NoProfile -File $script:SetupScript -Module bat -Backup 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'bat is installed'
        $output | Should -Match 'Backup mode — skipping theme provisioning'
        $output | Should -Not -Match 'Catppuccin'
        # The shim was never asked for --config-dir, so no themes dir should exist.
        (Test-Path (Join-Path $script:ConfigDir 'themes')) | Should -Be $false
    }

    It 'reports what it would do under -DryRun without downloading or creating the themes dir' {
        $env:PATH = $script:ShimDir + [IO.Path]::PathSeparator + $env:PATH
        $output = & pwsh -NoProfile -File $script:SetupScript -Module bat -DryRun 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match '\[DRY RUN\] would download .*Catppuccin%20Mocha\.tmTheme'
        $output | Should -Match '\[DRY RUN\] would download .*Catppuccin%20Latte\.tmTheme'
        $output | Should -Match '\[DRY RUN\] would run: bat cache --build'
        (Test-Path (Join-Path $script:ConfigDir 'themes')) | Should -Be $false
        (Get-Content -Path $script:LogFile -Raw -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
    }

    It 'skips already-present themes and does not rebuild the cache when nothing was added' {
        $themesDir = Join-Path $script:ConfigDir 'themes'
        New-Item -ItemType Directory -Path $themesDir -Force | Out-Null
        Set-Content -Path (Join-Path $themesDir 'Catppuccin Mocha.tmTheme') -Value 'stub' -Encoding UTF8
        Set-Content -Path (Join-Path $themesDir 'Catppuccin Latte.tmTheme') -Value 'stub' -Encoding UTF8

        $env:PATH = $script:ShimDir + [IO.Path]::PathSeparator + $env:PATH
        $output = & pwsh -NoProfile -File $script:SetupScript -Module bat 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'Catppuccin Mocha\.tmTheme \(already present\)'
        $output | Should -Match 'Catppuccin Latte\.tmTheme \(already present\)'
        $output | Should -Not -Match 'Downloaded:'
        $output | Should -Not -Match 'Rebuilt bat theme cache'
        # `cache --build` must not have been invoked: nothing new was added.
        (Get-Content -Path $script:LogFile -Raw -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
    }
}
