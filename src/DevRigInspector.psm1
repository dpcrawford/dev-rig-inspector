$implementationRoot = $PSScriptRoot

@(
    'Private/New-InventoryResults.ps1'
    'Private/New-DiagnosticFinding.ps1'
    'Private/Get-PathDiagnostics.ps1'
    'Private/Get-InventoryDiagnostics.ps1'
    'Private/Get-PowerShellHealthDiagnostics.ps1'
    'Private/Get-GitHealthDiagnostics.ps1'
    'Private/Get-PythonHealthDiagnostics.ps1'
    'Private/Invoke-ExternalCommand.ps1'
    'Private/Resolve-ToolCommand.ps1'
    'Private/ConvertTo-InventoryJson.ps1'
    'Private/Write-InventoryLog.ps1'
    'Private/Write-InventoryConsole.ps1'
    'Collectors/ToolDefinitions.psd1'
    'Collectors/Get-SystemInventory.ps1'
    'Collectors/Get-DevelopmentToolInventory.ps1'
    'Collectors/Get-PowerShellHealthInventory.ps1'
    'Collectors/Get-GitHealthInventory.ps1'
    'Collectors/Get-PythonHealthInventory.ps1'
    'Public/Invoke-DevRigInspection.ps1'
) | ForEach-Object {
    $path = Join-Path $implementationRoot $_
    if ($_.EndsWith('.psd1')) {
        $script:ToolDefinitions = Import-PowerShellDataFile -Path $path
    } else {
        . $path
    }
}

Export-ModuleMember -Function Invoke-DevRigInspection