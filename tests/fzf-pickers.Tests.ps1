#Requires -Version 7
# Pester tests for the pure logic behind the bare-fzf Ctrl+t / Ctrl+r pickers in
# powershell/Microsoft.PowerShell_profile.ps1. The profile runs side effects at load
# and is not dot-sourceable, so we lift just the two pure helpers out of it by AST and
# redefine them here. The interactive key-trigger + PSReadLine buffer insert/replace is
# not unit-testable and is live-verified.

BeforeAll {
    $profilePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'powershell' 'Microsoft.PowerShell_profile.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$null, [ref]$null)
    $wanted = 'Format-FzfPickInsertion', 'Get-FzfDedupedHistory'
    $funcs = $ast.FindAll(
        { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $funcs) {
        if ($wanted | Where-Object { $fn.Name -match $_ }) {
            . ([scriptblock]::Create($fn.Extent.Text))
        }
    }
}

Describe 'Format-FzfPickInsertion' {
    It 'passes a whitespace-free pick through unquoted' {
        Format-FzfPickInsertion -Picks @('a') | Should -BeExactly 'a'
    }

    It 'single-quotes a pick containing whitespace' {
        Format-FzfPickInsertion -Picks @('a b.txt') | Should -BeExactly "'a b.txt'"
    }

    It 'joins multiple picks with spaces, quoting only those with whitespace' {
        Format-FzfPickInsertion -Picks @('a', 'b c') | Should -BeExactly "a 'b c'"
    }

    It 'doubles an embedded single quote inside a quoted pick' {
        Format-FzfPickInsertion -Picks @("it's here") | Should -BeExactly "'it''s here'"
    }
}

Describe 'Get-FzfDedupedHistory' {
    It 'returns file-order lines newest-first, de-duplicated' {
        # File order (oldest-first) 'a','b','a' -> newest-first 'a','b','a' -> dedup 'a','b'.
        Get-FzfDedupedHistory -Lines @('a', 'b', 'a') | Should -Be @('a', 'b')
    }

    It 'keeps the most-recent occurrence position and drops earlier duplicates' {
        # 'one','two','three','two' -> newest-first 'two','three','two','one' -> 'two','three','one'.
        Get-FzfDedupedHistory -Lines @('one', 'two', 'three', 'two') |
            Should -Be @('two', 'three', 'one')
    }

    It 'returns an empty result for no input lines' {
        Get-FzfDedupedHistory -Lines @() | Should -BeNullOrEmpty
    }
}
