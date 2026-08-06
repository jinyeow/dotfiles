#Requires -Version 7
# Behavioural tests for git/templates/hooks/ctags — specifically the documented
# (git/README.md: "Create a .notags file in any repo to disable") but previously
# unimplemented .notags opt-out. The hook is driven directly via bash against a
# throwaway git repo, with a PATH-shimmed fake `ctags` that leaves a marker file
# when invoked, so the test can tell whether the real tool generation ran.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')

    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:CtagsHook = Join-Path $script:RepoRoot 'git/templates/hooks/ctags'
    $script:Bash = Resolve-TestBash
    if (-not $script:Bash) {
        throw 'ctags-hook.Tests.ps1: no usable bash found, WSL launchers excluded — install Git for Windows'
    }

    function New-TestRepo {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('ctags-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        & git -C $root init -q . 2>&1 | Out-Null
        & git -C $root config user.email 'test@example.invalid' 2>&1 | Out-Null
        & git -C $root config user.name 'Test' 2>&1 | Out-Null
        Set-Content -Path (Join-Path $root 'f.txt') -Value 'x'
        & git -C $root add f.txt 2>&1 | Out-Null
        & git -C $root commit -q -m init 2>&1 | Out-Null
        return $root
    }

    # A fake `ctags` on PATH: touches $env:CTAGS_MARKER (proving it was invoked) and
    # writes an empty file at whatever -f<path> it was given, so the hook's later
    # `mv "$dir/$$.tags" "$dir/tags"` has something to move.
    function New-CtagsShim {
        param([string] $Root)
        $shimDir = Join-Path $Root 'shim'
        New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
        $shimPath = Join-Path $shimDir 'ctags'
        $body = @'
#!/bin/sh
: > "$CTAGS_MARKER"
outfile=""
for arg in "$@"; do
    case "$arg" in
        -f*) outfile="${arg#-f}" ;;
    esac
done
cat >/dev/null
[ -n "$outfile" ] && : > "$outfile"
exit 0
'@
        Set-Content -Path $shimPath -Value $body -NoNewline
        if (Get-Command chmod -ErrorAction SilentlyContinue) { & chmod +x $shimPath }
        return $shimDir
    }

    function Invoke-CtagsHook {
        param([string] $Repo, [string] $ShimDir, [string] $Marker)
        $origPath = $env:PATH
        $origMarker = $env:CTAGS_MARKER
        Push-Location $Repo
        try {
            $env:PATH = $ShimDir + [IO.Path]::PathSeparator + $origPath
            $env:CTAGS_MARKER = $Marker
            & $script:Bash $script:CtagsHook 2>&1 | Out-Null
            return $LASTEXITCODE
        } finally {
            Pop-Location
            $env:PATH = $origPath
            $env:CTAGS_MARKER = $origMarker
        }
    }
}

Describe 'git/templates/hooks/ctags' {
    BeforeEach {
        $script:Root = Join-Path ([IO.Path]::GetTempPath()) ('ctags-root-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:Root -Force | Out-Null
        $script:Repo = New-TestRepo
        $script:ShimDir = New-CtagsShim -Root $script:Root
        $script:Marker = Join-Path $script:Root 'marker'
    }

    AfterEach {
        Remove-Item -Path $script:Root, $script:Repo -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'invokes ctags and generates a tags file when no .notags is present' {
        # Sanity check that the shim + invocation plumbing actually works, so the
        # opt-out test below can't pass by accident (e.g. a broken shim never
        # invoked at all in either case).
        $exit = Invoke-CtagsHook -Repo $script:Repo -ShimDir $script:ShimDir -Marker $script:Marker
        $exit | Should -Be 0
        (Test-Path $script:Marker) | Should -BeTrue -Because 'ctags should have been invoked'
        (Test-Path (Join-Path $script:Repo 'tags')) | Should -BeTrue
    }

    It 'exits 0 without invoking ctags when .notags is present' {
        Set-Content -Path (Join-Path $script:Repo '.notags') -Value '' -NoNewline
        $exit = Invoke-CtagsHook -Repo $script:Repo -ShimDir $script:ShimDir -Marker $script:Marker
        $exit | Should -Be 0
        (Test-Path $script:Marker) | Should -BeFalse -Because 'the .notags opt-out must skip ctags entirely'
        (Test-Path (Join-Path $script:Repo 'tags')) | Should -BeFalse
    }
}
