function Get-VirtualizationHealthDiagnostics {
    param([Parameter(Mandatory)] [object] $VirtualizationHealth)

    $findings = @()
    $wsl = $VirtualizationHealth.wsl
    $readiness = $VirtualizationHealth.readiness
    $distributions = @($wsl.distributions)
    $hasWsl2 = @($distributions | Where-Object version -eq 2).Count -gt 0

    if ($VirtualizationHealth.hypervisorState -eq 'Present') {
        $findings += New-DiagnosticFinding -Code 'HypervisorPresent' -Severity Info -Category 'Virtualization' -Title 'A hypervisor is present' -Message 'Windows reports that a hypervisor is present.' -AffectedComponent 'Virtualization.Hypervisor' -Evidence @([pscustomobject]@{ state = $VirtualizationHealth.hypervisorState }) -Recommendation 'No action is required.'
    }
    if ($VirtualizationHealth.firmwareVirtualization -eq 'Enabled') {
        $findings += New-DiagnosticFinding -Code 'VirtualizationFirmwareEnabled' -Severity Info -Category 'Virtualization' -Title 'Firmware virtualization is enabled' -Message 'Processor firmware virtualization is enabled.' -AffectedComponent 'Virtualization.Firmware' -Evidence @([pscustomobject]@{ state = $VirtualizationHealth.firmwareVirtualization }) -Recommendation 'No action is required.'
    } elseif ($VirtualizationHealth.firmwareVirtualization -eq 'Unavailable') {
        $findings += New-DiagnosticFinding -Code 'VirtualizationFirmwareUnavailable' -Severity Info -Category 'Virtualization' -Title 'Firmware virtualization state is unavailable' -Message 'Firmware virtualization could not be determined from the available processor evidence.' -AffectedComponent 'Virtualization.Firmware' -Evidence @([pscustomobject]@{ state = $VirtualizationHealth.firmwareVirtualization }) -Recommendation 'No action is required unless a virtualization-dependent workflow cannot start.'
    } elseif ($VirtualizationHealth.firmwareVirtualization -eq 'Disabled' -and $hasWsl2) {
        $findings += New-DiagnosticFinding -Code 'VirtualizationFirmwareDisabled' -Severity Warning -Category 'Virtualization' -Title 'Firmware virtualization is disabled for configured WSL 2' -Message 'Firmware virtualization is disabled while a WSL 2 distribution is configured.' -AffectedComponent 'Virtualization.Firmware' -Evidence @([pscustomobject]@{ state = $VirtualizationHealth.firmwareVirtualization; distributions = $distributions }) -Recommendation 'Enable firmware virtualization through approved firmware administration before relying on WSL 2.'
    }

    if (-not $wsl.installed) {
        $findings += New-DiagnosticFinding -Code 'WSLNotInstalled' -Severity Info -Category 'Virtualization' -Title 'WSL is not installed' -Message 'wsl.exe was not found; WSL is optional and no WSL-specific problem is inferred.' -AffectedComponent 'WSL' -Evidence @([pscustomobject]@{ installed = $false; readiness = $readiness }) -Recommendation 'No action is required unless WSL is needed for a development workflow.'
    } else {
        $findings += New-DiagnosticFinding -Code 'WSLInstalled' -Severity Info -Category 'Virtualization' -Title 'WSL is installed' -Message 'wsl.exe is available for inspection.' -AffectedComponent 'WSL' -Evidence @([pscustomobject]@{ command = $wsl.selectedCommand; version = $wsl.version; statusAvailable = $wsl.statusAvailable }) -Recommendation 'No action is required.'
        foreach ($distribution in $distributions) {
            $code = if ($distribution.version -eq 2) { 'WSL2DistributionDetected' } else { 'WSL1DistributionDetected' }
            $findings += New-DiagnosticFinding -Code $code -Severity Info -Category 'Virtualization' -Title ('WSL distribution detected: {0}' -f $distribution.name) -Message ('{0} is configured as WSL {1}.' -f $distribution.name, $distribution.version) -AffectedComponent ('WSL.Distribution.{0}' -f $distribution.name) -Evidence @($distribution) -Recommendation 'No action is required.'
        }
        if ($readiness.wsl2Ready -eq 'Ready' -or $readiness.wsl2Ready -eq 'Available') {
            $findings += New-DiagnosticFinding -Code 'WSLReady' -Severity Info -Category 'Virtualization' -Title 'WSL 2 capability is available' -Message ('WSL 2 readiness is {0} based on the inspected feature and virtualization evidence.' -f $readiness.wsl2Ready) -AffectedComponent 'WSL' -Evidence @($readiness) -Recommendation 'No action is required.'
        } elseif ($hasWsl2 -and $readiness.wsl2Ready -eq 'Incomplete') {
            $findings += New-DiagnosticFinding -Code 'WSLIncomplete' -Severity Warning -Category 'Virtualization' -Title 'Configured WSL 2 is incomplete' -Message 'A WSL 2 distribution is present, but one or more required virtualization components are disabled or unavailable.' -AffectedComponent 'WSL' -Evidence @([pscustomobject]@{ readiness = $readiness; features = $VirtualizationHealth.features; distributions = $distributions }) -Recommendation 'Review the reported feature and firmware states before using the configured WSL 2 distribution.'
            if ($readiness.virtualMachinePlatformState -eq 'Disabled') {
                $findings += New-DiagnosticFinding -Code 'VirtualMachinePlatformDisabled' -Severity Warning -Category 'Virtualization' -Title 'Virtual Machine Platform is disabled for WSL 2' -Message 'Virtual Machine Platform is disabled while a WSL 2 distribution is configured.' -AffectedComponent 'VirtualMachinePlatform' -Evidence @($VirtualizationHealth.features | Where-Object name -eq 'VirtualMachinePlatform') -Recommendation 'Enable the feature through approved Windows administration before relying on WSL 2.'
            }
            if ($readiness.wslFeatureState -eq 'Disabled') {
                $findings += New-DiagnosticFinding -Code 'WSLFeatureDisabled' -Severity Warning -Category 'Virtualization' -Title 'Windows Subsystem for Linux feature is disabled' -Message 'The WSL optional feature is disabled while a WSL 2 distribution is configured.' -AffectedComponent 'Microsoft-Windows-Subsystem-Linux' -Evidence @($VirtualizationHealth.features | Where-Object name -eq 'Microsoft-Windows-Subsystem-Linux') -Recommendation 'Enable the feature through approved Windows administration before relying on WSL 2.'
            }
        }
    }

    @($findings)
}