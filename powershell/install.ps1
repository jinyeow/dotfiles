$DocumentsPath = [Environment]::GetFolderPath("MyDocuments")
$PSProfileFile = "Microsoft.PowerShell_profile.ps1"

$Locations = @(
            # PowerShell v5
            "$($DocumentsPath)\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
            # VSCode PowerShell
            "$($DocumentsPath)\WindowsPowerShell\Microsoft.VSCode_profile.ps1",
            # PowerShell Core v7
            "$($DocumentsPath)\PowerShell\Microsoft.PowerShell_profile.ps1",
            # coc.nvim PowerShell
            "$($DocumentsPath)\PowerShell\coc.vim_profile.ps1"
        )

foreach ($loc in $Locations) {
    Write-Host "Linking Profile to $loc..."
    if (Test-Path $loc) {
        Remove-Item $loc -Force
    }

    New-Item -ItemType HardLink -Path $loc -Value $PSProfileFile
}

