# Test-run delete guard. Dot-source it as the first statement of each test file's top-level
# BeforeAll (tests/TestSafety.Tests.ps1 enforces this).
#
# While Invoke-Pester is on the call stack, Remove-Item (and its aliases) goes through a proxy
# that only removes FileSystem paths strictly inside the temp directory (TestDrive lives there)
# or strictly inside this repository outside .git. It refuses the real home folder, anything
# in it, and any ancestor of home, temp, or the repository, whatever a test's variables hold.
# Outside a Pester run the proxy passes straight through.
#
# Symlinks and junctions in a path are resolved before the check, on both the target and the
# protected paths.
#
# Not covered: .NET deletes ([IO.Directory]::Delete), shell rm, and child processes. The proxy
# stays defined in the session after Invoke-Pester returns, but it only checks paths while
# Invoke-Pester is on the call stack.

# Returns the full path with every symlink or junction along it replaced by its final target,
# so a link inside an allowed folder cannot reach a protected one. Parts that do not exist
# are kept as written.
function global:Resolve-TestSafetyPath
{
    param([string]$Path)

    $full = [IO.Path]::GetFullPath($Path)
    $current = [IO.Path]::GetPathRoot($full)
    $parts = $full.Substring($current.Length).Split(
        [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar),
        [StringSplitOptions]::RemoveEmptyEntries)
    foreach ($part in $parts)
    {
        $current = [IO.Path]::Combine($current, $part)
        $info = if ([IO.Directory]::Exists($current)) { [IO.DirectoryInfo]::new($current) }
        elseif ([IO.File]::Exists($current)) { [IO.FileInfo]::new($current) }
        if ($info -and $info.LinkTarget)
        {
            $final = $info.ResolveLinkTarget($true)
            if ($final) { $current = $final.FullName }
        }
    }
    $current.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

if (-not $global:TestSafetyState)
{
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $normalize = {
        param([string]$Path)
        Resolve-TestSafetyPath $Path
    }
    $homes = @([Environment]::GetFolderPath('UserProfile'), $HOME, $env:USERPROFILE) |
        Where-Object { $_ } | ForEach-Object { & $normalize $_ }
    $temp = & $normalize ([IO.Path]::GetTempPath())
    $repo = & $normalize $repoRoot
    $gitDir = & $normalize (Join-Path $repoRoot '.git')
    $global:TestSafetyState = [pscustomobject]@{
        Protected = @($homes + $temp + $repo + $gitDir | Select-Object -Unique)
        Allowed = @($temp, $repo)
        Denied = @($gitDir)
        Comparison = if ($IsWindows -or $env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    }
}

function global:Assert-TestSafetyRemoval
{
    param([string[]]$Path, [switch]$Literal)

    if (-not (Get-PSCallStack | Where-Object Command -EQ 'Invoke-Pester')) { return }
    $state = $global:TestSafetyState
    $sep = [IO.Path]::DirectorySeparatorChar
    $isUnder = { param($child, $parent) $child.StartsWith($parent + $sep, $state.Comparison) }
    $isSame = { param($a, $b) [string]::Equals($a, $b, $state.Comparison) }

    foreach ($p in $Path)
    {
        if ([string]::IsNullOrEmpty($p)) { continue }
        $provider = $null
        $targets = $null
        if (-not $Literal)
        {
            try { $targets = $ExecutionContext.SessionState.Path.GetResolvedProviderPathFromPSPath($p, [ref]$provider) } catch { $targets = $null }
        }
        if (-not $targets)
        {
            $drive = $null
            try
            {
                $targets = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p, [ref]$provider, [ref]$drive)
            }
            catch
            {
                throw "TestSafety: refusing to remove '$p': cannot resolve the path ($($_.Exception.Message))"
            }
        }
        if ($provider.Name -ne 'FileSystem') { continue }

        foreach ($raw in @($targets))
        {
            $target = Resolve-TestSafetyPath $raw
            foreach ($protected in $state.Protected)
            {
                if ((& $isSame $target $protected) -or (& $isUnder $protected $target))
                {
                    throw "TestSafety: refusing to remove '$target': it is, or contains, the protected path '$protected'"
                }
            }
            foreach ($denied in $state.Denied)
            {
                if (& $isUnder $target $denied)
                {
                    throw "TestSafety: refusing to remove '$target': it is inside '$denied'"
                }
            }
            if (-not @($state.Allowed | Where-Object { & $isUnder $target $_ }))
            {
                throw "TestSafety: refusing to remove '$target': tests may only remove paths inside the temp directory or the repository"
            }
        }
    }
}

function global:Assert-TestSafetyBound
{
    param([System.Collections.IDictionary]$Bound)
    if ($Bound.ContainsKey('LiteralPath')) { Assert-TestSafetyRemoval -Path $Bound['LiteralPath'] -Literal }
    if ($Bound.ContainsKey('Path')) { Assert-TestSafetyRemoval -Path $Bound['Path'] }
}

$proxy = [System.Management.Automation.ProxyCommand]::Create(
    [System.Management.Automation.CommandMetadata]::new((Get-Command Microsoft.PowerShell.Management\Remove-Item)))
foreach ($call in '$steppablePipeline.Begin($PSCmdlet)', '$steppablePipeline.Process($_)')
{
    if (-not $proxy.Contains($call)) { throw "TestSafety: unexpected Remove-Item proxy shape (missing $call)" }
    $proxy = $proxy.Replace($call, "Assert-TestSafetyBound `$PSBoundParameters`n        $call")
}
Set-Item -LiteralPath Function:\global:Remove-Item -Value ([scriptblock]::Create($proxy))
