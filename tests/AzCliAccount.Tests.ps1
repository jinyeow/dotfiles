#Requires -Version 7
# Pester tests for powershell/Profile/AzCliAccount.ps1 — the named az profile switcher
# (azs). The file defines functions with no load-time side effects, so it is dot-sourced
# directly (unlike the profile, which is AST-lifted). `az` is shadowed by a function stub
# so the best-effort `az account show` announce never hits the network or requires az to
# be installed. Assertions are on STATE — $env:AZURE_CONFIG_DIR, $env:AZURE_EXTENSION_DIR,
# the state-file content, and the cleared $global:__AdoAccessToken — never on az
# invocation. All identities in fixtures are fake: this is a public repo.

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
        # profile dirs) is scoped per test and no state file leaks across tests.
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
        $script:origExtensionDir = $env:AZURE_EXTENSION_DIR
        $script:origAdoToken = $global:__AdoAccessToken
    }

    AfterEach {
        Set-Variable -Name HOME -Value $script:origHome -Force
        if ($null -eq $script:origConfigDir) {
            Remove-Item Env:AZURE_CONFIG_DIR -ErrorAction Ignore
        } else {
            $env:AZURE_CONFIG_DIR = $script:origConfigDir
        }
        if ($null -eq $script:origExtensionDir) {
            Remove-Item Env:AZURE_EXTENSION_DIR -ErrorAction Ignore
        } else {
            $env:AZURE_EXTENSION_DIR = $script:origExtensionDir
        }
        $global:__AdoAccessToken = $script:origAdoToken
    }

    Context 'Switch-AzProfile with a profile name' {
        It 'points AZURE_CONFIG_DIR at the named profile dir' {
            Switch-AzProfile -Name work
            $env:AZURE_CONFIG_DIR | Should -Be (Join-Path $HOME '.azure-profiles' 'work')
        }

        It 'creates the profile dir when it does not exist' {
            Switch-AzProfile -Name work
            Test-Path -LiteralPath (Join-Path $HOME '.azure-profiles' 'work') | Should -BeTrue
        }

        It 'persists the profile name to the state file' {
            Switch-AzProfile -Name work
            $state = (Get-Content -LiteralPath (Join-Path $HOME '.azure-active-profile')).Trim()
            $state | Should -Be 'work'
        }

        It 'clears the cached ADO access token so prr re-auths against the new account' {
            $global:__AdoAccessToken = @{ Token = 'stale'; Expires = [DateTimeOffset]::MaxValue }
            Switch-AzProfile -Name work
            $global:__AdoAccessToken | Should -BeNullOrEmpty
        }
    }

    Context 'Switch-AzProfile -Name default' {
        It 'unsets AZURE_CONFIG_DIR, persists "default", and clears the cached token' {
            # Pre-set both so the unset and the clear are observable transitions.
            $env:AZURE_CONFIG_DIR = Join-Path $HOME '.azure-profiles' 'work'
            $global:__AdoAccessToken = @{ Token = 'stale'; Expires = [DateTimeOffset]::MaxValue }

            Switch-AzProfile -Name default

            $env:AZURE_CONFIG_DIR | Should -BeNullOrEmpty
            (Get-Content -LiteralPath (Join-Path $HOME '.azure-active-profile')).Trim() | Should -Be 'default'
            $global:__AdoAccessToken | Should -BeNullOrEmpty
        }

        It 'creates no profile dir for the reserved name' {
            # `default` IS az's own ~/.azure — a ~/.azure-profiles/default dir would be a
            # second, never-used config dir that the picker would then offer.
            Switch-AzProfile -Name default
            Test-Path -LiteralPath (Join-Path $HOME '.azure-profiles' 'default') | Should -BeFalse
        }
    }

    Context 'Switch-AzProfile with an invalid name' {
        # A name becomes a directory under ~/.azure-profiles, so a separator or a
        # traversal segment must be rejected before anything is written or set.
        It 'throws and mutates nothing for <_>' -ForEach @('bad/../name', 'has space', '..\evil', '-leading') {
            $preset = Join-Path $HOME '.azure-profiles' 'work'
            $env:AZURE_CONFIG_DIR = $preset
            $stateFile = Join-Path $HOME '.azure-active-profile'
            Set-Content -LiteralPath $stateFile -Value 'work'

            { Switch-AzProfile -Name $_ } | Should -Throw

            $env:AZURE_CONFIG_DIR | Should -Be $preset
            (Get-Content -LiteralPath $stateFile).Trim() | Should -Be 'work'
        }
    }

    Context 'Restore-AzActiveProfile' {
        It 'sets AZURE_CONFIG_DIR to the named profile dir even when that dir does not exist' {
            # Phase 1 does no existence check — a missing dir just means az sees an empty
            # config until the user logs in, and a second FS touch buys nothing.
            Set-Content -LiteralPath (Join-Path $HOME '.azure-active-profile') -Value 'work'
            Restore-AzActiveProfile
            $env:AZURE_CONFIG_DIR | Should -Be (Join-Path $HOME '.azure-profiles' 'work')
            Test-Path -LiteralPath $env:AZURE_CONFIG_DIR | Should -BeFalse
        }

        It 'actively unsets a pre-set AZURE_CONFIG_DIR when the state is <name>' -ForEach @(
            @{ Name = 'default'; Content = 'default' }
            @{ Name = 'empty'; Content = '' }
            @{ Name = 'an invalid token'; Content = '..\evil' }
        ) {
            # An inherited AZURE_CONFIG_DIR from a parent process must not survive —
            # restore must unset it, not merely skip.
            $env:AZURE_CONFIG_DIR = Join-Path $HOME '.azure-profiles' 'work'
            Set-Content -LiteralPath (Join-Path $HOME '.azure-active-profile') -Value $Content
            Restore-AzActiveProfile
            # Test-Path, not -BeNullOrEmpty: the latter also passes when the variable
            # still exists holding an empty string, which is a different state from
            # removed and not the one this contract promises.
            Test-Path Env:AZURE_CONFIG_DIR | Should -BeFalse
        }

        It 'unsets a pre-set AZURE_CONFIG_DIR when the state file is missing' {
            # Fresh $HOME has no state file; an inherited AZURE_CONFIG_DIR must not survive.
            $env:AZURE_CONFIG_DIR = Join-Path $HOME '.azure-profiles' 'work'
            Restore-AzActiveProfile
            Test-Path Env:AZURE_CONFIG_DIR | Should -BeFalse
        }

        It 'clears the cached ADO access token when the state is <name>' -ForEach @(
            @{ Name = 'a named profile'; Content = 'work' }
            @{ Name = 'default'; Content = 'default' }
            @{ Name = 'an invalid token'; Content = '..\evil' }
        ) {
            # Restore switches accounts just as Switch-AzProfile does, so it owes the same
            # token clear. A fresh shell has no cached token, but `. $PROFILE` in a session
            # that already ran prr does — and after another shell rewrote the state file it
            # would otherwise list the PREVIOUS account's PRs from the stale cached token.
            $global:__AdoAccessToken = @{ Token = 'stale'; Expires = [DateTimeOffset]::MaxValue }
            Set-Content -LiteralPath (Join-Path $HOME '.azure-active-profile') -Value $Content
            Restore-AzActiveProfile
            $global:__AdoAccessToken | Should -BeNullOrEmpty
        }

        It 'points AZURE_EXTENSION_DIR at the shared extension store when the state is <name>' -ForEach @(
            @{ Name = 'a named profile'; Content = 'work' }
            @{ Name = 'default'; Content = 'default' }
        ) {
            # Without this a non-default profile sees ZERO extensions and az devops /
            # az graph break. One shared store for every profile, set on every path.
            Set-Content -LiteralPath (Join-Path $HOME '.azure-active-profile') -Value $Content
            Restore-AzActiveProfile
            $env:AZURE_EXTENSION_DIR | Should -Be (Join-Path $HOME '.azure' 'cliextensions')
        }
    }

    Context 'Get-AzProfileIdentity' {
        # Feeds the fzf picker's preview column. It reads azureProfile.json as a plain
        # file — never an `az` process — so the preview costs nothing per keystroke.
        # Every identity below is fake: this is a public repo.
        It 'reports the cached account of a named profile' {
            $dir = Join-Path $HOME '.azure-profiles' 'work'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            @{
                subscriptions = @(
                    @{ name = 'Example Subscription'; isDefault = $true; user = @{ name = 'user@example.com' } }
                )
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $dir 'azureProfile.json')

            Get-AzProfileIdentity -Name 'work' | Should -BeLike '*user@example.com*'
        }

        It 'reports the cached account of the default profile from az''s own ~/.azure' {
            $dir = Join-Path $HOME '.azure'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            @{
                subscriptions = @(
                    @{ name = 'Example Subscription'; isDefault = $true; user = @{ name = 'other@example.com' } }
                )
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $dir 'azureProfile.json')

            Get-AzProfileIdentity -Name 'default' | Should -BeLike '*other@example.com*'
        }

        It 'falls back to subscription names when no entry carries a user (service principal logins)' {
            $dir = Join-Path $HOME '.azure-profiles' 'work'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            @{
                subscriptions = @(@{ name = 'Example Subscription'; isDefault = $true })
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $dir 'azureProfile.json')

            # Logged in, just not with a user identity — must not read as "not logged in".
            Get-AzProfileIdentity -Name 'work' | Should -BeLike '*Example Subscription*'
        }

        It 'reports the login hint when the profile has no azureProfile.json' {
            Get-AzProfileIdentity -Name 'work' | Should -Be 'not logged in — run: az login'
        }

        It 'reports the login hint when azureProfile.json is unparsable' {
            $dir = Join-Path $HOME '.azure-profiles' 'work'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $dir 'azureProfile.json') -Value 'not json {'

            Get-AzProfileIdentity -Name 'work' | Should -Be 'not logged in — run: az login'
        }
    }

    Context 'Switch-AzProfile with no name' {
        # The picker itself is interactive (bare fzf), so it is mocked at that boundary;
        # what is asserted is the resulting state, not that the picker was called.
        It 'switches to the picked profile' {
            Mock Select-AzProfileName { 'personal' }
            Switch-AzProfile
            $env:AZURE_CONFIG_DIR | Should -Be (Join-Path $HOME '.azure-profiles' 'personal')
        }

        It 'throws rather than opening the picker when -Name is supplied but empty' {
            # `azs ''` from a script or a mistyped expansion is a bug, not a request for
            # the interactive picker — only an omitted -Name opens fzf.
            Mock Select-AzProfileName { 'personal' }
            { Switch-AzProfile -Name '' } | Should -Throw
        }

        It 'changes nothing when the pick is cancelled' {
            Mock Select-AzProfileName { '' }
            $preset = Join-Path $HOME '.azure-profiles' 'work'
            $env:AZURE_CONFIG_DIR = $preset
            $global:__AdoAccessToken = @{ Token = 'stale'; Expires = [DateTimeOffset]::MaxValue }

            Switch-AzProfile

            $env:AZURE_CONFIG_DIR | Should -Be $preset
            $global:__AdoAccessToken | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath (Join-Path $HOME '.azure-active-profile') | Should -BeFalse
        }
    }

    Context 'Aliases' {
        It 'exposes azs for Switch-AzProfile' {
            (Get-Alias azs).ResolvedCommandName | Should -Be 'Switch-AzProfile'
        }

        It 'no longer defines the two-account switcher <_>' -ForEach @(
            'Switch-AzWork', 'Switch-AzPersonal', 'azw', 'azp'
        ) {
            # Asserted against the FILE, not the session: an interactive shell has the
            # installed profile's old aliases loaded, which would flake a Get-Alias check
            # while CI (-NoProfile) passed.
            $source = Get-Content -LiteralPath $scriptPath -Raw
            $source | Should -Not -Match "\b$_\b"
        }
    }
}
