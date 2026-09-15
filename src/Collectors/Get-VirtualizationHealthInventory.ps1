function Get-VirtualizationFeatureEvidence {
    param([Parameter(Mandatory)] [string] $Name)

    try {
        if (-not (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue)) {
            return [pscustomobject]@{ name = $Name; state = 'Unavailable'; queryStatus = 'Unavailable'; error = $null }
        }
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop
        $state = switch ([string] $feature.State) {
            'Enabled' { 'Enabled'; break }
            'Disabled' { 'Disabled'; break }
            default { 'Unknown' }
        }
        [pscustomobject]@{ name = $Name; state = $state; queryStatus = 'Available'; error = $null }
    } catch {
        [pscustomobject]@{ name = $Name; state = 'Unavailable'; queryStatus = 'Error'; error = $_.Exception.Message }
    }
}

function Get-WslDistributionEvidence {
    param([Parameter(Mandatory)] [string] $Output)

    $distributions = @()
    $lines = @($Output -replace "`0", '' -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 })
    foreach ($line in $lines) {
        if ($line -match '^\s*(\*)?\s*(.+?)\s{2,}(.+?)\s+([12])\s*$') {
            $distributions += [pscustomobject]@{
                name = $Matches[2].Trim()
                state = $Matches[3].Trim()
                version = [int] $Matches[4]
                isDefault = [bool] $Matches[1]
            }
        }
    }
    $distributions
}

function Invoke-WslHealthCommand {
    param(
        [Parameter(Mandatory)] [object] $Resolution,
        [Parameter(Mandatory)] [string[]] $Arguments
    )

    if (-not $Resolution.selected) { return $null }
    try { Invoke-ExternalCommand -FilePath $Resolution.selected.path -Arguments $Arguments } catch { $null }
}

function Get-VirtualizationCapabilityEvidence {
    param(
        [object] $ComputerSystem,
        [object[]] $Processors
    )

    $hypervisorRaw = if ($null -ne $ComputerSystem -and $null -ne $ComputerSystem.HypervisorPresent) { [bool] $ComputerSystem.HypervisorPresent } else { $null }
    $hypervisorState = if ($null -eq $hypervisorRaw) { 'Unavailable' } elseif ($hypervisorRaw) { 'Present' } else { 'NotPresent' }
    $firmwareValues = @($Processors | Where-Object { $null -ne $_.VirtualizationFirmwareEnabled } | ForEach-Object { [bool] $_.VirtualizationFirmwareEnabled })
    $firmwareState = if ($firmwareValues.Count -eq 0) {
        'Unavailable'
    } elseif (($firmwareValues | Select-Object -Unique).Count -gt 1 -or ($hypervisorState -eq 'Present' -and -not $firmwareValues[0])) {
        'ConflictingEvidence'
    } elseif ($firmwareValues[0]) {
        'Enabled'
    } else {
        'Disabled'
    }
    $capabilityState = if ($hypervisorState -eq 'Present' -or $firmwareState -eq 'Enabled') {
        'Available'
    } elseif ($firmwareState -eq 'Disabled') {
        'Disabled'
    } else {
        'Unavailable'
    }

    [pscustomobject]@{
        virtualizationCapability = $capabilityState
        hypervisorState = $hypervisorState
        firmwareVirtualization = $firmwareState
        evidence = [pscustomobject]@{
            hypervisor = [pscustomobject]@{
                source = 'Win32_ComputerSystem.HypervisorPresent'
                rawValue = $hypervisorRaw
                state = $hypervisorState
            }
            processors = @($Processors | ForEach-Object {
                [pscustomobject]@{
                    deviceId = $_.DeviceID
                    name = $_.Name
                    virtualizationFirmwareEnabled = $_.VirtualizationFirmwareEnabled
                    vmMonitorModeExtensions = $_.VMMonitorModeExtensions
                    secondLevelAddressTranslationExtensions = $_.SecondLevelAddressTranslationExtensions
                    source = 'Win32_Processor'
                }
            })
        }
    }
}

