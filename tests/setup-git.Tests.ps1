#Requires -Version 7
# Pester tests for setup.ps1's git module. Runs the installer as a child pwsh in
# -DryRun so it never mutates the machine.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    $script:SetupScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'setup.ps1'
}

Describe 'setup.ps1 git module' {
    It 'runs the git module in -DryRun, installs ~/.gitattributes and wires the hook links' {
        $output = & pwsh -NoProfile -File $script:SetupScript -Module git -DryRun 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match '=== Git'
        # There are no work-only hooks to link.
        $output | Should -Not -Match '\.git_work_hooks'
        # core.attributesfile points at ~/.gitattributes, and the config-based hooks in
        # git/gitconfig run scripts under ~/.git_templates/hooks.
        $output | Should -Match 'git.gitattributes -> .*\.gitattributes'
        $output | Should -Match '\.git_templates -> .*git.templates'
    }
}

Describe 'setup.ps1 Test-GitHookSupport' {
    # Config-based hooks (the [hook "dotfiles-<event>"] stanzas in gitconfig) need
    # Git >= 2.54; below that they are ignored
    # SILENTLY, so the global hooks enforce nothing with no error.
    # The install-time warning is the only signal, which makes the version gate worth testing.
    #
    # Driven by a fake `git` on PATH so each branch runs regardless of the machine's real
    # git (CI's git version must not decide the result). Assertions check the section header
    # too, so an early crash in the module cannot false-green the message checks.
    It 'reports <Expected> for <Case>' -ForEach @(
        @{ Case = 'git 2.39.2 (Debian bookworm)'; Version = 'git version 2.39.2'; Expected = 'a warning'; Match = 'older than 2\.54.*global hooks \(gitleaks, AI-reference scan\) do not run' }
        @{ Case = 'git 2.53.9 (just below the gate)'; Version = 'git version 2.53.9'; Expected = 'a warning'; Match = 'older than 2\.54' }
        @{ Case = 'git 2.54.0 (exactly the gate)'; Version = 'git version 2.54.0'; Expected = 'support'; Match = 'supports config-based hooks' }
        @{ Case = 'git 2.55.0.windows.2'; Version = 'git version 2.55.0.windows.2'; Expected = 'support'; Match = 'supports config-based hooks' }
        @{ Case = 'git 3.0.0 (future major)'; Version = 'git version 3.0.0'; Expected = 'support'; Match = 'supports config-based hooks' }
        @{ Case = 'unparseable version output'; Version = 'git version banana'; Expected = 'a warning'; Match = 'Could not parse git version' }
    ) {
        $shimDir = Join-Path ([IO.Path]::GetTempPath()) ('git-hooktest-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
        if ($IsWindows)
        {
            Set-Content -Path (Join-Path $shimDir 'git.cmd') -Value "@echo off`r`necho $Version" -Encoding ASCII
        }
        else
        {
            # No .cmd/PATHEXT resolution off Windows — an extensionless script with a shebang,
            # made executable, is what `Get-Command git` / `& git` will actually find on PATH.
            $shimPath = Join-Path $shimDir 'git'
            Set-Content -Path $shimPath -Value "#!/bin/sh`necho `"$Version`"" -Encoding ASCII
            chmod +x $shimPath
        }

        $origPath = $env:PATH
        try
        {
            $env:PATH = $shimDir + [IO.Path]::PathSeparator + $env:PATH
            $output = & pwsh -NoProfile -File $script:SetupScript -Module git -DryRun 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match '=== Git'
            $output | Should -Match $Match
        }
        finally
        {
            $env:PATH = $origPath
            Remove-Item -Path $shimDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
