# ============================================================================
# StagingNote.ps1 — `note`: append text to today's note in the Staging Obsidian vault
# ============================================================================
# Defines functions and the `note` alias only; NO side effects at dot-source.
# The Obsidian CLI (Obsidian.exe on PATH, app running) resolves the vault folder and
# today's daily-note path, and creates the note from the vault's `Daily` template. The
# text itself is appended straight to the file: the CLI's content= argument rewrites
# backslash sequences (C:\new becomes "C:" + newline + "ew"), and a command line caps
# its length.
# ============================================================================

function Invoke-ObsidianCli {
    <#
    .SYNOPSIS
    Run one Obsidian CLI command and return its trimmed output. Throws on a non-zero exit.
    #>
    [OutputType([string])]
    param([Parameter(Mandatory)][string[]]$Arguments)

    [System.Management.Automation.ApplicationInfo]$cli = Get-Command obsidian -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    # Capturing the output makes PowerShell wait for the GUI-subsystem exe to exit.
    [string]$output = (& $cli.Source @Arguments 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "obsidian $($Arguments -join ' ') failed with exit code ${LASTEXITCODE}: $output"
    }
    return $output
}

function Add-StagingNote {
    <#
    .SYNOPSIS
    Append a labelled section to today's daily note in the Staging vault.
    .DESCRIPTION
    Takes piped input (strings as-is, other objects formatted as the console shows them),
    or the clipboard when nothing is piped. Writes "## <Label>" followed by the text.
    Add a routing hint such as #to/work to the label; see Routing.md in the vault.
    .EXAMPLE
    herdr ... | note 'deploy output #to/work'
    .EXAMPLE
    note 'snippet from work PC'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Label,
        [Parameter(ValueFromPipeline)][object]$InputObject
    )

    begin {
        [System.Collections.Generic.List[object]]$items = [System.Collections.Generic.List[object]]::new()
    }
    process {
        if ($null -ne $InputObject) { $items.Add($InputObject) }
    }
    end {
        [string]$content = if ($items.Count) { $items | Out-String } else { Get-Clipboard -Raw }
        $content = ($content -replace "`r`n?", "`n").Trim("`n")
        if (-not $content.Trim()) {
            throw [System.ArgumentException]::new('Nothing to add: pipe text into note or copy it to the clipboard first.')
        }

        [string]$vault = 'Staging'
        [string]$vaultRoot = Invoke-ObsidianCli -Arguments @("vault=$vault", 'vault', 'info=path')
        [string]$relative = Invoke-ObsidianCli -Arguments @("vault=$vault", 'daily:path')
        [string]$file = Join-Path $vaultRoot $relative
        if (-not (Test-Path -LiteralPath $file)) {
            Invoke-ObsidianCli -Arguments @("vault=$vault", 'create', "path=$relative", 'template=Daily') | Out-Null
            if (-not (Test-Path -LiteralPath $file)) {
                throw [System.IO.FileNotFoundException]::new("Obsidian did not create today's note at $file", $file)
            }
        }

        [string]$existing = [System.IO.File]::ReadAllText($file)
        [string]$separator = if ($existing.Length -and -not $existing.EndsWith("`n")) { "`n" } else { '' }
        [System.IO.File]::AppendAllText($file, "$separator`n## $Label`n$content`n", [System.Text.UTF8Encoding]::new($false))
    }
}

Set-Alias -Name note -Value Add-StagingNote
