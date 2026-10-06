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
            LicenseUri = 'https://github.com/dpcrawford/dev-rig-inspector/blob/main/LICENSE'
            ReleaseNotes = 'v0.5.0: PowerShell 7 runtime guidance, versioned packaging, inventory schema 0.2 privacy hardening, and operator documentation/help.'
        }
    }
}
