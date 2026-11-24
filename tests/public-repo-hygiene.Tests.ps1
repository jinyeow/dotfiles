#Requires -Version 7
# Public-repo hygiene: this dotfiles repo is published (GitHub + Codeberg mirror), so no tracked
# file may name the developer's employer, its Azure DevOps organisation or project, or hardcode
# a drive path into the work root.
#
# The guarded values are never written here: that would leak them by inspection. They are read
# at runtime from the untracked ~/.gitconfig.local (see git/README.md):
#   git config --file ~/.gitconfig.local work.employer '<employer>'
#   git config --file ~/.gitconfig.local work.adoOrgUrl https://dev.azure.com/<org>
#   git config --global work.adoProject '<project>'
#   git config --global work.root '<drive>:\<work root>'
# Each check is skipped (not false-green) when its key is unset, e.g. in CI. The project-brain
# plugin check needs no config: a projected plugin must not carry ANY absolute drive path.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:PluginRoot = 'ai-agents/skills/project-brain'

    function Get-WorkConfig
    {
        param([Parameter(Mandatory)] [string] $Key)
        $value = & git -C $script:RepoRoot config --get $Key 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return ([string] $value).Trim()
    }

    # Tracked files (working-tree content) matching a fixed string, case-insensitive. Returns
    # "path:line" only, never the matched text, so a failure message doesn't echo the value.
    function Find-TrackedFixedString
    {
        param([Parameter(Mandatory)] [string] $Needle, [string[]] $PathSpec = @())
        $out = & git -C $script:RepoRoot grep -n -i -I -F -e $Needle -- @PathSpec 2>$null
        return @($out | ForEach-Object { ($_ -split ':', 3)[0..1] -join ':' })
    }
}

Describe 'public repo hygiene' {
    It 'does not name the employer in any tracked file' {
        $employer = Get-WorkConfig -Key 'work.employer'
        if (-not $employer)
        {
            Set-ItResult -Skipped -Because 'git config work.employer is not set'
            return
        }
        Find-TrackedFixedString -Needle $employer | Should -BeNullOrEmpty
    }

    It 'does not name the work Azure DevOps organisation in any tracked file' {
        $orgUrl = Get-WorkConfig -Key 'work.adoOrgUrl'
        if (-not $orgUrl)
        {
            Set-ItResult -Skipped -Because 'git config work.adoOrgUrl is not set'
            return
        }
        $org = ($orgUrl.TrimEnd('/') -split '/')[-1]
        $org | Should -Not -BeNullOrEmpty
        Find-TrackedFixedString -Needle $org | Should -BeNullOrEmpty
    }

    It 'does not name the work Azure DevOps project in any tracked file' {
        $project = Get-WorkConfig -Key 'work.adoProject'
        if (-not $project)
        {
            Set-ItResult -Skipped -Because 'git config work.adoProject is not set'
            return
        }
        Find-TrackedFixedString -Needle $project | Should -BeNullOrEmpty
    }

    It 'does not hardcode a drive path into the work root in any tracked file' {
        $workRoot = Get-WorkConfig -Key 'work.root'
        if (-not $workRoot)
        {
            Set-ItResult -Skipped -Because 'git config work.root is not set'
            return
        }
        # Match the root's own folder name after any drive letter and either separator, so
        # E:\<root>, e:/<root> and C:\Repos-style moves of the same root are all caught.
        $leaf = ($workRoot.TrimEnd('\', '/') -split '[\\/]')[-1]
        $leaf | Should -Not -BeNullOrEmpty
        $pattern = '(?<![A-Za-z])[A-Za-z]:[\\/]+' + [regex]::Escape($leaf)
        $out = & git -C $script:RepoRoot grep -n -i -I -P -e $pattern 2>$null
        @($out | ForEach-Object { ($_ -split ':', 3)[0..1] -join ':' }) | Should -BeNullOrEmpty
    }

    It 'keeps the project-brain plugin free of absolute Windows drive paths' {
        Test-Path -LiteralPath (Join-Path $script:RepoRoot $script:PluginRoot) -PathType Container |
            Should -BeTrue
        $out = & git -C $script:RepoRoot grep -n -I -P -e '(?<![A-Za-z0-9_])[A-Za-z]:[\\/]+[A-Za-z]' -- $script:PluginRoot 2>$null
        @($out | ForEach-Object { ($_ -split ':', 3)[0..1] -join ':' }) | Should -BeNullOrEmpty
    }
}
