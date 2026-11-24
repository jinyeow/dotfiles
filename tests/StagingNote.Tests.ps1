#Requires -Version 7
# Pester tests for powershell/Profile/StagingNote.ps1 (the `note` command). The file
# defines functions with no load-time side effects, so it is dot-sourced directly.
# Invoke-ObsidianCli is the only boundary to the running Obsidian app; it is mocked to
# point the Staging vault at $TestDrive, so no test touches a real vault. Assertions are
# on the daily-note file content.

BeforeAll {
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'powershell' 'Profile' 'StagingNote.ps1')
}

Describe 'Add-StagingNote' {
    BeforeEach {
        $script:vaultRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $script:vaultRoot 'daily') -Force | Out-Null
        $script:dailyFile = Join-Path $script:vaultRoot 'daily' '2026-11-24.md'

        Mock Invoke-ObsidianCli { $script:vaultRoot } -ParameterFilter { $Arguments -contains 'info=path' }
        Mock Invoke-ObsidianCli { 'daily/2026-11-24.md' } -ParameterFilter { $Arguments -contains 'daily:path' }
        Mock Invoke-ObsidianCli {
            [IO.File]::WriteAllText($script:dailyFile, "# from template`n")
        } -ParameterFilter { $Arguments -contains 'create' }
    }

    It 'appends a labelled section with piped text to an existing daily note' {
        [IO.File]::WriteAllText($script:dailyFile, "# 2026-11-24`n")

        'first line', 'second line' | Add-StagingNote 'build output'

        [IO.File]::ReadAllText($script:dailyFile) |
            Should -BeExactly "# 2026-11-24`n`n## build output`nfirst line`nsecond line`n"
    }

    It 'keeps backslashes and tabs exactly as given' {
        [IO.File]::WriteAllText($script:dailyFile, '')

        "C:\new\tab`tcol \n" | Add-StagingNote 'paths'

        [IO.File]::ReadAllText($script:dailyFile) |
            Should -BeExactly "`n## paths`nC:\new\tab`tcol \n`n"
    }

    It 'normalises CRLF in the content to LF' {
        [IO.File]::WriteAllText($script:dailyFile, "x`n")

        "a`r`nb" | Add-StagingNote 'crlf'

        [IO.File]::ReadAllText($script:dailyFile) | Should -BeExactly "x`n`n## crlf`na`nb`n"
    }

    It 'normalises lone CR line endings to LF' {
        [IO.File]::WriteAllText($script:dailyFile, "x`n")

        "a`rb`rc" | Add-StagingNote 'cr'

        [IO.File]::ReadAllText($script:dailyFile) | Should -BeExactly "x`n`n## cr`na`nb`nc`n"
    }

    It 'adds a line break first when the note does not end with one' {
        [IO.File]::WriteAllText($script:dailyFile, 'no trailing newline')

        'text' | Add-StagingNote 'label'

        [IO.File]::ReadAllText($script:dailyFile) |
            Should -BeExactly "no trailing newline`n`n## label`ntext`n"
    }

    It 'formats piped objects the way the console shows them' {
        [IO.File]::WriteAllText($script:dailyFile, '')
        $expected = ([pscustomobject]@{ Name = 'alpha'; Size = 1 } | Out-String).Trim() -replace "`r`n", "`n"

        [pscustomobject]@{ Name = 'alpha'; Size = 1 } | Add-StagingNote 'objects'

        [IO.File]::ReadAllText($script:dailyFile) | Should -BeExactly "`n## objects`n$expected`n"
    }

    It 'uses the clipboard when nothing is piped' {
        [IO.File]::WriteAllText($script:dailyFile, '')
        Mock Get-Clipboard { 'from clipboard' }

        Add-StagingNote 'clip'

        [IO.File]::ReadAllText($script:dailyFile) | Should -BeExactly "`n## clip`nfrom clipboard`n"
    }

    It 'creates the daily note from the template when it does not exist yet' {
        'text' | Add-StagingNote 'new day'

        [IO.File]::ReadAllText($script:dailyFile) | Should -BeExactly "# from template`n`n## new day`ntext`n"
    }

    It 'throws and writes nothing when there is no content' {
        [IO.File]::WriteAllText($script:dailyFile, 'unchanged')
        Mock Get-Clipboard { '' }

        { Add-StagingNote 'empty' } | Should -Throw '*Nothing to add*'
        [IO.File]::ReadAllText($script:dailyFile) | Should -BeExactly 'unchanged'
    }

    It 'is available as the note alias' {
        (Get-Alias note).Definition | Should -Be 'Add-StagingNote'
    }
}