function Get-VirtualizationHealthInventory {
    $computerSystems = @()
    $processors = @()
    try { $computerSystems = @(Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop) } catch {}
    try { $processors = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop) } catch {}
    $capabilityEvidence = Get-VirtualizationCapabilityEvidence -ComputerSystem ($computerSystems | Select-Object -First 1) -Processors $processors
    $hypervisor = $capabilityEvidence.hypervisorState
    $firmware = $capabilityEvidence.firmwareVirtualization
    $capability = $capabilityEvidence.virtualizationCapability

    $features = @(
        Get-VirtualizationFeatureEvidence -Name 'Microsoft-Windows-Subsystem-Linux'
        Get-VirtualizationFeatureEvidence -Name 'VirtualMachinePlatform'
        Get-VirtualizationFeatureEvidence -Name 'Microsoft-Hyper-V-All'
    )
    $wslResolution = Resolve-ToolCommand -CommandName 'wsl'
    $wslVersion = Invoke-WslHealthCommand -Resolution $wslResolution -Arguments @('--version')
    $wslStatus = Invoke-WslHealthCommand -Resolution $wslResolution -Arguments @('--status')
    $wslList = Invoke-WslHealthCommand -Resolution $wslResolution -Arguments @('--list', '--verbose')
    $distributions = if ($wslList -and $wslList.exitCode -eq 0) { @(Get-WslDistributionEvidence -Output $wslList.standardOutput) } else { @() }
    $wslFeature = $features | Where-Object name -eq 'Microsoft-Windows-Subsystem-Linux' | Select-Object -First 1
    $vmPlatform = $features | Where-Object name -eq 'VirtualMachinePlatform' | Select-Object -First 1
    $hasWsl2 = @($distributions | Where-Object version -eq 2).Count -gt 0
    $requiredAvailable = $wslFeature.state -eq 'Enabled' -and $vmPlatform.state -eq 'Enabled' -and $firmware -eq 'Enabled'
    $wsl2Readiness = if (-not $wslResolution.selected) { 'NotInstalled' } elseif ($hasWsl2 -and $requiredAvailable) { 'Ready' } elseif ($requiredAvailable) { 'Available' } elseif ($hasWsl2) { 'Incomplete' } elseif ($wslFeature.state -eq 'Enabled') { 'Installed' } else { 'Unknown' }

    New-CollectorResult -CollectorId 'VirtualizationHealth' -Status Available -Data ([pscustomobject]@{
        virtualizationCapability = $capability
        hypervisorState = $hypervisor
        firmwareVirtualization = $firmware
        virtualizationEvidence = $capabilityEvidence.evidence
        features = $features
        wsl = [pscustomobject]@{
            installed = $null -ne $wslResolution.selected
            selectedCommand = $wslResolution.selected
            commandCandidates = @($wslResolution.candidates)
            version = if ($wslVersion -and $wslVersion.exitCode -eq 0) { ($wslVersion.standardOutput -replace "`0", '').Trim() } else { $null }
            versionAvailable = $null -ne $wslVersion -and $wslVersion.exitCode -eq 0
            statusAvailable = $null -ne $wslStatus -and $wslStatus.exitCode -eq 0
            status = if ($wslStatus -and $wslStatus.exitCode -eq 0) { ($wslStatus.standardOutput -replace "`0", '').Trim() } else { $null }
            distributions = @($distributions)
            distributionParseStatus = if ($wslList -and $wslList.exitCode -eq 0 -and $distributions.Count -eq 0) { 'NoneOrUnknown' } elseif ($wslList -and $wslList.exitCode -eq 0) { 'Parsed' } else { 'Unavailable' }
        }
        readiness = [pscustomobject]@{
            virtualizationCapability = $capability
            hypervisorState = $hypervisor
            wslInstalled = if ($wslResolution.selected) { 'Installed' } else { 'NotInstalled' }
            wslFeatureState = $wslFeature.state
            virtualMachinePlatformState = $vmPlatform.state
            distributionsPresent = if ($wslResolution.selected -and $distributions.Count -gt 0) { 'Present' } elseif ($wslResolution.selected) { 'None' } else { 'Unknown' }
            wsl2Ready = $wsl2Readiness
        }
    })
}