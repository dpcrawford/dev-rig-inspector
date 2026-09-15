$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

Describe 'Get-SystemInventory' {
    It 'normalizes Windows 11 from registry build data' {
        InModuleScope DevRigInspector {
            Mock Get-ItemProperty {
                [pscustomobject]@{
                    ProductName = 'Windows 10 Pro'
                    CurrentBuildNumber = '22631'
                    DisplayVersion = '23H2'
                    ReleaseId = $null
                    CurrentVersion = '10.0'
                }
            }
            Mock Get-CimInstance {
                param($ClassName)
                switch ($ClassName) {
                    'Win32_ComputerSystem' { return [pscustomobject]@{ NumberOfLogicalProcessors = 16; TotalPhysicalMemory = 32GB } }
                    'Win32_Processor' { return [pscustomobject]@{ Name = 'Test CPU'; NumberOfCores = 8; NumberOfLogicalProcessors = 16 } }
                    'Win32_LogicalDisk' { return [pscustomobject]@{ DeviceID = 'C:'; VolumeName = 'Windows'; FileSystem = 'NTFS'; Size = 100GB; FreeSpace = 40GB } }
                }
            }

            $result = Get-SystemInventory
            $result.status | Should Be 'Available'
            $result.data.windows.productName | Should Be 'Windows 11 Pro'
            $result.data.cpu.physicalCores | Should Be 8
            $result.data.logicalVolumes.Count | Should Be 1
        }
    }
}