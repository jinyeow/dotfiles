#Requires -Version 7
# Pester test: the psmux config must parse without warnings. Guards against regressions like the
# trailing-comment-on-`set`-line bug (psmux parses an inline comment into the option value) or a
# psmux update that renames a command. Runs only when psmux is installed (CI has none, so it skips
# there); isolated on a private socket (-L) and a throwaway HOME so it never touches the user's real
# psmux server or triggers the vendored persistence plugins (`run ppm.ps1` finds no plugins).

BeforeAll {
    $script:Repo = Split-Path $PSScriptRoot -Parent
    $script:Conf = Join-Path $script:Repo 'psmux/psmux.conf'
    $script:PluginsSrc = Join-Path $script:Repo 'psmux/plugins'
    $script:SaveScript = Join-Path $script:Repo 'psmux/plugins/psmux-resurrect/scripts/save.ps1'
}

Describe 'psmux.conf' {
    It 'loads without any config warning or error' -Skip:(-not (Get-Command psmux -ErrorAction SilentlyContinue)) {
        # Throwaway HOME with the vendored plugins copied in, so the config's `source-file` lines
        # resolve - this validates the REAL config end-to-end, not just its syntax. Detached
        # (`new-session -d`) so continuum's client-attached auto-save hook never fires; the
        # session-created auto-restore hook no-ops (no savefile in the temp HOME). Private socket
        # (-L) so it never touches the user's real psmux server.
        $sock = 'psmux-pester-cfg'
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('psmux-cfgtest-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $tmpHome '.psmux/plugins') -Force | Out-Null
        Get-ChildItem -Path $script:PluginsSrc -Directory | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $tmpHome '.psmux/plugins') -Recurse -Force
        }
        $origUP, $origH = $env:USERPROFILE, $env:HOME
        try {
            $env:USERPROFILE = $tmpHome; $env:HOME = $tmpHome
            psmux -L $sock kill-server 2>&1 | Out-Null
            $out = psmux -L $sock -f $script:Conf new-session -d -s cfgtest -x 80 -y 24 2>&1 | Out-String
            $out | Should -Not -Match '(?i)(config warning|invalid|unknown command|parse error|failed)'
            # The persistence plugins must have sourced: resurrect binds Prefix+Ctrl-s.
            $keys = psmux -L $sock list-keys -T prefix 2>&1 | Out-String
            $keys | Should -Match 'C-s'
        }
        finally {
            psmux -L $sock kill-server 2>&1 | Out-Null
            $env:USERPROFILE = $origUP; $env:HOME = $origH
            Get-Job -ErrorAction SilentlyContinue | Where-Object { $_.Command -match 'auto_save' } | Remove-Job -Force -ErrorAction SilentlyContinue
            Remove-Item $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'psmux-resurrect save.ps1' {
    # Regression: a save that captures no REAL sessions must NOT overwrite the `last` pointer (or write
    # a new snapshot). The bug: the 15-min auto-save loop fires while the server has no sessions (it
    # exited after the last client detached), save.ps1 writes an empty/garbage capture and repoints
    # `last` at it, clobbering the good snapshot so restore-on-start brings back nothing.
    #
    # Two trigger paths, both must keep the previous snapshot:
    #   - empty output : `list-sessions` returns nothing         -> 0 sessions.
    #   - psmux error  : `list-sessions 2>&1` returns a "no server" line on stderr; that text must be
    #                    discarded (exit-code guard), not parsed as a bogus session name.
    #
    # Isolated with a fake `psmux` on PATH driving each path, so it never touches the user's real
    # psmux server and needs no psmux install (runs in CI). Assertions check the guard's skip message
    # and exit code too, so an early crash in save.ps1 cannot false-green the file-state checks.
    It 'keeps the previous snapshot when no real sessions are captured (<Case>)' -ForEach @(
        @{ Case = 'empty output'; ShimBody = "@echo off`r`nexit /b 0" }
        @{ Case = 'psmux error on stderr'; ShimBody = "@echo off`r`necho no server running on \\.\pipe\psmux 1>&2`r`nexit /b 1" }
    ) {
        $tmpHome = Join-Path ([IO.Path]::GetTempPath()) ('psmux-savetest-' + [guid]::NewGuid())
        $resurrectDir = Join-Path $tmpHome '.psmux/resurrect'
        $shimDir = Join-Path $tmpHome 'shim'
        New-Item -ItemType Directory -Path $resurrectDir -Force | Out-Null
        New-Item -ItemType Directory -Path $shimDir -Force | Out-Null

        # Seed a known-good non-empty snapshot and point `last` at it.
        $goodSave = Join-Path $resurrectDir 'psmux_resurrect_GOOD.json'
        $goodJson = @{
            version   = 2
            timestamp = 'GOOD'
            sessions  = @(@{ name = 'work'; windows = @(@{ index = 0; name = 'pwsh'; layout = 'x'; active = $true; zoomed = $false; flags = '*'; panes = @(@{ index = 0; directory = $tmpHome; active = $true; title = 't'; command = 'pwsh' }) }) })
        } | ConvertTo-Json -Depth 10
        Set-Content -Path $goodSave -Value $goodJson -Encoding UTF8
        $lastFile = Join-Path $resurrectDir 'last'
        Set-Content -Path $lastFile -Value $goodSave -Encoding UTF8

        # Fake psmux for this case (same response to every subcommand).
        Set-Content -Path (Join-Path $shimDir 'psmux.cmd') -Value $ShimBody -Encoding ASCII

        $origUP, $origPath = $env:USERPROFILE, $env:PATH
        try {
            $env:USERPROFILE = $tmpHome
            $env:PATH = $shimDir + [IO.Path]::PathSeparator + $env:PATH
            $out = (& pwsh -NoProfile -File $script:SaveScript 2>&1 | Out-String)
            $exit = $LASTEXITCODE

            # The guarded skip path must have run to completion (guards against a false green).
            $exit | Should -Be 0
            $out | Should -Match '0 sessions captured, skipped'
            # `last` must still point at the good snapshot, and no other save may exist.
            (Get-Content $lastFile -Raw).Trim() | Should -Be $goodSave
            @(Get-ChildItem -Path $resurrectDir -Filter 'psmux_resurrect_*.json' | ForEach-Object Name) |
                Should -Be 'psmux_resurrect_GOOD.json'
        }
        finally {
            $env:USERPROFILE = $origUP; $env:PATH = $origPath
            Remove-Item $tmpHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
