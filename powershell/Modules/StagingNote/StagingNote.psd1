@{
    RootModule = 'StagingNote.psm1'
    ModuleVersion = '1.0.0'
    GUID = '69d1a683-fd34-424b-9ee3-e4b6ebcbecb3'
    Description = 'note: append text to today''s daily note in the Staging Obsidian vault.'
    PowerShellVersion = '7.0'

    # Explicit exports let PowerShell autoload the module the first time `note` or
    # Add-StagingNote runs, without an Import-Module in the profile.
    FunctionsToExport = @('Add-StagingNote')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @('note')
}
