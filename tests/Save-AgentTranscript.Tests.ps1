#Requires -Version 7
# Pester tests for powershell/Scripts/Save-AgentTranscript.ps1. Every test builds a fake home
# and archive under $TestDrive and passes them in, so no real transcript or archive is read
# or written. Assertions are on the files in the archive.

BeforeAll {
    $script:ScriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'powershell' 'Scripts' 'Save-AgentTranscript.ps1'

    function New-TestFile([string]$Path, [string]$Content = 'line') {
        New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
        Set-Content -LiteralPath $Path -Value $Content -NoNewline
    }
}

# The script uses robocopy and compact.exe, which exist only on Windows.
Describe 'Save-AgentTranscript' -Skip:(-not $IsWindows) {
    BeforeEach {
        $script:SourceHome = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:Archive = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-TestFile (Join-Path $SourceHome '.claude' 'projects' 'E--Acme-repo' 'session.jsonl')
        New-TestFile (Join-Path $SourceHome '.claude' 'projects' 'E--Acme-repo' 'session' 'subagents' 'agent.jsonl')
        New-TestFile (Join-Path $SourceHome '.claude' 'projects' 'E--Personal-dotfiles' 'personal.jsonl')
        New-TestFile (Join-Path $SourceHome '.claude' 'history.jsonl')
        New-TestFile (Join-Path $SourceHome '.codex' 'sessions' '2026' '11' 'rollout.jsonl')
        New-TestFile (Join-Path $SourceHome '.pi' 'agent' 'sessions' 'pi.jsonl')
    }

    It 'routes Claude projects matching the work pattern to work and everything else to personal' {
        & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome -WorkProjectPattern '^E--Acme'

        Join-Path $Archive 'work' 'claude' 'projects' 'E--Acme-repo' 'session.jsonl' | Should -Exist
        Join-Path $Archive 'work' 'claude' 'projects' 'E--Acme-repo' 'session' 'subagents' 'agent.jsonl' | Should -Exist
        Join-Path $Archive 'personal' 'claude' 'projects' 'E--Personal-dotfiles' 'personal.jsonl' | Should -Exist
        Join-Path $Archive 'personal' 'claude' 'projects' 'E--Acme-repo' | Should -Not -Exist
    }

    It 'archives Claude prompt history, Codex sessions and Pi sessions under personal' {
        & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome -WorkProjectPattern '^E--Acme'

        Join-Path $Archive 'personal' 'claude' 'history.jsonl' | Should -Exist
        Join-Path $Archive 'personal' 'codex' 'sessions' '2026' '11' 'rollout.jsonl' | Should -Exist
        Join-Path $Archive 'personal' 'pi' 'sessions' 'pi.jsonl' | Should -Exist
    }

    It 'puts every Claude project under personal when no work pattern is given' {
        & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome

        Join-Path $Archive 'personal' 'claude' 'projects' 'E--Acme-repo' 'session.jsonl' | Should -Exist
        Join-Path $Archive 'work' | Should -Not -Exist
    }

    It 'keeps archived files after they are deleted from the source' {
        & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome -WorkProjectPattern '^E--Acme'
        Remove-Item -LiteralPath (Join-Path $SourceHome '.claude' 'projects' 'E--Personal-dotfiles' 'personal.jsonl')

        & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome -WorkProjectPattern '^E--Acme'

        Join-Path $Archive 'personal' 'claude' 'projects' 'E--Personal-dotfiles' 'personal.jsonl' | Should -Exist
    }

    It 'updates an archived file when the source is newer' {
        & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome -WorkProjectPattern '^E--Acme'
        $source = Join-Path $SourceHome '.claude' 'history.jsonl'
        Set-Content -LiteralPath $source -Value 'line plus more' -NoNewline
        (Get-Item -LiteralPath $source).LastWriteTime = (Get-Date).AddMinutes(5)

        & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome -WorkProjectPattern '^E--Acme'

        Get-Content -LiteralPath (Join-Path $Archive 'personal' 'claude' 'history.jsonl') -Raw | Should -BeExactly 'line plus more'
    }

    It 'keeps the archived copy when the source is older than it' {
        & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome -WorkProjectPattern '^E--Acme'
        $source = Join-Path $SourceHome '.claude' 'history.jsonl'
        Set-Content -LiteralPath $source -Value 'older rewrite' -NoNewline
        (Get-Item -LiteralPath $source).LastWriteTime = (Get-Date).AddDays(-1)

        & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome -WorkProjectPattern '^E--Acme'

        Get-Content -LiteralPath (Join-Path $Archive 'personal' 'claude' 'history.jsonl') -Raw | Should -BeExactly 'line'
    }

    It 'archives the other sources when one source has a locked file, then fails naming that source' {
        $locked = Join-Path $SourceHome '.claude' 'projects' 'E--Personal-dotfiles' 'personal.jsonl'
        $handle = [IO.File]::Open($locked, 'Open', 'Read', 'None')
        try {
            { & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome -WorkProjectPattern '^E--Acme' } |
                Should -Throw '*E--Personal-dotfiles*'
        } finally {
            $handle.Dispose()
        }

        Join-Path $Archive 'personal' 'codex' 'sessions' '2026' '11' 'rollout.jsonl' | Should -Exist
        Join-Path $Archive 'personal' 'pi' 'sessions' 'pi.jsonl' | Should -Exist
    }

    It 'warns about a missing source and still archives the others' {
        Remove-Item -LiteralPath (Join-Path $SourceHome '.codex') -Recurse

        & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome -WorkProjectPattern '^E--Acme' -WarningVariable warnings -WarningAction SilentlyContinue

        $warnings | Should -HaveCount 1
        "$($warnings[0])" | Should -BeLike '*.codex*sessions*'
        Join-Path $Archive 'personal' 'pi' 'sessions' 'pi.jsonl' | Should -Exist
    }

    It 'compresses the archive with NTFS compression' {
        & $ScriptPath -ArchiveRoot $Archive -SourceHome $SourceHome -WorkProjectPattern '^E--Acme'

        $file = Get-Item -LiteralPath (Join-Path $Archive 'personal' 'claude' 'history.jsonl')
        $file.Attributes.HasFlag([IO.FileAttributes]::Compressed) | Should -BeTrue
    }
}
