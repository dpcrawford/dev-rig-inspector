function Get-MachineIdentityAssessment {
    param(
        [Parameter(Mandatory)] [object] $Reference,
        [Parameter(Mandatory)] [object] $Current
    )

    $refHost = $Reference.hostname
    $curHost = $Current.hostname
    $refCpu = $Reference.cpuName
    $curCpu = $Current.cpuName
    $refMem = $Reference.physicalMemoryBytes
    $curMem = $Current.physicalMemoryBytes

    $hostnameKnown = -not [string]::IsNullOrWhiteSpace($refHost) -and -not [string]::IsNullOrWhiteSpace($curHost)
    $cpuKnown = -not [string]::IsNullOrWhiteSpace($refCpu) -and -not [string]::IsNullOrWhiteSpace($curCpu)
    $memKnown = $null -ne $refMem -and $null -ne $curMem -and [double] $refMem -gt 0 -and [double] $curMem -gt 0

    if (-not $hostnameKnown -and -not $cpuKnown) {
        return [pscustomobject]@{
            state = 'Insufficient'
            reasons = @('Hostname and CPU evidence are unavailable in one or both snapshots.')
        }
    }

    $hostnameMatches = $hostnameKnown -and ($refHost -ieq $curHost)
    $cpuMatches = $cpuKnown -and ($refCpu -ieq $curCpu)
    $memClose = $memKnown -and ([math]::Abs([double] $refMem - [double] $curMem) -lt ([math]::Max([double] $refMem, [double] $curMem) * 0.05))

    if ($hostnameKnown -and $hostnameMatches) {
        $reasons = @("Hostname matches: $refHost")
        if ($cpuKnown -and -not $cpuMatches) {
            $reasons += 'CPU identifier differs; hardware may have changed on the same workstation.'
        }
        return [pscustomobject]@{ state = 'LikelySame'; reasons = $reasons }
    }

    if ($hostnameKnown -and -not $hostnameMatches) {
        if ($cpuMatches -and $memClose) {
            return [pscustomobject]@{
                state = 'PossiblySame'
                reasons = @("Hostname differs ($refHost vs $curHost), but CPU and memory characteristics closely resemble one another.")
            }
        }
        return [pscustomobject]@{
            state = 'Different'
            reasons = @("Hostname differs: $refHost vs $curHost")
        }
    }

    if ($cpuKnown) {
        if ($cpuMatches -and $memClose) {
            return [pscustomobject]@{
                state = 'PossiblySame'
                reasons = @('Hostname unavailable; CPU and memory characteristics resemble one another.')
            }
        }
        return [pscustomobject]@{
            state = 'Different'
            reasons = @('Hostname unavailable; CPU or memory characteristics differ.')
        }
    }

    [pscustomobject]@{ state = 'Insufficient'; reasons = @('Insufficient machine identity evidence.') }
}

function New-ComparisonResult {
    param(
        [Parameter(Mandatory)] [object] $Reference,
        [Parameter(Mandatory)] [object] $Current,
        [Parameter(Mandatory)] [object] $Changes
    )

    $machineIdentity = Get-MachineIdentityAssessment -Reference $Reference -Current $Current

    $toolsAdded = @($Changes.tools | Where-Object kind -eq 'Added').Count
    $toolsRemoved = @($Changes.tools | Where-Object kind -eq 'Removed').Count
    $toolsChanged = @($Changes.tools | Where-Object kind -eq 'Changed').Count
    $newFindings = @($Changes.findings | Where-Object kind -eq 'NewFinding').Count
    $resolvedFindings = @($Changes.findings | Where-Object kind -eq 'ResolvedFinding').Count
    $severityChanges = @($Changes.findings | Where-Object kind -eq 'SeverityChanged').Count
    $healthChanges = @($Changes.health).Count
    $healthSubsystemsChanged = @($Changes.health | Select-Object -ExpandProperty subsystem -Unique).Count

    [pscustomobject]@{
        comparisonSchemaVersion = '0.1'
        comparisonVersion = '0.5.0'
        reference = [pscustomobject]@{
            sourceType = $Reference.sourceType
            path = $Reference.path
            collectedAt = $Reference.collectedAt
            hostname = $Reference.hostname
            schemaVersion = $Reference.schemaVersion
            collectorVersion = $Reference.collectorVersion
        }
        current = [pscustomobject]@{
            sourceType = $Current.sourceType
            path = $Current.path
            collectedAt = $Current.collectedAt
            hostname = $Current.hostname
            schemaVersion = $Current.schemaVersion
            collectorVersion = $Current.collectorVersion
        }
        machineIdentity = $machineIdentity
        changes = [pscustomobject]@{
            tools = @($Changes.tools)
            findings = @($Changes.findings)
            health = @($Changes.health)
        }
        summary = [pscustomobject]@{
            toolsAdded = $toolsAdded
            toolsRemoved = $toolsRemoved
            toolsChanged = $toolsChanged
            newFindings = $newFindings
            resolvedFindings = $resolvedFindings
            severityChanges = $severityChanges
            healthChanges = $healthChanges
            healthSubsystemsChanged = $healthSubsystemsChanged
            totalChanges = $toolsAdded + $toolsRemoved + $toolsChanged + $newFindings + $resolvedFindings + $severityChanges + $healthChanges
        }
    }
}
