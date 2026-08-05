#Requires -Version 7
# Pester tests for tests/Resolve-TestBash.ps1 — the helper that locates a real POSIX
# bash on the test machine. $IsWindows and $HOME are ReadOnly/AllScope automatic
# variables, so branches are forced the same way AzCliAccount.Tests.ps1 redirects
# $HOME: Set-Variable -Force, saved and restored per test. Get-Command and Test-Path
# are mocked so no real filesystem or PATH state leaks into the assertions.

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot 'Resolve-TestBash.ps1'
    . $scriptPath
}

Describe 'Resolve-TestBash' {
    BeforeEach {
        $script:origIsWindows = $IsWindows
    }

    AfterEach {
        Set-Variable -Name IsWindows -Value $script:origIsWindows -Force -Scope Global
    }

    Context 'non-Windows' {
        It 'returns whatever bash resolves to on PATH' {
            Set-Variable -Name IsWindows -Value $false -Force -Scope Global
            Mock Get-Command {
                [pscustomobject]@{ Source = '/usr/bin/bash' }
            } -ParameterFilter { $Name -eq 'bash' -and $CommandType -eq 'Application' }

            Resolve-TestBash | Should -Be '/usr/bin/bash'
        }
    }

    Context 'Windows, git.exe found under cmd\' {
        It 'derives Git for Windows bash from the git.exe install root' {
            Set-Variable -Name IsWindows -Value $true -Force -Scope Global
            # Built via Join-Path, not a hardcoded backslash literal, so the expected
            # value matches production's own Join-Path output regardless of the host
            # OS's path-separator convention — this test forces $IsWindows to exercise
            # the Windows branch on any CI host, and a literal would silently mismatch
            # on a non-Windows runner where Join-Path joins with '/'.
            [string]$expected = Join-Path 'C:\Program Files\Git' 'bin' 'bash.exe'
            Mock Get-Command {
                [pscustomobject]@{ Source = 'C:\Program Files\Git\cmd\git.exe' }
            } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }
            Mock Test-Path {
                $LiteralPath -eq $expected
            }

            Resolve-TestBash | Should -Be $expected
        }
    }

    Context 'Windows, git.exe is a shim with no bin\bash.exe' {
        It 'falls through to the $env:ProgramFiles default install root' {
            Set-Variable -Name IsWindows -Value $true -Force -Scope Global
            $origProgramFiles = $env:ProgramFiles
            try {
                $env:ProgramFiles = 'C:\Program Files'
                # See the comment in the previous Context — Join-Path-derived, not literal.
                [string]$expected = Join-Path $env:ProgramFiles 'Git' 'bin' 'bash.exe'
                Mock Get-Command {
                    [pscustomobject]@{ Source = 'C:\Users\me\scoop\shims\git.exe' }
                } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }
                Mock Test-Path {
                    $LiteralPath -eq $expected
                }

                Resolve-TestBash | Should -Be $expected
            } finally {
                $env:ProgramFiles = $origProgramFiles
            }
        }
    }

    Context 'Windows, no git.exe and no ProgramFiles default, PATH has both WSL and a real bash' {
        It 'skips the WSL launcher entries and returns the first real bash on PATH' {
            Set-Variable -Name IsWindows -Value $true -Force -Scope Global
            $origProgramFiles = $env:ProgramFiles
            try {
                $env:ProgramFiles = 'C:\Program Files'
                Mock Get-Command {
                    $null
                } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }
                Mock Get-Command {
                    @(
                        [pscustomobject]@{ Source = 'C:\Windows\System32\bash.exe' }
                        [pscustomobject]@{ Source = 'C:\Users\me\WindowsApps\bash.exe' }
                        [pscustomobject]@{ Source = 'D:\tools\PortableGit\bin\bash.exe' }
                    )
                } -ParameterFilter { $Name -eq 'bash' -and $CommandType -eq 'Application' -and $All }
                Mock Test-Path {
                    $LiteralPath -eq 'D:\tools\PortableGit\bin\bash.exe'
                }

                Resolve-TestBash | Should -Be 'D:\tools\PortableGit\bin\bash.exe'
            } finally {
                $env:ProgramFiles = $origProgramFiles
            }
        }

        It 'rejects a WindowsApps-rooted candidate even without the exact \Microsoft\WindowsApps\ segment' {
            Set-Variable -Name IsWindows -Value $true -Force -Scope Global
            $origProgramFiles = $env:ProgramFiles
            try {
                # Empty ProgramFiles so the default-install-root fallback never fires,
                # keeping this test focused on the PATH-scan exclusion.
                $env:ProgramFiles = ''
                Mock Get-Command {
                    $null
                } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }
                Mock Get-Command {
                    @(
                        [pscustomobject]@{ Source = 'C:\Users\me\WindowsApps\bash.exe' }
                        [pscustomobject]@{ Source = 'D:\tools\PortableGit\bin\bash.exe' }
                    )
                } -ParameterFilter { $Name -eq 'bash' -and $CommandType -eq 'Application' -and $All }
                # Both candidates "exist" on disk; only the exclusion logic keeps the
                # WindowsApps one from being returned.
                Mock Test-Path { $true }

                Resolve-TestBash | Should -Be 'D:\tools\PortableGit\bin\bash.exe'
            } finally {
                $env:ProgramFiles = $origProgramFiles
            }
        }
    }

    Context 'Windows, nothing found anywhere' {
        It 'returns $null instead of guessing' {
            Set-Variable -Name IsWindows -Value $true -Force -Scope Global
            $origProgramFiles = $env:ProgramFiles
            try {
                $env:ProgramFiles = ''
                Mock Get-Command {
                    $null
                } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }
                Mock Get-Command {
                    @([pscustomobject]@{ Source = 'C:\Windows\System32\bash.exe' })
                } -ParameterFilter { $Name -eq 'bash' -and $CommandType -eq 'Application' -and $All }
                Mock Test-Path { $false }

                Resolve-TestBash | Should -BeNullOrEmpty
            } finally {
                $env:ProgramFiles = $origProgramFiles
            }
        }
    }

    Context 'Windows, git resolves to an alias/function (no real .Source)' {
        It 'falls through instead of returning a broken bash path' {
            Set-Variable -Name IsWindows -Value $true -Force -Scope Global
            $origProgramFiles = $env:ProgramFiles
            try {
                $env:ProgramFiles = 'C:\Program Files'
                [string]$expected = Join-Path $env:ProgramFiles 'Git' 'bin' 'bash.exe'
                Mock Get-Command {
                    [pscustomobject]@{ Source = '' }
                } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }
                Mock Test-Path {
                    $LiteralPath -eq $expected
                }

                Resolve-TestBash | Should -Be $expected
            } finally {
                $env:ProgramFiles = $origProgramFiles
            }
        }
    }

    Context 'a boundary call throws unexpectedly' {
        It 'never throws — returns $null instead of propagating the exception' {
            Set-Variable -Name IsWindows -Value $true -Force -Scope Global
            $origProgramFiles = $env:ProgramFiles
            try {
                # Isolate every remaining strategy too, so this test proves the
                # no-throw contract rather than incidentally finding a real bash
                # installed on the machine running the suite.
                $env:ProgramFiles = ''
                Mock Get-Command {
                    throw 'simulated PATH resolution failure'
                } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }
                Mock Get-Command {
                    @()
                } -ParameterFilter { $Name -eq 'bash' -and $CommandType -eq 'Application' -and $All }

                { Resolve-TestBash } | Should -Not -Throw
                Resolve-TestBash | Should -BeNullOrEmpty
            } finally {
                $env:ProgramFiles = $origProgramFiles
            }
        }

        It 'still tries the ProgramFiles fallback when git-derivation throws' {
            Set-Variable -Name IsWindows -Value $true -Force -Scope Global
            $origProgramFiles = $env:ProgramFiles
            try {
                $env:ProgramFiles = 'C:\Program Files'
                [string]$expected = Join-Path $env:ProgramFiles 'Git' 'bin' 'bash.exe'
                Mock Get-Command {
                    throw 'simulated git-derivation failure'
                } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }
                Mock Test-Path {
                    $LiteralPath -eq $expected
                }

                Resolve-TestBash | Should -Be $expected
            } finally {
                $env:ProgramFiles = $origProgramFiles
            }
        }
    }
}
