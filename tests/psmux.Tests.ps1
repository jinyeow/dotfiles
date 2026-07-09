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
