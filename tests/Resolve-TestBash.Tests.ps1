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
            Mock Get-Command {
                [pscustomobject]@{ Source = 'C:\Program Files\Git\cmd\git.exe' }
            } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }
            Mock Test-Path {
                $LiteralPath -eq 'C:\Program Files\Git\bin\bash.exe'
            }

            Resolve-TestBash | Should -Be 'C:\Program Files\Git\bin\bash.exe'
        }
    }

    Context 'Windows, git.exe is a shim with no bin\bash.exe' {
        It 'falls through to the $env:ProgramFiles default install root' {
            Set-Variable -Name IsWindows -Value $true -Force -Scope Global
            $origProgramFiles = $env:ProgramFiles
            try {
                $env:ProgramFiles = 'C:\Program Files'
                Mock Get-Command {
                    [pscustomobject]@{ Source = 'C:\Users\me\scoop\shims\git.exe' }
                } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }
                Mock Test-Path {
                    $LiteralPath -eq 'C:\Program Files\Git\bin\bash.exe'
                }

                Resolve-TestBash | Should -Be 'C:\Program Files\Git\bin\bash.exe'
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
                Mock Get-Command {
                    [pscustomobject]@{ Source = '' }
                } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }
                Mock Test-Path {
                    $LiteralPath -eq 'C:\Program Files\Git\bin\bash.exe'
                }

                Resolve-TestBash | Should -Be 'C:\Program Files\Git\bin\bash.exe'
            } finally {
                $env:ProgramFiles = $origProgramFiles
            }
        }
    }

    Context 'a boundary call throws unexpectedly' {
        It 'never throws — returns $null instead of propagating the exception' {
            Set-Variable -Name IsWindows -Value $true -Force -Scope Global
            Mock Get-Command {
                throw 'simulated PATH resolution failure'
            } -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }

            { Resolve-TestBash } | Should -Not -Throw
            Resolve-TestBash | Should -BeNullOrEmpty
        }
    }
}
