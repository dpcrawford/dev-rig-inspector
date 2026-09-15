$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

function global:New-TestVirtualizationHealth {
    param(
        [string] $Hypervisor = 'Present',
        [string] $Firmware = 'Enabled',
        [string] $WslInstalled = 'Installed',
        [string] $WslFeature = 'Enabled',
        [string] $VmPlatform = 'Enabled',
        [object[]] $Distributions = @(),
        [string] $Wsl2Ready = 'Ready'
    )

    [pscustomobject]@{
        virtualizationCapability = 'Available'
        hypervisorState = $Hypervisor
        firmwareVirtualization = $Firmware
        features = @(
            [pscustomobject]@{ name = 'Microsoft-Windows-Subsystem-Linux'; state = $WslFeature; queryStatus = 'Available'; error = $null }
            [pscustomobject]@{ name = 'VirtualMachinePlatform'; state = $VmPlatform; queryStatus = 'Available'; error = $null }
        )
        wsl = [pscustomobject]@{
            installed = $WslInstalled -eq 'Installed'
            selectedCommand = if ($WslInstalled -eq 'Installed') { [pscustomobject]@{ path = 'C:\Windows\System32\wsl.exe' } } else { $null }
            version = 'WSL version: 2.0.0'
            statusAvailable = $true
            distributions = @($Distributions)
        }
        readiness = [pscustomobject]@{
            virtualizationCapability = 'Available'
            hypervisorState = $Hypervisor
            wslInstalled = $WslInstalled
            wslFeatureState = $WslFeature
            virtualMachinePlatformState = $VmPlatform
            distributionsPresent = if (@($Distributions).Count -gt 0) { 'Present' } else { 'None' }
            wsl2Ready = $Wsl2Ready
        }
    }
}

