#Requires -Version 7
# Pester test: winget/README.md promises that packages.ps1 and packages.json carry the same package
# set. Nothing else enforces that, so a package added to one file silently goes missing from a
# machine bootstrapped with the other.

BeforeAll {
    $script:Repo = Split-Path $PSScriptRoot -Parent
    $script:ScriptPath = Join-Path $script:Repo 'winget/packages.ps1'
    $script:JsonPath = Join-Path $script:Repo 'winget/packages.json'
}

Describe 'winget package lists' {
    It 'packages.ps1 and packages.json list the same package IDs' {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$tokens, [ref]$errors)
        $errors | Should -BeNullOrEmpty

        $calls = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq 'Install-Package'
            }, $true)
        # Every call must pass the ID as one positional string constant, or the extraction below
        # would drop it without notice.
        $unreadable = $calls | Where-Object {
            $_.CommandElements.Count -ne 2 -or
            $_.CommandElements[1] -isnot [System.Management.Automation.Language.StringConstantExpressionAst]
        }
        $unreadable.Extent.Text | Should -BeNullOrEmpty
        [string[]]$scriptIds = $calls | ForEach-Object { $_.CommandElements[1].Value } | Sort-Object -Unique

        $json = Get-Content -Raw $script:JsonPath | ConvertFrom-Json
        [string[]]$jsonIds = $json.Sources.Packages.PackageIdentifier | Sort-Object -Unique

        $scriptIds | Should -Not -BeNullOrEmpty
        $jsonIds | Should -Not -BeNullOrEmpty
        Compare-Object -ReferenceObject $jsonIds -DifferenceObject $scriptIds | Should -BeNullOrEmpty
    }
}
