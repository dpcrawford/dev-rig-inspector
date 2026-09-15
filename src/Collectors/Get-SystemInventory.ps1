function Get-SystemInventory {
    try {
        $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $windows = Get-ItemProperty -Path $registryPath -ErrorAction Stop
        $buildNumber = [int] $windows.CurrentBuildNumber
        $productName = [string] $windows.ProductName
        if ($buildNumber -ge 22000 -and $productName -match 'Windows 10') {
            $productName = $productName -replace 'Windows 10', 'Windows 11'
        }

        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $processor = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $volumes = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3" -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                driveLetter = $_.DeviceID
                label = $_.VolumeName
                fileSystem = $_.FileSystem
                sizeBytes = [int64] $_.Size
                freeBytes = [int64] $_.FreeSpace
            }
        })

        New-CollectorResult -CollectorId 'System' -Status Available -Data ([pscustomobject]@{
            hostname = $env:COMPUTERNAME
            windows = [pscustomobject]@{
                productName = $productName
                displayVersion = $windows.DisplayVersion
                releaseId = $windows.ReleaseId
                buildNumber = [string] $buildNumber
                currentVersion = $windows.CurrentVersion
                registryPath = $registryPath
            }
            cpu = [pscustomobject]@{
                name = $processor.Name
                physicalCores = [int] $processor.NumberOfCores
                logicalProcessors = [int] $processor.NumberOfLogicalProcessors
            }
            physicalMemoryBytes = [int64] $computerSystem.TotalPhysicalMemory
            logicalVolumes = $volumes
        })
    } catch {
        New-CollectorResult -CollectorId 'System' -Status Error -ErrorMessage $_.Exception.Message
    }
}