Describe 'WSL and virtualization health' {
    It 'reconciles hypervisor and firmware evidence without declaring active capability unavailable' {
        InModuleScope DevRigInspector {
            $hypervisorTrue = [pscustomobject]@{ HypervisorPresent = $true }
            $hypervisorFalse = [pscustomobject]@{ HypervisorPresent = $false }
            $firmwareTrue = @([pscustomobject]@{ DeviceID = 'CPU0'; Name = 'CPU'; VirtualizationFirmwareEnabled = $true; VMMonitorModeExtensions = $true; SecondLevelAddressTranslationExtensions = $true })
            $firmwareFalse = @([pscustomobject]@{ DeviceID = 'CPU0'; Name = 'CPU'; VirtualizationFirmwareEnabled = $false; VMMonitorModeExtensions = $false; SecondLevelAddressTranslationExtensions = $false })

            $activeEnabled = Get-VirtualizationCapabilityEvidence -ComputerSystem $hypervisorTrue -Processors $firmwareTrue
            $activeEnabled.virtualizationCapability | Should Be 'Available'
            $activeEnabled.firmwareVirtualization | Should Be 'Enabled'

            $activeFalse = Get-VirtualizationCapabilityEvidence -ComputerSystem $hypervisorTrue -Processors $firmwareFalse
            $activeFalse.virtualizationCapability | Should Be 'Available'
            $activeFalse.firmwareVirtualization | Should Be 'ConflictingEvidence'
            $activeFalse.evidence.hypervisor.source | Should Be 'Win32_ComputerSystem.HypervisorPresent'
            $activeFalse.evidence.processors[0].virtualizationFirmwareEnabled | Should Be $false

            $inactiveEnabled = Get-VirtualizationCapabilityEvidence -ComputerSystem $hypervisorFalse -Processors $firmwareTrue
            $inactiveEnabled.virtualizationCapability | Should Be 'Available'
            $inactiveEnabled.firmwareVirtualization | Should Be 'Enabled'

            $inactiveFalse = Get-VirtualizationCapabilityEvidence -ComputerSystem $hypervisorFalse -Processors $firmwareFalse
            $inactiveFalse.virtualizationCapability | Should Be 'Disabled'
            $inactiveFalse.firmwareVirtualization | Should Be 'Disabled'
        }
    }

    It 'treats unavailable firmware properties as unavailable and conflicting processor values as conflicting evidence' {
        InModuleScope DevRigInspector {
            $hypervisorFalse = [pscustomobject]@{ HypervisorPresent = $false }
            $missing = Get-VirtualizationCapabilityEvidence -ComputerSystem $hypervisorFalse -Processors @([pscustomobject]@{ DeviceID = 'CPU0'; Name = 'CPU' })
            $missing.firmwareVirtualization | Should Be 'Unavailable'
            $missing.virtualizationCapability | Should Be 'Unavailable'

            $conflicting = Get-VirtualizationCapabilityEvidence -ComputerSystem $hypervisorFalse -Processors @(
                [pscustomobject]@{ DeviceID = 'CPU0'; Name = 'CPU0'; VirtualizationFirmwareEnabled = $true }
                [pscustomobject]@{ DeviceID = 'CPU1'; Name = 'CPU1'; VirtualizationFirmwareEnabled = $false }
            )
            $conflicting.firmwareVirtualization | Should Be 'ConflictingEvidence'
            $conflicting.virtualizationCapability | Should Be 'Unavailable'
        }
    }

    It 'does not warn solely for conflicting firmware evidence when a hypervisor is active' {
        InModuleScope DevRigInspector {
            $health = New-TestVirtualizationHealth -Hypervisor 'Present' -Firmware 'ConflictingEvidence' -WslInstalled 'Installed' -Wsl2Ready 'Unknown'
            $findings = @(Get-VirtualizationHealthDiagnostics -VirtualizationHealth $health)
            @($findings | Where-Object severity -eq 'Warning').Count | Should Be 0
        }
    }

    It 'reports hypervisor and firmware enabled states as informational' {
        InModuleScope DevRigInspector {
            $findings = @(Get-VirtualizationHealthDiagnostics -VirtualizationHealth (New-TestVirtualizationHealth))
            ($findings | Where-Object code -eq 'HypervisorPresent').severity | Should Be 'Info'
            ($findings | Where-Object code -eq 'VirtualizationFirmwareEnabled').severity | Should Be 'Info'
        }
    }

    It 'reports unavailable firmware evidence as Info rather than disabled' {
        InModuleScope DevRigInspector {
            $findings = @(Get-VirtualizationHealthDiagnostics -VirtualizationHealth (New-TestVirtualizationHealth -Firmware 'Unavailable'))
            ($findings | Where-Object code -eq 'VirtualizationFirmwareUnavailable').severity | Should Be 'Info'
            @($findings | Where-Object code -eq 'VirtualizationFirmwareDisabled').Count | Should Be 0
        }
    }

    It 'reports optional WSL absence as informational only' {
        InModuleScope DevRigInspector {
            $health = New-TestVirtualizationHealth -WslInstalled 'NotInstalled' -WslFeature 'Disabled' -VmPlatform 'Disabled' -Wsl2Ready 'NotInstalled'
            $health.wsl.selectedCommand = $null
            $findings = @(Get-VirtualizationHealthDiagnostics -VirtualizationHealth $health)
            ($findings | Where-Object code -eq 'WSLNotInstalled').severity | Should Be 'Info'
            @($findings | Where-Object severity -eq 'Warning').Count | Should Be 0
        }
    }

    It 'reports WSL 1 and WSL 2 distributions as informational' {
        InModuleScope DevRigInspector {
            $distributions = @(
                [pscustomobject]@{ name = 'Ubuntu'; state = 'Running'; version = 2; isDefault = $true }
                [pscustomobject]@{ name = 'Legacy'; state = 'Stopped'; version = 1; isDefault = $false }
            )
            $findings = @(Get-VirtualizationHealthDiagnostics -VirtualizationHealth (New-TestVirtualizationHealth -Distributions $distributions))
            ($findings | Where-Object code -eq 'WSL2DistributionDetected').severity | Should Be 'Info'
            ($findings | Where-Object code -eq 'WSL1DistributionDetected').severity | Should Be 'Info'
            ($findings | Where-Object code -eq 'WSLReady').severity | Should Be 'Info'
        }
    }

    It 'warns only when configured WSL 2 is incomplete' {
        InModuleScope DevRigInspector {
            $distributions = @([pscustomobject]@{ name = 'Ubuntu'; state = 'Stopped'; version = 2; isDefault = $true })
            $health = New-TestVirtualizationHealth -Distributions $distributions -WslFeature 'Disabled' -VmPlatform 'Disabled' -Wsl2Ready 'Incomplete'
            $findings = @(Get-VirtualizationHealthDiagnostics -VirtualizationHealth $health)
            ($findings | Where-Object code -eq 'WSLIncomplete').severity | Should Be 'Warning'
            ($findings | Where-Object code -eq 'VirtualMachinePlatformDisabled').severity | Should Be 'Warning'
            ($findings | Where-Object code -eq 'WSLFeatureDisabled').severity | Should Be 'Warning'
        }
    }

    It 'preserves readiness evidence through JSON serialization' {
        InModuleScope DevRigInspector {
            $health = New-TestVirtualizationHealth
            $json = $health | ConvertTo-Json -Depth 12
            $json | Should Match 'wsl2Ready'
            $json | Should Match 'VirtualMachinePlatform'
        }
    }

    It 'parses WSL distribution rows defensively and leaves unparseable output empty' {
        InModuleScope DevRigInspector {
            $parsed = @(Get-WslDistributionEvidence -Output "`0  NAME      STATE           VERSION`0`n`0* Ubuntu   Running         2")
            $parsed.Count | Should Be 1
            $parsed[0].name | Should Be 'Ubuntu'
            $parsed[0].version | Should Be 2
            @(Get-WslDistributionEvidence -Output 'localized output without a version column').Count | Should Be 0
        }
    }

    It 'handles unavailable WSL and CIM queries without crashing' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand { [pscustomobject]@{ selected = $null; candidates = @() } }
            Mock Get-CimInstance { throw 'CIM unavailable' }
            Mock Get-WindowsOptionalFeature { throw 'feature query unavailable' }
            $result = Get-VirtualizationHealthInventory
            $result.status | Should Be 'Available'
            $result.data.wsl.installed | Should Be $false
            $result.data.firmwareVirtualization | Should Be 'Unavailable'
            $result.data.features[0].state | Should Be 'Unavailable'
        }
    }
}