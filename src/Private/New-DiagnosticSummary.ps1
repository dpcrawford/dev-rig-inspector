function Get-DiagnosticSeverityRank {
    param([string] $Severity)
    switch ($Severity) {
        'Error' { 0 }
        'Warning' { 1 }
        'Info' { 2 }
        default { 3 }
    }
}

function New-DiagnosticSummary {
    # Purely derived from findings; must never re-query the machine or independently diagnose anything.
    param([object[]] $Findings = @())

    $findings = @($Findings)
    $errorFindings = @($findings | Where-Object severity -eq 'Error')
    $warningFindings = @($findings | Where-Object severity -eq 'Warning')
    $infoFindings = @($findings | Where-Object severity -eq 'Info')

    $status = if ($errorFindings.Count -gt 0) {
        'Problems'
    } elseif ($warningFindings.Count -gt 0) {
        'Attention'
    } else {
        'Healthy'
    }

    $attentionSource = @($errorFindings) + @($warningFindings)
    $attention = @($attentionSource |
        Sort-Object -Property @{ Expression = { Get-DiagnosticSeverityRank -Severity $_.severity } }, 'code', 'affectedComponent', 'title', @{ Expression = { Get-FindingIdentity -Finding $_ } } |
        ForEach-Object {
            [pscustomobject]@{
                severity = $_.severity
                code = $_.code
                category = $_.category
                affectedComponent = $_.affectedComponent
                title = $_.title
                identity = Get-FindingIdentity -Finding $_
            }
        })

    $affectedSubsystems = @($attentionSource |
        Select-Object -ExpandProperty category -Unique |
        Sort-Object)

    [pscustomobject]@{
        status = $status
        errorCount = $errorFindings.Count
        warningCount = $warningFindings.Count
        infoCount = $infoFindings.Count
        affectedSubsystems = $affectedSubsystems
        attention = $attention
    }
}

function Resolve-SummaryAttentionFinding {
    # Looks up the authoritative finding behind a lean attention-list entry so renderers can show full detail.
    param(
        [object[]] $Findings = @(),
        [Parameter(Mandatory)] [object] $AttentionItem
    )

    @($Findings) | Where-Object { (Get-FindingIdentity -Finding $_) -eq $AttentionItem.identity } | Select-Object -First 1
}
