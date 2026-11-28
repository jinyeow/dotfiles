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

    It 'stores every script in <Dir> as executable' -ForEach @(
        @{ Dir = 'git/templates/hooks' }
        @{ Dir = 'git/templates/work-hooks' }
    ) {
        # The stanzas and the post-* scripts exec these files directly. On Linux and macOS a
        # file without the executable bit fails with exit 126 on every checkout, commit or push.
        $entries = @(& git -C $script:RepoRoot ls-files --stage -- $Dir)
        $entries.Count | Should -BeGreaterThan 0
        $notExecutable = @($entries | Where-Object { $_ -notmatch '^100755 ' } | ForEach-Object { ($_ -split "`t", 2)[1] })
        $notExecutable | Should -BeNullOrEmpty
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

    It 'runs the global hook and then the repository hook once each on <Command>' -ForEach @(
        @{ Command = 'commit'; HookEvent = 'pre-commit' }
        @{ Command = 'checkout'; HookEvent = 'post-checkout' }
    ) {
        # A real git command, not `git hook run`, so the test covers how git dispatches the
        # event: configured hooks first, then the repository's own .git/hooks script.
        $repo = Join-Path $script:Root ('lifecycle-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        & git -C $repo init -q -b main .
        & git -C $repo config user.email 'test@example.invalid'
        & git -C $repo config user.name 'Test'
        & git -C $repo commit -q --allow-empty -m 'base' 2>&1 | Out-Null

        $log = (Join-Path $script:Root ('order-' + [guid]::NewGuid().ToString('N') + '.txt')) -replace '\\', '/'
        New-FakeHook -HookEvent $HookEvent -Body "echo global >> '$log'" | Out-Null
        $localHook = Join-Path $repo ".git/hooks/$HookEvent"
        Set-Content -Path $localHook -Value "#!/bin/sh`necho local >> '$log'`n" -Encoding ASCII -NoNewline
        if (Get-Command chmod -ErrorAction SilentlyContinue) { & chmod +x $localHook }

        if ($Command -eq 'commit')
        {
            & git -C $repo commit -q --allow-empty -m 'lifecycle' 2>&1 | Out-Null
        }
        else
        {
            & git -C $repo checkout -q -b lifecycle 2>&1 | Out-Null
        }

        $LASTEXITCODE | Should -Be 0
        Get-Content -Path $log | Should -Be @('global', 'local')
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

Describe 'git/gitconfig-work' {
    BeforeAll {
        $script:WorkConfig = Join-Path $script:RepoRoot 'git/gitconfig-work'
    }

    It 'turns on the AI-reference scan for the repos that include it' {
        $value = & git config --file $script:WorkConfig --type=bool --get work.aiReferenceScan
        $value | Should -Be 'true'
    }

    It 'includes ~/.gitconfig-work.local as the last entry, so it can override the scan key' {
        $entries = @(& git config --file $script:WorkConfig --list)
        $entries[-1] | Should -Be 'include.path=~/.gitconfig-work.local'
        $entries | Should -Contain 'work.aireferencescan=true'
    }

    It 'defines exactly the work hook stanzas, each on its event' {
        $events = @(& git config --file $script:WorkConfig --get-regexp '^hook\..*\.event$' | Sort-Object)
        $expected = @(
            'hook.work-checks.event pre-commit'
            'hook.work-push-lint.event pre-push'
            'hook.work-push-warnings.event pre-push'
        ) | Sort-Object
        $events | Should -Be $expected
    }

    It 'quotes the <Name> command so the text after the first ; survives' -ForEach @(
        @{ Name = 'work-checks'; Script = 'checks' }
        @{ Name = 'work-push-warnings'; Script = 'push-warnings' }
        @{ Name = 'work-push-lint'; Script = 'push-lint' }
    ) {
        # The same form as the dotfiles-<event> commands in git/gitconfig, run from
        # ~/.git_templates/work-hooks. The script must exist, or the stanza would always
        # fail open.
        Test-Path -LiteralPath (Join-Path $script:RepoRoot "git/templates/work-hooks/$Script") -PathType Leaf |
            Should -BeTrue
        $expected = 'f="$HOME/.git_templates/work-hooks/' + $Script + '"; test -f "$f" || exit 0; exec "$f"'
        & git config --file $script:WorkConfig --get "hook.$Name.command" | Should -Be $expected
    }

    It 'leaves the commit-format check off' {
        # prepare-commit-msg writes the work item as a Refs: trailer, so the check would
        # block every commit it prepares. See git/README.md for how to turn it on.
        & git config --file $script:WorkConfig --get work.commitFormat | Should -BeNullOrEmpty
    }
}

Describe 'git/gitconfig-work hooks at run time' -Skip:(-not $script:HasConfigHooks) {
    BeforeAll {
        # A global config that includes git/gitconfig and git/gitconfig-work, as a work repo
        # sees them. HOME has no ~/.git_templates, which is the not-yet-installed state.
        $workGlobal = Join-Path $script:Root 'work-global.gitconfig'
        $includes = @($script:GitConfig, (Join-Path $script:RepoRoot 'git/gitconfig-work')) |
            ForEach-Object { "[include]`n    path = $($_ -replace '\\', '/')`n" }
        Set-Content -Path $workGlobal -Value (($includes -join '') + "[core]`n    fsmonitor = false`n") -Encoding ASCII -NoNewline
        $script:SavedWorkGlobal = $env:GIT_CONFIG_GLOBAL
        $env:GIT_CONFIG_GLOBAL = $workGlobal

        $script:WorkRepo = Join-Path $script:Root 'work-repo'
        New-Item -ItemType Directory -Path $script:WorkRepo -Force | Out-Null
        & git -C $script:WorkRepo init -q .
    }

    AfterAll {
        $env:GIT_CONFIG_GLOBAL = $script:SavedWorkGlobal
    }

    It 'lists <Name> for <HookEvent>' -ForEach @(
        @{ Name = 'work-checks'; HookEvent = 'pre-commit' }
        @{ Name = 'work-push-warnings'; HookEvent = 'pre-push' }
        @{ Name = 'work-push-lint'; HookEvent = 'pre-push' }
    ) {
        $out = & git -C $script:WorkRepo hook list $HookEvent 2>&1 | Out-String
        $out | Should -Match $Name
    }

    It 'fails open for <HookEvent> when the work hooks are not installed' -ForEach @(
        @{ HookEvent = 'pre-commit' }
        @{ HookEvent = 'pre-push' }
    ) {
        $out = & git -C $script:WorkRepo hook run $HookEvent 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0 -Because $out
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
