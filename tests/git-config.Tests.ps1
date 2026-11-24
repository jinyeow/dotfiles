#Requires -Version 7
# Tests for git/gitconfig: the config-based global hooks, the GitHub fetch/push URL split,
# and settings that must stay.
#
# Static checks read the file with `git config --file`, which does not follow includes. The
# behavioural checks run git against an isolated global config (GIT_CONFIG_GLOBAL) that
# includes the REAL git/gitconfig, with HOME pointed at a temp folder whose name has a space.
# They never touch the real ~/.gitconfig or ~/.git_templates.

# Runs at DISCOVERY time, because -Skip: and -ForEach are evaluated then.
$script:HasConfigHooks = $false
$gitRaw = (& git --version) -replace '^git version\s*', ''
if ($gitRaw -match '^(\d+)\.(\d+)')
{
    $script:HasConfigHooks = [version]::new([int]$Matches[1], [int]$Matches[2]) -ge [version]'2.54'
}

# githooks(5) event names. Other files in git/templates/hooks (ctags, the .ps1/.sh halves of
# prepare-commit-msg) are helpers that a hook script calls, so they get no stanza.
$script:GitHookEvents = @(
    'applypatch-msg', 'pre-applypatch', 'post-applypatch', 'pre-commit', 'pre-merge-commit',
    'prepare-commit-msg', 'commit-msg', 'post-commit', 'pre-rebase', 'post-checkout',
    'post-merge', 'pre-push', 'pre-receive', 'update', 'proc-receive', 'post-receive',
    'post-update', 'reference-transaction', 'push-to-checkout', 'pre-auto-gc', 'post-rewrite',
    'sendemail-validate', 'fsmonitor-watchman', 'post-index-change'
)
$script:HookScriptEvents = @(
    Get-ChildItem -Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'git/templates/hooks') -File |
        Where-Object { $script:GitHookEvents -contains $_.Name } |
        ForEach-Object { @{ HookEvent = $_.Name } }
)

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:GitConfig = Join-Path $script:RepoRoot 'git/gitconfig'

    # Returns the value of one key in git/gitconfig, or $null when it is not set.
    function Get-GitConfigValue
    {
        param([string] $Key)

        $value = & git config --file $script:GitConfig --get $Key
        if ($LASTEXITCODE -ne 0) { return $null }
        return $value
    }

    # Every git call in this file sees only an isolated global config that includes the real
    # git/gitconfig, never the machine's ~/.gitconfig. HOME is a temp folder whose name has a
    # space, which tests the quoting of "$HOME/..." in the hook commands. fsmonitor is off so
    # no daemon holds a temp repo open during cleanup.
    $script:Root = Join-Path ([IO.Path]::GetTempPath()) ('git-config-' + [guid]::NewGuid())
    $script:FakeHome = Join-Path $script:Root 'home dir'
    New-Item -ItemType Directory -Path $script:FakeHome -Force | Out-Null
    $globalConfig = Join-Path $script:Root 'global.gitconfig'
    $include = $script:GitConfig -replace '\\', '/'
    Set-Content -Path $globalConfig -Value "[include]`n    path = $include`n[core]`n    fsmonitor = false`n" -Encoding ASCII -NoNewline

    $script:SavedEnv = @{}
    foreach ($name in 'HOME', 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM', 'GIT_PAGER')
    {
        $script:SavedEnv[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    $env:HOME = $script:FakeHome
    $env:GIT_CONFIG_GLOBAL = $globalConfig
    $env:GIT_CONFIG_NOSYSTEM = '1'
    $env:GIT_PAGER = 'cat'
}

AfterAll {
    # [NullString]::Value unsets a variable that was unset before. A plain $null reaches
    # .NET as '', and an empty GIT_CONFIG_GLOBAL hides the global config from later tests.
    foreach ($name in $script:SavedEnv.Keys)
    {
        $value = if ($null -eq $script:SavedEnv[$name]) { [NullString]::Value } else { $script:SavedEnv[$name] }
        [Environment]::SetEnvironmentVariable($name, $value)
    }
    Remove-Item -Path $script:Root -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'git/gitconfig global hooks' {
    It 'sets no core.hooksPath or init.templatedir' {
        # A global core.hooksPath masks every repo's own .git/hooks, and the pre-commit
        # framework refuses to install while it is set.
        Get-GitConfigValue -Key 'core.hooksPath' | Should -BeNullOrEmpty
        Get-GitConfigValue -Key 'init.templatedir' | Should -BeNullOrEmpty
    }

    It 'has one dotfiles stanza per hook script, and no stanza without a script' -ForEach @(
        @{ Scripts = @($script:HookScriptEvents | ForEach-Object { $_.HookEvent } | Sort-Object) }
    ) {
        $Scripts.Count | Should -BeGreaterThan 0

        $stanzas = @(& git config --file $script:GitConfig --get-regexp '^hook\.dotfiles-.*\.event$' |
                ForEach-Object { ($_ -split ' ', 2)[1] } | Sort-Object)

        $stanzas | Should -Be $Scripts
    }

    It 'names the stanza for <HookEvent> after its event' -ForEach $script:HookScriptEvents {
        Get-GitConfigValue -Key "hook.dotfiles-$HookEvent.event" | Should -Be $HookEvent
    }

    It 'quotes the <HookEvent> command so the text after the first ; survives' -ForEach $script:HookScriptEvents {
        # `;` starts a comment in git config. Unquoted, the value would end at the first `;`
        # and the hook would never run the script. $HOME is quoted for paths with spaces.
        $expected = 'f="$HOME/.git_templates/hooks/' + $HookEvent + '"; test -f "$f" || exit 0; exec "$f"'
        Get-GitConfigValue -Key "hook.dotfiles-$HookEvent.command" | Should -Be $expected
    }
}

Describe 'git/gitconfig global hooks at run time' -Skip:(-not $script:HasConfigHooks) {
    BeforeAll {
        $script:FakeHooks = Join-Path $script:FakeHome '.git_templates/hooks'
        $script:Repo = Join-Path $script:Root 'repo'
        New-Item -ItemType Directory -Path $script:Repo -Force | Out-Null
        & git -C $script:Repo init -q .

        # Writes a fake hook script into the temp ~/.git_templates/hooks.
        function New-FakeHook
        {
            param([string] $HookEvent, [string] $Body)

            New-Item -ItemType Directory -Path $script:FakeHooks -Force | Out-Null
            $path = Join-Path $script:FakeHooks $HookEvent
            Set-Content -Path $path -Value "#!/bin/sh`n$Body`n" -Encoding ASCII -NoNewline
            if (Get-Command chmod -ErrorAction SilentlyContinue) { & chmod +x $path }
            return $path
        }
    }

    AfterEach {
        Remove-Item -Path (Join-Path $script:FakeHome '.git_templates') -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'lists the <HookEvent> stanza' -ForEach $script:HookScriptEvents {
        $out = & git -C $script:Repo hook list $HookEvent 2>&1 | Out-String
        $out | Should -Match "dotfiles-$HookEvent"
    }

    It 'fails open for <HookEvent> when the script is not installed' -ForEach $script:HookScriptEvents {
        # Git does not fail open on a missing command: it blocks the commit. The stanza goes
        # live as soon as the repo is pulled, before setup re-creates ~/.git_templates.
        $out = & git -C $script:Repo hook run $HookEvent 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0 -Because $out
    }

    It 'runs a present script and passes each argument once' {
        $argsFile = Join-Path $script:Root 'args.txt'
        $argsFileUnix = $argsFile -replace '\\', '/'
        New-FakeHook -HookEvent 'prepare-commit-msg' -Body "for a in `"`$@`"; do printf '%s\n' `"`$a`"; done > '$argsFileUnix'" | Out-Null

        & git -C $script:Repo hook run prepare-commit-msg -- 'msg file' 'message' 2>&1 | Out-Null

        $LASTEXITCODE | Should -Be 0
        Get-Content -Path $argsFile | Should -Be @('msg file', 'message')
    }

    It 'passes stdin through to post-rewrite' {
        $stdinFile = Join-Path $script:Root 'stdin.txt'
        $outFile = Join-Path $script:Root 'stdin-out.txt'
        Set-Content -Path $stdinFile -Value "aaa bbb`n" -Encoding ASCII -NoNewline
        New-FakeHook -HookEvent 'post-rewrite' -Body "printf '%s|' `"`$1`" > '$($outFile -replace '\\', '/')'; cat >> '$($outFile -replace '\\', '/')'" | Out-Null

        & git -C $script:Repo hook run "--to-stdin=$stdinFile" post-rewrite -- rebase 2>&1 | Out-Null

        $LASTEXITCODE | Should -Be 0
        Get-Content -Path $outFile -Raw | Should -Be "rebase|aaa bbb`n"
    }

    It 'blocks when a present script fails' {
        New-FakeHook -HookEvent 'pre-commit' -Body "echo 'HOOK RAN'; exit 1" | Out-Null

        $out = & git -C $script:Repo hook run pre-commit 2>&1 | Out-String

        $LASTEXITCODE | Should -Not -Be 0
        $out | Should -Match 'HOOK RAN' -Because 'the script must be what failed, not a spawn or parse error'
    }
}

Describe 'git/gitconfig GitHub remotes' {
    BeforeAll {
        $script:UrlRepo = Join-Path $script:Root 'url-repo'
        New-Item -ItemType Directory -Path $script:UrlRepo -Force | Out-Null
        & git -C $script:UrlRepo init -q .
    }

    It 'fetches <Url> over HTTPS and pushes it over SSH' -ForEach @(
        @{ Url = 'gh:owner/repo.git' }
        @{ Url = 'https://github.com/owner/repo.git' }
    ) {
        # Git applies insteadOf and pushInsteadOf to the original URL, so gh: takes the same
        # split as an https URL. `git remote get-url` applies both rewrites without a network.
        $remote = 'r' + [guid]::NewGuid().ToString('N')
        & git -C $script:UrlRepo config "remote.$remote.url" $Url

        & git -C $script:UrlRepo remote get-url $remote | Should -Be 'https://github.com/owner/repo.git'
        & git -C $script:UrlRepo remote get-url --push $remote | Should -Be 'git@github.com:owner/repo.git'
    }
}

Describe 'git/gitconfig kept settings' {
    It 'keeps SSH signing support' {
        Get-GitConfigValue -Key 'gpg.format' | Should -Be 'ssh'
        Get-GitConfigValue -Key 'tig.diff-options' | Should -Be '--show-signature'
    }

    It 'keeps fetch.prunetags' {
        Get-GitConfigValue -Key 'fetch.prunetags' | Should -Be 'true'
    }

    It 'includes ~/.gitconfig.local as the last entry, so its values win' {
        $last = @(& git config --file $script:GitConfig --list)[-1]
        $last | Should -Be 'include.path=~/.gitconfig.local'
    }
}

Describe 'git/gitattributes' {
    It 'uses tab indentation rules for <Path>' -ForEach @(
        @{ Path = 'main.go'; Expected = 'trailing-space,space-before-tab,indent-with-non-tab' }
        @{ Path = 'Makefile'; Expected = 'trailing-space,space-before-tab,indent-with-non-tab' }
        @{ Path = 'data.tsv'; Expected = 'trailing-space' }
    ) {
        $attributes = Join-Path $script:RepoRoot 'git/gitattributes'
        Test-Path -LiteralPath $attributes | Should -BeTrue

        $out = & git -c "core.attributesfile=$($attributes -replace '\\', '/')" -C $script:RepoRoot check-attr whitespace -- $Path
        $out | Should -Be "${Path}: whitespace: $Expected"
    }
}
