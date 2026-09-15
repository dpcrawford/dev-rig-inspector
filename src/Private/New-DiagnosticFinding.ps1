function New-DiagnosticFinding {
    param(
        [Parameter(Mandatory)] [string] $Code,
        [Parameter(Mandatory)] [ValidateSet('Info', 'Warning', 'Error')] [string] $Severity,
        [Parameter(Mandatory)] [string] $Category,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $Message,
        [Parameter(Mandatory)] [string] $AffectedComponent,
        [object[]] $Evidence = @(),
        [Parameter(Mandatory)] [string] $Recommendation
    )

    [pscustomobject]@{
        code = $Code
        severity = $Severity
        category = $Category
        title = $Title
        message = $Message
        affectedComponent = $AffectedComponent
        evidence = @($Evidence)
        recommendation = $Recommendation
    }
}