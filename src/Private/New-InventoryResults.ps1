function New-CollectorResult {
    param(
        [Parameter(Mandatory)] [string] $CollectorId,
        [Parameter(Mandatory)] [ValidateSet('Available', 'Missing', 'Unsupported', 'Error', 'TimedOut')] [string] $Status,
        [object] $Data,
        [string] $ErrorMessage
    )

    [pscustomobject]@{
        collectorId = $CollectorId
        status = $Status
        data = $Data
        error = $ErrorMessage
    }
}

function New-InspectionResult {
    param(
        [Parameter(Mandatory)] [object] $Computer,
        [Parameter(Mandatory)] [object[]] $Tools,
        [Parameter(Mandatory)] [object[]] $CollectorResults,
        [object[]] $Findings = @()
    )

    [pscustomobject]@{
        schemaVersion = '0.1'
        collectorVersion = '0.2.1'
        collectedAt = [DateTime]::UtcNow.ToString('o')
        computer = $Computer
        tools = @($Tools)
        diagnostics = [pscustomobject]@{
            collectorResults = @($CollectorResults)
            findings = @($Findings)
        }
    }
}