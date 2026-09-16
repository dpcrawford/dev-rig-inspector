function Invoke-DevRigInspection {
    <#
    .SYNOPSIS
    Inspects a Windows development workstation without changing its configuration.
    .DESCRIPTION
    Collects system and development-tool inventory and subsystem health evidence,
    derives diagnostic findings and a summary, and renders a console report.
    Optional JSON, Markdown, and progress-log files are written only when requested.
    Missing optional capabilities and unavailable evidence are not automatically errors.
    .PARAMETER OutputPath
    Writes inventory JSON to this path, creating parent directories if needed.
    Overwrites an existing file. May be combined with ReportPath or JsonOnly.
    .PARAMETER ReportPath
    Writes a Markdown inventory report, creating parent directories if needed.
    Overwrites an existing file. Cannot be combined with JsonOnly.
    .PARAMETER LogPath
    Appends timestamped inspection progress and report locations to a log file.
    Creates parent directories if needed. Does not enable raw probe logging.
    .PARAMETER JsonOnly
    Returns inventory JSON as a string and skips the console report.
    Cannot be combined with PassThru or ReportPath. Supports OutputPath and LogPath.
    .PARAMETER PassThru
    Returns the inventory object in addition to rendering the console report.
    Cannot be combined with JsonOnly.
    .EXAMPLE
    Invoke-DevRigInspection

    Displays the current workstation report.
    .EXAMPLE
    $inventory = Invoke-DevRigInspection -PassThru

    Keeps the structured inventory for further inspection or comparison.
    .EXAMPLE
    Invoke-DevRigInspection -OutputPath .\inventory.json -ReportPath .\report.md

    Saves JSON and Markdown from the same collection and displays the report.
    .EXAMPLE
    $json = Invoke-DevRigInspection -JsonOnly

    Captures JSON without the console report.
    .OUTPUTS
    None by default. System.Management.Automation.PSCustomObject with PassThru.
    System.String with JsonOnly. Console rendering uses the information stream.
    .NOTES
    Requires Windows and PowerShell 7.0+. Windows PowerShell 5.1 is unsupported.
    Inventory schema 0.2; collector version 0.5.0. Reports contain identifying
    workstation metadata and are not anonymous. No automatic remediation occurs.
    Requested report/log files are expected outputs. See docs/privacy.md.
    #>
    [CmdletBinding()]
    param(
        [string] $OutputPath,
        [string] $ReportPath,
        [string] $LogPath,
        [switch] $JsonOnly,
        [switch] $PassThru
    )

    if ($JsonOnly -and $PassThru) {
        throw 'JsonOnly and PassThru cannot be used together.'
    }
    if ($JsonOnly -and $ReportPath) {
        throw 'JsonOnly and ReportPath cannot be used together.'
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
    $nodeHealthResult = Get-NodeHealthInventory
    $virtualizationHealthResult = Get-VirtualizationHealthInventory
    $computer = if ($systemResult.status -eq 'Available') { $systemResult.data } else { [pscustomobject]@{} }
    $tools = if ($toolsResult.status -eq 'Available') { @($toolsResult.data) } else { @() }
    $powerShellHealth = if ($powerShellHealthResult.status -eq 'Available') { $powerShellHealthResult.data } else { [pscustomobject]@{} }
    $gitHealth = if ($gitHealthResult.status -eq 'Available') { $gitHealthResult.data } else { [pscustomobject]@{} }
    $pythonHealth = if ($pythonHealthResult.status -eq 'Available') { $pythonHealthResult.data } else { [pscustomobject]@{} }
    $nodeHealth = if ($nodeHealthResult.status -eq 'Available') { $nodeHealthResult.data } else { [pscustomobject]@{} }
    $virtualizationHealth = if ($virtualizationHealthResult.status -eq 'Available') { $virtualizationHealthResult.data } else { [pscustomobject]@{} }
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
    if ($nodeHealthResult.status -eq 'Available') {
        $findings += Get-NodeHealthDiagnostics -NodeHealth $nodeHealth
    }
    if ($virtualizationHealthResult.status -eq 'Available') {
        $findings += Get-VirtualizationHealthDiagnostics -VirtualizationHealth $virtualizationHealth
    }
    $health = [pscustomobject]@{
        powerShell = $powerShellHealth
        git = $gitHealth
        python = $pythonHealth
        node = $nodeHealth
        virtualization = $virtualizationHealth
    }
    $inventory = New-InspectionResult -Computer $computer -Tools $tools -CollectorResults @($systemResult, $toolsResult) -Findings $findings -Health $health

    if ($OutputPath) {
        $parent = Split-Path -Parent $OutputPath
        if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        ConvertTo-InventoryJson -Inventory $inventory | Set-Content -LiteralPath $OutputPath -Encoding utf8
        Write-InventoryLog -Message "JSON written to $OutputPath." -Path $LogPath
    }
    if ($ReportPath) {
        $parent = Split-Path -Parent $ReportPath
        if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        ConvertTo-InventoryMarkdown -Inventory $inventory | Set-Content -LiteralPath $ReportPath -Encoding utf8
        Write-InventoryLog -Message "Markdown report written to $ReportPath." -Path $LogPath
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
