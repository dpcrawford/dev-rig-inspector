function Write-InventoryConsole {
    param([Parameter(Mandatory)] [object] $Inventory)

    Write-Host 'System'
    Write-Host ('  Hostname:       {0}' -f $Inventory.computer.hostname)
    Write-Host ('  Windows:        {0} (build {1})' -f $Inventory.computer.windows.productName, $Inventory.computer.windows.buildNumber)
    Write-Host ('  CPU:            {0}' -f $Inventory.computer.cpu.name)
    Write-Host ('  Logical CPUs:   {0}' -f $Inventory.computer.cpu.logicalProcessors)
    Write-Host ('  Physical RAM:   {0:N1} GB' -f ($Inventory.computer.physicalMemoryBytes / 1GB))
    Write-Host '  Logical volumes:'
    foreach ($volume in $Inventory.computer.logicalVolumes) {
        Write-Host ('    {0}: {1:N1} GB free of {2:N1} GB' -f $volume.driveLetter, ($volume.freeBytes / 1GB), ($volume.sizeBytes / 1GB))
    }

    Write-Host ''
    Write-Host 'Development tools'
    foreach ($tool in $Inventory.tools) {
        $version = if ($tool.version) { $tool.version } else { '-' }
        Write-Host ('  {0,-16} {1,-12} {2}' -f $tool.displayName, $tool.status, $version)
        foreach ($diagnostic in $tool.diagnostics) {
            Write-Host ('    [{0}] {1}' -f $diagnostic.severity, $diagnostic.message)
        }
    }
}