function Compare-DevRigInspection {
    <#
    .SYNOPSIS
    Compares saved or in-memory Dev Rig Inspector inventories.
    .DESCRIPTION
    Accepts a JSON file or inventory object independently for each side, validates
    schema compatibility, and compares normalized tools, findings, and selected
    health evidence. Does not recollect the machine or modify either baseline.
    Renders a console comparison by default. Missing health evidence is not
    automatically treated as a regression. This is not a diff of every property.
    .PARAMETER ReferencePath
    Path to the baseline inventory JSON. Use this or Reference, not both.
    .PARAMETER Reference
    Baseline inventory object, such as an Invoke-DevRigInspection PassThru result.
    Use this or ReferencePath, not both.
    .PARAMETER CurrentPath
    Path to the current inventory JSON. Use this or Current, not both.
    .PARAMETER Current
    Current inventory object, such as an Invoke-DevRigInspection PassThru result.
    Use this or CurrentPath, not both.
    .PARAMETER JsonOnly
    Returns comparison JSON as a string without rendering the console report.
    Cannot be combined with PassThru or ReportPath. Pipe to Set-Content to save JSON.
    .PARAMETER PassThru
    Returns the comparison object in addition to rendering the console report.
    Cannot be combined with JsonOnly.
    .PARAMETER ReportPath
    Writes a Markdown comparison and still renders the console report.
    Creates parent directories and overwrites an existing report.
    Cannot be combined with JsonOnly.
    .EXAMPLE
    Compare-DevRigInspection -ReferencePath .\baseline.json -CurrentPath .\inventory.json

    Compares two saved inventory files.
    .EXAMPLE
    $current = Invoke-DevRigInspection -PassThru
    Compare-DevRigInspection -ReferencePath .\baseline.json -Current $current -ReportPath .\comparison.md

    Compares a saved baseline to an object and saves Markdown.
    .EXAMPLE
    $comparison = Compare-DevRigInspection -Reference $baseline -Current $current -PassThru

    Compares two inventory objects and returns the structured result.
    .EXAMPLE
    Compare-DevRigInspection -Reference $baseline -CurrentPath .\inventory.json -JsonOnly | Set-Content .\comparison.json -Encoding utf8

    Compares an object to a file and saves comparison JSON.
    .OUTPUTS
    None by default. System.Management.Automation.PSCustomObject with PassThru.
    System.String with JsonOnly. Console rendering uses the information stream.
    .NOTES
    Requires Windows and PowerShell 7.0+. Accepts inventory schemas 0.1 and 0.2.
    Comparison schema 0.1; comparison implementation 0.5.0. Legacy raw tool fields
    do not create drift. Unsupported/missing schemas and malformed structures
    are rejected. Output may contain identifying metadata. See docs/comparison.md.
    #>
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
