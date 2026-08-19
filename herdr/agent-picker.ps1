#Requires -Version 7
<#
.SYNOPSIS
    fzf-backed picker for jumping directly to a live Herdr agent pane.

.DESCRIPTION
    Lists live agents via `herdr agent list`, joins in human-readable workspace/tab
    labels, and shows one line per agent in a bare-fzf picker (no PSFzf — this runs
    inside a Herdr `type = "popup"` command launched via cmd.exe /d /c; see
    herdr/config.toml and herdr/README.md). Selecting a line runs
    `herdr agent focus <pane_id>` on the pane_id hidden after the display line, and
    the popup closes, restoring focus to that pane. Esc/Ctrl-C in fzf, or an empty
    agent list, exit this script cleanly with no `herdr agent focus` call.

    Windows-only: the popup launcher mechanism (cmd.exe /d /c) is confirmed on
    Windows only; see herdr/README.md for the Linux/WSL caveat (issue #169).
#>

[CmdletBinding()]
param()

function ConvertTo-HerdrAgentPickerLines {
    <#
    .SYNOPSIS
    Build one fzf line per live agent: a human-readable display column, then a tab,
    then the raw pane_id — so the pane_id round-trips losslessly through fzf
    (hidden from view via --delimiter/--with-nth) regardless of title content.
    #>
    [OutputType([string[]])]
    param(
        [Parameter()][object[]]$Agents,
        [Parameter()][hashtable]$WorkspaceLabels = @{},
        [Parameter()][hashtable]$TabLabels = @{}
    )

    if (-not $Agents) {
        return @()
    }

    $Agents | ForEach-Object {
        $workspace = if ($WorkspaceLabels[$_.workspace_id]) { $WorkspaceLabels[$_.workspace_id] } else { $_.workspace_id }
        $tab = if ($TabLabels[$_.tab_id]) { $TabLabels[$_.tab_id] } else { $_.tab_id }
        $display = '{0,-8} {1,-8} {2} > {3} > {4}' -f $_.agent_status, $_.agent, $workspace, $tab, $_.terminal_title_stripped
        "$display`t$($_.pane_id)"
    }
}

function Get-HerdrPaneIdFromSelection {
    <#
    .SYNOPSIS
    Extract the pane_id appended by ConvertTo-HerdrAgentPickerLines after the last
    tab. Returns $null for an empty/whitespace/cancelled selection or a line with no
    tab delimiter.
    #>
    [OutputType([string])]
    param([Parameter()][string]$Selection)

    if ([string]::IsNullOrWhiteSpace($Selection)) {
        return $null
    }
    $trimmed = $Selection.Trim("`r", "`n")
    $lastTab = $trimmed.LastIndexOf("`t")
    if ($lastTab -lt 0) {
        return $null
    }
    $paneId = $trimmed.Substring($lastTab + 1).Trim()
    if ([string]::IsNullOrWhiteSpace($paneId)) {
        return $null
    }
    return $paneId
}

# --- Entry point ---------------------------------------------------------------
$listJson = herdr agent list
if ($LASTEXITCODE -ne 0) {
    Write-Host "herdr agent list failed: $listJson"
    Start-Sleep -Seconds 2
    return
}

$agents = ($listJson | ConvertFrom-Json).result.agents
if (-not $agents -or $agents.Count -eq 0) {
    Write-Host 'No live agents.'
    Start-Sleep -Seconds 1
    return
}

$workspaceListJson = herdr workspace list
if ($LASTEXITCODE -ne 0) {
    Write-Host "herdr workspace list failed: $workspaceListJson"
    Start-Sleep -Seconds 2
    return
}

$workspaceLabels = @{}
($workspaceListJson | ConvertFrom-Json).result.workspaces | ForEach-Object {
    $workspaceLabels[$_.workspace_id] = $_.label
}

$tabLabels = @{}
foreach ($workspaceId in ($agents.workspace_id | Select-Object -Unique)) {
    $tabListJson = herdr tab list --workspace $workspaceId
    if ($LASTEXITCODE -ne 0) {
        Write-Host "herdr tab list --workspace $workspaceId failed: $tabListJson"
        Start-Sleep -Seconds 2
        return
    }
    ($tabListJson | ConvertFrom-Json).result.tabs | ForEach-Object {
        $tabLabels[$_.tab_id] = $_.label
    }
}

$lines = ConvertTo-HerdrAgentPickerLines -Agents $agents -WorkspaceLabels $workspaceLabels -TabLabels $tabLabels

$selection = $lines | fzf --prompt 'agent> ' --delimiter "`t" --with-nth 1
$paneId = Get-HerdrPaneIdFromSelection -Selection $selection
if (-not $paneId) {
    return
}

$focus = herdr agent focus $paneId
if ($LASTEXITCODE -ne 0) {
    Write-Host "herdr agent focus $paneId failed (exit $LASTEXITCODE): $focus"
    Start-Sleep -Seconds 2
}
