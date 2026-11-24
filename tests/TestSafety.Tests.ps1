BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:RealHome = [Environment]::GetFolderPath('UserProfile')
}

# Every refusal case passes -WhatIf, so a broken guard still cannot delete anything.
Describe 'TestSafety Remove-Item guard' {
    It 'refuses the real home folder' {
        { Remove-Item -LiteralPath $script:RealHome -Recurse -Force -WhatIf } | Should -Throw '*TestSafety*'
    }

    It 'refuses the home folder through $HOME and -Path' {
        { Remove-Item -Path $HOME -Recurse -WhatIf } | Should -Throw '*TestSafety*'
    }

    It 'refuses a top-level folder inside home, even one that does not exist' {
        { Remove-Item -LiteralPath (Join-Path $script:RealHome 'Documents') -Recurse -WhatIf } | Should -Throw '*TestSafety*'
        { Remove-Item -LiteralPath (Join-Path $script:RealHome ('testsafety-' + [guid]::NewGuid())) -WhatIf } | Should -Throw '*TestSafety*'
    }

    It 'refuses a wildcard over home' {
        { Remove-Item -Path (Join-Path $script:RealHome '*') -Recurse -WhatIf } | Should -Throw '*TestSafety*'
    }

    It 'refuses an ancestor of home' {
        { Remove-Item -LiteralPath (Split-Path $script:RealHome -Parent) -Recurse -WhatIf } | Should -Throw '*TestSafety*'
    }

    It 'refuses the temp root itself' {
        { Remove-Item -LiteralPath ([IO.Path]::GetTempPath()) -Recurse -WhatIf } | Should -Throw '*TestSafety*'
    }

    It 'refuses the repository root and its .git' {
        { Remove-Item -LiteralPath $script:RepoRoot -Recurse -WhatIf } | Should -Throw '*TestSafety*'
        { Remove-Item -LiteralPath (Join-Path $script:RepoRoot '.git') -Recurse -WhatIf } | Should -Throw '*TestSafety*'
    }

    It 'refuses home passed down the pipeline' {
        { Get-Item -LiteralPath $script:RealHome -Force | Remove-Item -Recurse -WhatIf } | Should -Throw '*TestSafety*'
        { $script:RealHome | Remove-Item -Recurse -WhatIf } | Should -Throw '*TestSafety*'
    }

    It 'refuses through the ri alias' {
        # ri is a Remove-Item alias on every platform; rm is a native binary on Linux and macOS.
        # Via a variable so PSScriptAnalyzer's alias rule does not flag the deliberate alias.
        $alias = 'ri'
        (Get-Alias -Name $alias).Definition | Should -Be 'Remove-Item'
        { & $alias -LiteralPath $script:RealHome -Recurse -WhatIf } | Should -Throw '*TestSafety*'
    }

    It 'refuses a wildcard through a link that points at home' {
        $link = Join-Path $TestDrive 'escape'
        $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $linkType -Path $link -Target $script:RealHome | Out-Null
        try
        {
            { Remove-Item -Path (Join-Path $link '*') -Recurse -WhatIf } | Should -Throw '*TestSafety*'
        }
        finally
        {
            # Deletes only the link itself, never the folder it points at.
            [IO.Directory]::Delete($link, $false)
        }
    }

    It 'removes a folder inside the temp directory' {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ('testsafety-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $dir 'child') -Force | Out-Null
        Remove-Item -LiteralPath $dir -Recurse -Force
        Test-Path -LiteralPath $dir | Should -BeFalse
    }

    It 'removes a TestDrive item passed down the pipeline' {
        $file = New-Item -ItemType File -Path (Join-Path $TestDrive 'piped.txt') -Force
        $file | Remove-Item -Force
        Test-Path -LiteralPath $file.FullName | Should -BeFalse
    }

    It 'removes a folder inside the repository' {
        $dir = Join-Path $script:RepoRoot ('.testsafety-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try
        {
            Remove-Item -LiteralPath $dir -Recurse -Force
            Test-Path -LiteralPath $dir | Should -BeFalse
        }
        finally
        {
            if (Test-Path -LiteralPath $dir) { Microsoft.PowerShell.Management\Remove-Item -LiteralPath $dir -Recurse -Force }
        }
    }

    It 'passes non-filesystem paths through' {
        $env:TESTSAFETY_PROBE = '1'
        Remove-Item -LiteralPath Env:TESTSAFETY_PROBE
        Test-Path Env:TESTSAFETY_PROBE | Should -BeFalse
    }
}

Describe 'TestSafety coverage' {
    It 'is loaded as the first statement of the top-level BeforeAll in every test file' {
        $missing = foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1')
        {
            $text = Get-Content -LiteralPath $file.FullName -Raw
            if ($text -notmatch "(?m)^BeforeAll \{\r?\n\s+\. \(Join-Path \`$PSScriptRoot 'TestSafety\.ps1'\)") { $file.Name }
        }
        $missing | Should -BeNullOrEmpty
    }
}
