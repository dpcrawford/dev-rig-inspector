function ConvertTo-ComparableInventory {
    param(
        [Parameter(Mandatory)] [object] $Inventory,
        [Parameter(Mandatory)] [string] $Path
    )

    $tools = @($Inventory.tools | ForEach-Object {
        [pscustomobject]@{
            id = [string] $_.id
            displayName = [string] $_.displayName
            status = [string] $_.status
            version = if ($null -ne $_.version) { [string] $_.version } else { $null }
        }
    })

    $findings = @($Inventory.diagnostics.findings | ForEach-Object {
        [pscustomobject]@{
            identity = Get-FindingIdentity -Finding $_
            code = [string] $_.code
            severity = [string] $_.severity
            category = [string] $_.category
            affectedComponent = [string] $_.affectedComponent
            title = [string] $_.title
            message = [string] $_.message
        }
    })

    [pscustomobject]@{
        path = $Path
        collectedAt = $Inventory.collectedAt
        schemaVersion = [string] $Inventory.schemaVersion
        collectorVersion = [string] $Inventory.collectorVersion
        hostname = $Inventory.computer.hostname
        cpuName = $Inventory.computer.cpu.name
        physicalMemoryBytes = $Inventory.computer.physicalMemoryBytes
        tools = $tools
        findings = $findings
    }
}
