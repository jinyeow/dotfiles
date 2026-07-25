#Requires -Version 7
# Pester tests for powershell/Profile/AzCliAccount.ps1 — the az CLI account switch
# (azw/azp). The file defines functions with no load-time side effects, so it is
# dot-sourced directly (unlike the profile, which is AST-lifted). `az` is shadowed by
# a function stub so the best-effort `az account show` announce never hits the network
# or requires az to be installed. Assertions are on STATE — $env:AZURE_CONFIG_DIR, the
# state-file content, and the cleared $global:__AdoAccessToken — never on az invocation.

BeforeAll {
    $scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'powershell' 'Profile' 'AzCliAccount.ps1'
    . $scriptPath

    # Shadow the az CLI: a function always beats an external application by command
    # precedence, so this keeps the announce offline whether or not az is installed.
    function az { }
}

Describe 'AzCliAccount' {
    BeforeEach {
        # Redirect $HOME to a fresh, isolated dir so path resolution (state file +
        # personal config dir) is scoped per test and no state file leaks across tests.
        # $HOME is a ReadOnly, AllScope automatic variable — AllScope defeats a child-scope
        # shadow, so the only way to redirect it is Set-Variable -Force (which overrides
        # ReadOnly), saved and restored in AfterEach. Set-Variable (not `$HOME = …`) also
        # sidesteps the PSAvoidAssignmentToAutomaticVariable analyzer error a direct
        # assignment raises.
        $script:origHome = $HOME
        Set-Variable -Name HOME -Value (Join-Path $TestDrive ([guid]::NewGuid().ToString())) -Force
        New-Item -ItemType Directory -Path $HOME -Force | Out-Null

        # Save mutated global state; the functions overwrite these.
        $script:origConfigDir = $env:AZURE_CONFIG_DIR
        $script:origAdoToken = $global:__AdoAccessToken
    }

    AfterEach {
        Set-Variable -Name HOME -Value $script:origHome -Force
        if ($null -eq $script:origConfigDir) {
            Remove-Item Env:AZURE_CONFIG_DIR -ErrorAction Ignore
        } else {
            $env:AZURE_CONFIG_DIR = $script:origConfigDir
        }
        $global:__AdoAccessToken = $script:origAdoToken
    }

    Context 'Switch-AzPersonal' {
        It 'points AZURE_CONFIG_DIR at the personal config dir' {
            Switch-AzPersonal
            $env:AZURE_CONFIG_DIR | Should -Be (Join-Path $HOME '.azure-personal')
        }

        It 'persists "personal" to the state file' {
            Switch-AzPersonal
            $state = (Get-Content -LiteralPath (Join-Path $HOME '.azure-active-profile')).Trim()
            $state | Should -Be 'personal'
        }

        It 'clears the cached ADO access token so prr re-auths against the new account' {
            $global:__AdoAccessToken = @{ Token = 'stale'; Expires = [DateTimeOffset]::MaxValue }
            Switch-AzPersonal
            $global:__AdoAccessToken | Should -BeNullOrEmpty
        }
    }

    Context 'Switch-AzWork' {
        It 'unsets AZURE_CONFIG_DIR, persists "work", and clears the cached token' {
            # Pre-set both so the unset and the clear are observable transitions.
            $env:AZURE_CONFIG_DIR = Join-Path $HOME '.azure-personal'
            $global:__AdoAccessToken = @{ Token = 'stale'; Expires = [DateTimeOffset]::MaxValue }

            Switch-AzWork

            $env:AZURE_CONFIG_DIR | Should -BeNullOrEmpty
            (Get-Content -LiteralPath (Join-Path $HOME '.azure-active-profile')).Trim() | Should -Be 'work'
            $global:__AdoAccessToken | Should -BeNullOrEmpty
        }
    }

    Context 'Restore-AzActiveProfile' {
        It 'sets AZURE_CONFIG_DIR to the personal dir when the state says "personal"' {
            Set-Content -LiteralPath (Join-Path $HOME '.azure-active-profile') -Value 'personal'
            Restore-AzActiveProfile
            $env:AZURE_CONFIG_DIR | Should -Be (Join-Path $HOME '.azure-personal')
        }

        It 'actively unsets a pre-set AZURE_CONFIG_DIR when the state says "work"' {
            # An inherited AZURE_CONFIG_DIR must not survive a "work" state — restore must
            # unset it, not merely skip.
            $env:AZURE_CONFIG_DIR = Join-Path $HOME '.azure-personal'
            Set-Content -LiteralPath (Join-Path $HOME '.azure-active-profile') -Value 'work'
            Restore-AzActiveProfile
            $env:AZURE_CONFIG_DIR | Should -BeNullOrEmpty
        }

        It 'unsets a pre-set AZURE_CONFIG_DIR when the state file is missing' {
            # Fresh $HOME has no state file; an inherited AZURE_CONFIG_DIR must not survive.
            $env:AZURE_CONFIG_DIR = Join-Path $HOME '.azure-personal'
            Restore-AzActiveProfile
            $env:AZURE_CONFIG_DIR | Should -BeNullOrEmpty
        }
    }
}
