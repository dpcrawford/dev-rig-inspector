function Invoke-DevRigInspection {
    [CmdletBinding()]
    param(
        [string] $OutputPath,
        [string] $LogPath,
        [switch] $JsonOnly,
        [switch] $PassThru
    )

    if ($JsonOnly -and $PassThru) {
        throw 'JsonOnly and PassThru cannot be used together.'
    }

    if ($LogPath) {
        $parent = Split-Path -Parent $LogPath
        if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    }
    Write-InventoryLog -Message 'Inspection started.' -Path $LogPath
    $systemResult = Get-SystemInventory
    $toolsResult = Get-DevelopmentToolInventory
    $powerShellHealthResult = Get-PowerShellHealthInventory
    $gitHealthResult = Get-GitHealthInventory
    $pythonHealthResult = Get-PythonHealthInventory
    $computer = if ($systemResult.status -eq 'Available') { $systemResult.data } else { [pscustomobject]@{} }
    $tools = if ($toolsResult.status -eq 'Available') { @($toolsResult.data) } else { @() }
    $powerShellHealth = if ($powerShellHealthResult.status -eq 'Available') { $powerShellHealthResult.data } else { [pscustomobject]@{} }
    $gitHealth = if ($gitHealthResult.status -eq 'Available') { $gitHealthResult.data } else { [pscustomobject]@{} }
    $pythonHealth = if ($pythonHealthResult.status -eq 'Available') { $pythonHealthResult.data } else { [pscustomobject]@{} }
    $findings = @(Get-InventoryDiagnostics -Tools $tools)
    if ($powerShellHealthResult.status -eq 'Available') {
        $findings += Get-PowerShellHealthDiagnostics -PowerShellHealth $powerShellHealth
    }
    if ($gitHealthResult.status -eq 'Available') {
        $findings += Get-GitHealthDiagnostics -GitHealth $gitHealth
    }
    if ($pythonHealthResult.status -eq 'Available') {
        $findings += Get-PythonHealthDiagnostics -PythonHealth $pythonHealth
    }
    $health = [pscustomobject]@{
        powerShell = $powerShellHealth
        git = $gitHealth
        python = $pythonHealth
    }
    $inventory = New-InspectionResult -Computer $computer -Tools $tools -CollectorResults @($systemResult, $toolsResult) -Findings $findings -Health $health

    if ($OutputPath) {
        $parent = Split-Path -Parent $OutputPath
        if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        ConvertTo-InventoryJson -Inventory $inventory | Set-Content -LiteralPath $OutputPath -Encoding utf8
        Write-InventoryLog -Message "JSON written to $OutputPath." -Path $LogPath
    }
    if ($JsonOnly) {
        Write-InventoryLog -Message 'Inspection completed.' -Path $LogPath
        return ConvertTo-InventoryJson -Inventory $inventory
    }
    Write-InventoryConsole -Inventory $inventory
    Write-InventoryLog -Message 'Inspection completed.' -Path $LogPath
    if ($PassThru) {
        $inventory
    }
}