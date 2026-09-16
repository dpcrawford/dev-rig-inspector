$implementationRoot = $PSScriptRoot

@(
    'Private/New-DiagnosticSummary.ps1'
    'Private/New-InventoryResults.ps1'
    'Private/New-DiagnosticFinding.ps1'
    'Private/Get-PathDiagnostics.ps1'
    'Private/Get-InventoryDiagnostics.ps1'
    'Private/Get-PowerShellHealthDiagnostics.ps1'
    'Private/Get-GitHealthDiagnostics.ps1'
    'Private/Get-PythonHealthDiagnostics.ps1'
    'Private/Get-NodeHealthDiagnostics.ps1'
    'Private/Get-VirtualizationHealthDiagnostics.ps1'
    'Private/Invoke-ExternalCommand.ps1'
    'Private/Resolve-ToolCommand.ps1'
    'Private/ConvertTo-InventoryJson.ps1'
    'Private/Write-InventoryLog.ps1'
    'Private/Write-InventoryConsole.ps1'
    'Private/ConvertTo-MarkdownText.ps1'
    'Private/ConvertTo-InventoryMarkdown.ps1'
    'Private/Get-FindingIdentity.ps1'
    'Private/ConvertTo-ComparableInventory.ps1'
    'Private/Read-InventorySnapshot.ps1'
    'Private/Compare-InventoryState.ps1'
    'Private/Compare-HealthState.ps1'
    'Private/New-ComparisonResult.ps1'
    'Private/Write-ComparisonConsole.ps1'
    'Private/ConvertTo-ComparisonMarkdown.ps1'
    'Collectors/ToolDefinitions.psd1'
    'Collectors/Get-SystemInventory.ps1'
    'Collectors/Get-DevelopmentToolInventory.ps1'
    'Collectors/Get-PowerShellHealthInventory.ps1'
    'Collectors/Get-GitHealthInventory.ps1'
    'Collectors/Get-PythonHealthInventory.ps1'
    'Collectors/Get-NodeHealthInventory.ps1'
    'Collectors/Get-VirtualizationHealthInventory.ps1'
    'Public/Invoke-DevRigInspection.ps1'
    'Public/Compare-DevRigInspection.ps1'
) | ForEach-Object {
    $path = Join-Path $implementationRoot $_
    if ($_.EndsWith('.psd1')) {
        $script:ToolDefinitions = Import-PowerShellDataFile -Path $path
    } else {
        . $path
    }
}

Export-ModuleMember -Function Invoke-DevRigInspection, Compare-DevRigInspection