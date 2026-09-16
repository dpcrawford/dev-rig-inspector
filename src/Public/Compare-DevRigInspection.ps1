function Compare-DevRigInspection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ReferencePath,
        [Parameter(Mandatory)] [string] $CurrentPath,
        [switch] $JsonOnly,
        [switch] $PassThru
    )

    if ($JsonOnly -and $PassThru) {
        throw 'JsonOnly and PassThru cannot be used together.'
    }

    $reference = Read-InventorySnapshot -Path $ReferencePath -Label 'reference'
    $current = Read-InventorySnapshot -Path $CurrentPath -Label 'current'
    $changes = Compare-InventoryState -Reference $reference -Current $current
    $healthChanges = Compare-HealthState -Reference $reference.health -Current $current.health
    $changes = [pscustomobject]@{
        tools = $changes.tools
        findings = $changes.findings
        health = $healthChanges
    }
    $comparison = New-ComparisonResult -Reference $reference -Current $current -Changes $changes

    if ($JsonOnly) {
        return $comparison | ConvertTo-Json -Depth 12
    }

    Write-ComparisonConsole -Comparison $comparison
    if ($PassThru) {
        $comparison
    }
}
