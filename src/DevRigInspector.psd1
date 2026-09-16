@{
    RootModule = 'DevRigInspector.psm1'
    ModuleVersion = '0.5.0'
    GUID = 'a6d4cc24-c4b5-4d56-9b11-70a4f84575a1'
    Author = 'Dev Rig Inspector'
    Description = 'PowerShell-native Windows developer-workstation inventory, diagnostics, health, comparison, and reporting tool.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Invoke-DevRigInspection', 'Compare-DevRigInspection')
    PrivateData = @{
        PSData = @{
            Tags = @('Windows', 'PowerShell', 'Diagnostics', 'DeveloperTools', 'Inventory', 'Health')
            ProjectUri = 'https://github.com/dpcrawford/dev-rig-inspector'
            ReleaseNotes = 'v0.5.0: PowerShell 7 runtime/installation UX and versioned module packaging.'
        }
    }
}