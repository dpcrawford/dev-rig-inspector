function Compare-DevRigInspection {
    [CmdletBinding(DefaultParameterSetName = 'PathPath')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'PathPath')]
        [Parameter(Mandatory, ParameterSetName = 'PathObject')]
        [string] $ReferencePath,

        [Parameter(Mandatory, ParameterSetName = 'ObjectPath')]
        [Parameter(Mandatory, ParameterSetName = 'ObjectObject')]
        [object] $Reference,

        [Parameter(Mandatory, ParameterSetName = 'PathPath')]
        [Parameter(Mandatory, ParameterSetName = 'ObjectPath')]
        [string] $CurrentPath,

        [Parameter(Mandatory, ParameterSetName = 'PathObject')]
        [Parameter(Mandatory, ParameterSetName = 'ObjectObject')]
        [object] $Current,

        [switch] $JsonOnly,
        [switch] $PassThru,
        [string] $ReportPath
    )

    if ($JsonOnly -and $PassThru) {
        throw 'JsonOnly and PassThru cannot be used together.'
    }
    if ($JsonOnly -and $ReportPath) {
        throw 'JsonOnly and ReportPath cannot be used together.'
    }

    $referenceSnapshot = if ($PSCmdlet.ParameterSetName -in @('PathPath', 'PathObject')) {
        Read-InventorySnapshot -Path $ReferencePath -Label 'reference'
    } else {
        ConvertTo-ValidatedInventorySnapshot -Inventory $Reference -Label 'reference' -Path $null -SourceType 'Object'
    }

    $currentSnapshot = if ($PSCmdlet.ParameterSetName -in @('PathPath', 'ObjectPath')) {
        Read-InventorySnapshot -Path $CurrentPath -Label 'current'
    } else {
        ConvertTo-ValidatedInventorySnapshot -Inventory $Current -Label 'current' -Path $null -SourceType 'Object'
    }

    $changes = Compare-InventoryState -Reference $referenceSnapshot -Current $currentSnapshot
    $healthChanges = Compare-HealthState -Reference $referenceSnapshot.health -Current $currentSnapshot.health
    $changes = [pscustomobject]@{
        tools = $changes.tools
        findings = $changes.findings
        health = $healthChanges
    }
    $comparison = New-ComparisonResult -Reference $referenceSnapshot -Current $currentSnapshot -Changes $changes

    if ($JsonOnly) {
        return $comparison | ConvertTo-Json -Depth 12
    }

    if ($ReportPath) {
        $parent = Split-Path -Parent $ReportPath
        if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        ConvertTo-ComparisonMarkdown -Comparison $comparison | Set-Content -LiteralPath $ReportPath -Encoding utf8
    }

    Write-ComparisonConsole -Comparison $comparison
    if ($PassThru) {
        $comparison
    }
}
