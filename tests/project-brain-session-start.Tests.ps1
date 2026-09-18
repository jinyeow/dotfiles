#Requires -Version 7
# Behavioural tests for ai-agents/skills/project-brain/scripts/session-start.ps1 — the SessionStart
# hook that injects an initiative's core.md + STATUS.md as additionalContext. Pins the fail-safe
# over-cap warning line appended when STATUS.md exceeds the ~60 line soft cap. Drives the real
# script as a child process with SessionStart-shaped JSON on stdin, against the in-repo self-contained brain path
# (session-start.ps1:52-65: an ancestor .claude/brain/core.md wins with no brains.json/$HOME
# involved), asserting on the emitted hookSpecificOutput.additionalContext JSON since that is the
# contract.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:Script = Join-Path $script:RepoRoot 'ai-agents/skills/project-brain/scripts/session-start.ps1'

    # Runs the real hook as a fresh child. On Windows the child derives $HOME from
    # $env:USERPROFILE (verified: setting only USERPROFILE, leaving HOMEDRIVE/HOMEPATH
    # pointed at the real home, still moves the child's $HOME); on Linux/macOS pwsh derives
    # $HOME from $env:HOME instead. We set both env vars to the fixture home for the child
    # launch and restore both (including unsetting when they were previously unset) in
    # finally, so isolation holds on every OS. Default home is an empty temp dir so path-1
    # (in-repo brain) tests never read the real ~/.claude/project-brain/brains.json and stay
    # machine-independent.
    function Invoke-SessionStart {
        param([string] $Payload, [string] $Cwd, [string] $HomeDir)
        if (-not $Payload) { $Payload = @{ cwd = $Cwd } | ConvertTo-Json -Compress }
        $ownHome = $false
        if (-not $HomeDir) {
            $HomeDir = Join-Path ([IO.Path]::GetTempPath()) ('pb-emptyhome-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $HomeDir -Force | Out-Null
            $ownHome = $true
        }
        $savedUserProfile = $env:USERPROFILE
        $savedHome = $env:HOME
        try {
            $env:USERPROFILE = $HomeDir
            $env:HOME = $HomeDir
            $out = ($Payload | & pwsh -NoProfile -File $script:Script 2>&1 | Out-String).Trim()
            $script:LastExitCode = $LASTEXITCODE
            return $out
        } finally {
            $env:USERPROFILE = $savedUserProfile
            $env:HOME = $savedHome
            if ($ownHome) { Remove-Item -LiteralPath $HomeDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    function New-Workspace {
        param([string[]] $StatusLines, [string] $StatusRaw, [switch] $NoStatus)
        $ws = Join-Path ([IO.Path]::GetTempPath()) ('pb-session-start-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $ws '.claude/brain') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $ws '.claude/brain/core.md') -Value '# core' -Encoding utf8
        if ($StatusRaw) {
            Set-Content -LiteralPath (Join-Path $ws '.claude/brain/STATUS.md') -Value $StatusRaw -NoNewline -Encoding utf8
        } elseif (-not $NoStatus) {
            Set-Content -LiteralPath (Join-Path $ws '.claude/brain/STATUS.md') -Value ($StatusLines -join "`n") -Encoding utf8
        }
        return $ws
    }

    function ConvertTo-CwdNorm([string] $path) {
        return ($path -replace '\\', '/').TrimEnd('/')
    }

    # Builds a fixture $HOME + registered brain repo for the path-2 (brains.json ->
    # registry -> initiative) resolution. Returns the home dir plus the brain path so a
    # test can pass -HomeDir and assert on the loaded initiative. $Cwd is registered both
    # as the scope and as the loaded initiative's dir glob (exact, normalised). Extra
    # on-disk initiatives (for the staleness scan) come from -Initiatives; each is a
    # hashtable @{ Id; StatusRaw?; Archived? }. A raw -RegistryJson overrides the registry
    # file verbatim (used to drive the malformed-registry fail-safe case).
    function New-RegisteredHome {
        param(
            [Parameter(Mandatory)][string] $Cwd,
            [string] $LoadedId = 'loaded',
            [string] $LoadedTitle = 'Loaded initiative',
            [string] $LoadedStatusRaw,
            [hashtable[]] $Initiatives,
            [string] $RegistryJson
        )
        $fixtureHome = Join-Path ([IO.Path]::GetTempPath()) ('pb-home-' + [guid]::NewGuid())
        $brain = Join-Path ([IO.Path]::GetTempPath()) ('pb-brain-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $fixtureHome '.claude/project-brain') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $brain 'initiatives') -Force | Out-Null

        $cwdNorm = ConvertTo-CwdNorm $Cwd
        $brains = @{ brains = @(@{ scope = $cwdNorm; path = $brain }) }
        Set-Content -LiteralPath (Join-Path $fixtureHome '.claude/project-brain/brains.json') `
            -Value ($brains | ConvertTo-Json -Depth 6) -Encoding utf8

        if ($RegistryJson) {
            Set-Content -LiteralPath (Join-Path $brain 'registry.json') -Value $RegistryJson -NoNewline -Encoding utf8
        } else {
            $reg = @{ initiatives = @{ $LoadedId = @{ title = $LoadedTitle; dirs = @($cwdNorm) } } }
            Set-Content -LiteralPath (Join-Path $brain 'registry.json') `
                -Value ($reg | ConvertTo-Json -Depth 6) -Encoding utf8
        }

        $loadedDir = Join-Path $brain "initiatives/$LoadedId"
        New-Item -ItemType Directory -Path $loadedDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $loadedDir 'core.md') -Value '# loaded core' -Encoding utf8
        $loadedStatus = if ($LoadedStatusRaw) { $LoadedStatusRaw } else { "# loaded status`nnow" }
        Set-Content -LiteralPath (Join-Path $loadedDir 'STATUS.md') -Value $loadedStatus -NoNewline -Encoding utf8

        foreach ($init in $Initiatives) {
            $dir = if ($init.Archived) {
                Join-Path $brain "initiatives/_archive/$($init.Id)"
            } else {
                Join-Path $brain "initiatives/$($init.Id)"
            }
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $dir 'core.md') -Value "# $($init.Id) core" -Encoding utf8
            if ($init.ContainsKey('StatusRaw')) {
                Set-Content -LiteralPath (Join-Path $dir 'STATUS.md') -Value $init.StatusRaw -NoNewline -Encoding utf8
            }
        }
        return @{ Home = $fixtureHome; Brain = $brain }
    }

    # A conformant STATUS.md front matter block with the given stale_after date plus
    # $BodyLines lines of body. Total line count = 6 frontmatter lines + $BodyLines.
    function New-StatusMd {
        param([string] $StaleAfter, [int] $BodyLines = 3)
        $fm = "---`ninitiative: x`ntype: status`nupdated: 2026-01-01`nstale_after: $StaleAfter`n---"
        $body = (1..$BodyLines | ForEach-Object { "body$_" }) -join "`n"
        return "$fm`n$body"
    }

    # Registers $Initiatives (plus a fresh loaded initiative matching cwd) under an
    # isolated fixture home, runs the hook via path 2, and returns the emitted
    # additionalContext. Used by the staleness/oversize advisory tests.
    function Invoke-Path2 {
        param([hashtable[]] $Initiatives, [string] $LoadedStatusRaw)
        $cwd = Join-Path ([IO.Path]::GetTempPath()) ('pb-cwd-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $cwd -Force | Out-Null
        $fx = New-RegisteredHome -Cwd $cwd -Initiatives $Initiatives -LoadedStatusRaw $LoadedStatusRaw
        try {
            $out = Invoke-SessionStart -Cwd $cwd -HomeDir $fx.Home
            return ($out | ConvertFrom-Json).hookSpecificOutput.additionalContext
        } finally {
            Remove-Item -LiteralPath $cwd -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $fx.Home -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $fx.Brain -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'ai-agents/skills/project-brain/scripts/session-start.ps1' {
    It 'emits no warning line when STATUS.md is under the cap' {
        $lines = 1..5 | ForEach-Object { "line$_" }
        $ws = New-Workspace -StatusLines $lines
        try {
            $out = Invoke-SessionStart -Cwd $ws
            $json = $out | ConvertFrom-Json
            $ctx = $json.hookSpecificOutput.additionalContext
            $ctx | Should -Not -Match '\[project-brain\] STATUS\.md is \d+ lines'
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'appends exactly one warning line carrying the real count when STATUS.md exceeds the cap' {
        $lines = 1..61 | ForEach-Object { "line$_" }
        $ws = New-Workspace -StatusLines $lines
        try {
            $out = Invoke-SessionStart -Cwd $ws
            $json = $out | ConvertFrom-Json
            $ctx = $json.hookSpecificOutput.additionalContext
            $warningMatches = [regex]::Matches($ctx, '\[project-brain\] STATUS\.md is \d+ lines')
            $warningMatches.Count | Should -Be 1
            $ctx | Should -Match ([regex]::Escape('[project-brain] STATUS.md is 61 lines; the contract caps it at about 60. Move history to log.md in this initiative at the next status update.'))
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'keeps the missing-STATUS.md line and emits no warning when STATUS.md is absent' {
        $ws = New-Workspace -NoStatus
        try {
            $out = Invoke-SessionStart -Cwd $ws
            $json = $out | ConvertFrom-Json
            $ctx = $json.hookSpecificOutput.additionalContext
            $ctx | Should -Match ([regex]::Escape('(No STATUS.md yet - this initiative may be newly scaffolded.)'))
            $ctx | Should -Not -Match '\[project-brain\] STATUS\.md is \d+ lines'
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'exits 0 with no output on malformed stdin' {
        $out = Invoke-SessionStart -Payload 'not valid json {'
        $out | Should -BeNullOrEmpty
        $script:LastExitCode | Should -Be 0
    }

    It 'emits no warning line when STATUS.md is exactly at the cap' {
        $lines = 1..60 | ForEach-Object { "line$_" }
        $ws = New-Workspace -StatusLines $lines
        try {
            $out = Invoke-SessionStart -Cwd $ws
            $json = $out | ConvertFrom-Json
            $ctx = $json.hookSpecificOutput.additionalContext
            $ctx | Should -Not -Match '\[project-brain\] STATUS\.md is \d+ lines'
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'counts a trailing blank line as real content, not as the terminator' {
        $raw = (1..61 | ForEach-Object { "line$_" }) -join "`n"
        $raw += "`n`n"
        $ws = New-Workspace -StatusRaw $raw
        try {
            $out = Invoke-SessionStart -Cwd $ws
            $json = $out | ConvertFrom-Json
            $ctx = $json.hookSpecificOutput.additionalContext
            $ctx | Should -Match ([regex]::Escape('[project-brain] STATUS.md is 62 lines'))
        } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Context 'path 2: global brains.json -> registry -> initiative' {
        It 'loads the registered initiative context when a dir glob matches cwd' {
            $cwd = Join-Path ([IO.Path]::GetTempPath()) ('pb-cwd-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $cwd -Force | Out-Null
            $fx = New-RegisteredHome -Cwd $cwd -LoadedId 'PBI-9' -LoadedTitle 'Ninth thing'
            try {
                $out = Invoke-SessionStart -Cwd $cwd -HomeDir $fx.Home
                $json = $out | ConvertFrom-Json
                $ctx = $json.hookSpecificOutput.additionalContext
                $ctx | Should -Match ([regex]::Escape('[project-brain] Active initiative: PBI-9 - Ninth thing.'))
                $ctx | Should -Match ([regex]::Escape('# loaded core'))
                $script:LastExitCode | Should -Be 0
            } finally {
                Remove-Item -LiteralPath $cwd -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $fx.Home -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $fx.Brain -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'emits nothing and exits 0 when no registry dir glob matches cwd' {
            $cwd = Join-Path ([IO.Path]::GetTempPath()) ('pb-cwd-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $cwd -Force | Out-Null
            $fx = New-RegisteredHome -Cwd $cwd
            try {
                # Point the child at a sibling dir the scope does not cover.
                $other = Join-Path ([IO.Path]::GetTempPath()) ('pb-other-' + [guid]::NewGuid())
                New-Item -ItemType Directory -Path $other -Force | Out-Null
                $out = Invoke-SessionStart -Cwd $other -HomeDir $fx.Home
                $out | Should -BeNullOrEmpty
                $script:LastExitCode | Should -Be 0
                Remove-Item -LiteralPath $other -Recurse -Force -ErrorAction SilentlyContinue
            } finally {
                Remove-Item -LiteralPath $cwd -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $fx.Home -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $fx.Brain -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'path 1: P2 shadow notice when a registered initiative also matches' {
        It 'appends exactly one notice naming the shadowed id and still loads the in-repo brain' {
            $ws = New-Workspace -StatusLines @('now')
            $fx = New-RegisteredHome -Cwd $ws -LoadedId 'PBI-7'
            try {
                $out = Invoke-SessionStart -Cwd $ws -HomeDir $fx.Home
                $json = $out | ConvertFrom-Json
                $ctx = $json.hookSpecificOutput.additionalContext
                $ctx | Should -Match ([regex]::Escape('# core'))
                $notices = [regex]::Matches($ctx, '\[project-brain\] A registered initiative also matches this directory and was NOT loaded:')
                $notices.Count | Should -Be 1
                $ctx | Should -Match 'NOT loaded: PBI-7 at .+initiatives.+PBI-7\. Read its core\.md and STATUS\.md if the task concerns it\.'
                $script:LastExitCode | Should -Be 0
            } finally {
                Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $fx.Home -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $fx.Brain -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'appends no notice when no registered initiative matches, keeping the in-repo context' {
            $ws = New-Workspace -StatusLines @('now')
            try {
                $out = Invoke-SessionStart -Cwd $ws
                $json = $out | ConvertFrom-Json
                $ctx = $json.hookSpecificOutput.additionalContext
                $ctx | Should -Match ([regex]::Escape('# core'))
                $ctx | Should -Not -Match '\[project-brain\] A registered initiative also matches'
            } finally { Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue }
        }

        It 'keeps the in-repo context and adds no notice when the brains.json scope does not cover cwd' {
            # brains.json exists but its scope points at an unrelated dir, so the resolver
            # returns $null at the scope-mismatch branch. Pins that this branch returns (not
            # exits): an exit here would escape the inner try/catch and drop the in-repo context.
            $ws = New-Workspace -StatusLines @('now')
            $unrelated = Join-Path ([IO.Path]::GetTempPath()) ('pb-unrelated-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $unrelated -Force | Out-Null
            $fx = New-RegisteredHome -Cwd $unrelated
            try {
                $out = Invoke-SessionStart -Cwd $ws -HomeDir $fx.Home
                $json = $out | ConvertFrom-Json
                $ctx = $json.hookSpecificOutput.additionalContext
                $ctx | Should -Match ([regex]::Escape('# core'))
                $ctx | Should -Not -Match '\[project-brain\] A registered initiative also matches'
                $script:LastExitCode | Should -Be 0
            } finally {
                Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $unrelated -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $fx.Home -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $fx.Brain -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'still emits the in-repo context with no notice and exit 0 when registry.json is malformed' {
            $ws = New-Workspace -StatusLines @('now')
            $fx = New-RegisteredHome -Cwd $ws -RegistryJson '{ "initiatives": { not valid'
            try {
                $out = Invoke-SessionStart -Cwd $ws -HomeDir $fx.Home
                $json = $out | ConvertFrom-Json
                $ctx = $json.hookSpecificOutput.additionalContext
                $ctx | Should -Match ([regex]::Escape('# core'))
                $ctx | Should -Not -Match '\[project-brain\] A registered initiative also matches'
                $script:LastExitCode | Should -Be 0
            } finally {
                Remove-Item -LiteralPath $ws -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $fx.Home -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $fx.Brain -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'path 2: P1 staleness / oversize advisory line' {
        It 'names only the stale active initiative, excluding fresh, archived, and frontmatter-less' {
            $ctx = Invoke-Path2 -Initiatives @(
                @{ Id = 'stale-one'; StatusRaw = (New-StatusMd -StaleAfter '2020-01-01') }
                @{ Id = 'fresh-one'; StatusRaw = (New-StatusMd -StaleAfter '2099-01-01') }
                @{ Id = 'arch-stale'; Archived = $true; StatusRaw = (New-StatusMd -StaleAfter '2020-01-01') }
                @{ Id = 'no-fm'; StatusRaw = "# no frontmatter`nbody" }
            )
            $ctx | Should -Match ([regex]::Escape('[project-brain] 1 initiatives past stale_after: stale-one (2020-01-01).'))
            $ctx | Should -Not -Match 'fresh-one'
            $ctx | Should -Not -Match 'arch-stale'
            $ctx | Should -Not -Match 'no-fm'
        }

        It 'emits no advisory line when nothing is stale and nothing is over the cap' {
            $ctx = Invoke-Path2 -Initiatives @(
                @{ Id = 'fresh-one'; StatusRaw = (New-StatusMd -StaleAfter '2099-01-01') }
            )
            $ctx | Should -Not -Match 'past stale_after'
            $ctx | Should -Not -Match 'over the size cap'
        }

        It 'treats a stale_after equal to today as not stale' {
            $today = (Get-Date).ToString('yyyy-MM-dd')
            $ctx = Invoke-Path2 -Initiatives @(
                @{ Id = 'edge'; StatusRaw = (New-StatusMd -StaleAfter $today) }
            )
            $ctx | Should -Not -Match 'past stale_after'
        }

        It 'lists the 8 oldest stale names first with a +K more suffix when more than 8 are stale' {
            # Names ascend (st01..st10) but stale_after descends, so oldest-first ordering
            # must reverse discovery order: st10 (oldest) first, st01/st02 (newest) dropped.
            $inits = 1..10 | ForEach-Object {
                $id = 'st{0:D2}' -f $_
                $date = '2020-01-{0:D2}' -f (11 - $_)
                @{ Id = $id; StatusRaw = (New-StatusMd -StaleAfter $date) }
            }
            $ctx = Invoke-Path2 -Initiatives $inits
            $expected = '[project-brain] 10 initiatives past stale_after: st10 (2020-01-01), st09 (2020-01-02), st08 (2020-01-03), st07 (2020-01-04), st06 (2020-01-05), st05 (2020-01-06), st04 (2020-01-07), st03 (2020-01-08) +2 more.'
            $ctx | Should -Match ([regex]::Escape($expected))
            $ctx | Should -Not -Match 'st01 \('
            $ctx | Should -Not -Match 'st02 \('
        }

        It 'appends an over-the-cap clause after the stale clause when both apply' {
            $ctx = Invoke-Path2 -Initiatives @(
                @{ Id = 'stl'; StatusRaw = (New-StatusMd -StaleAfter '2020-01-01') }
                @{ Id = 'big'; StatusRaw = (New-StatusMd -StaleAfter '2099-01-01' -BodyLines 61) }
            )
            $ctx | Should -Match ([regex]::Escape('[project-brain] 1 initiatives past stale_after: stl (2020-01-01). Over the size cap: big (67 lines).'))
        }

        It 'emits an over-the-cap-only line when something is oversized but nothing is stale' {
            $ctx = Invoke-Path2 -Initiatives @(
                @{ Id = 'big'; StatusRaw = (New-StatusMd -StaleAfter '2099-01-01' -BodyLines 61) }
            )
            $ctx | Should -Match ([regex]::Escape('[project-brain] STATUS.md over the size cap: big (67 lines).'))
            $ctx | Should -Not -Match 'past stale_after'
        }
    }
}
