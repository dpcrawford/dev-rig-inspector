function Write-ComparisonConsole {
    param([Parameter(Mandatory)] [object] $Comparison)

    Write-Host 'Dev Rig Inspector Comparison'
    Write-Host ''
    Write-Host ('Reference: {0}' -f (Split-Path -Leaf $Comparison.reference.path))
    Write-Host ('Current:   {0}' -f (Split-Path -Leaf $Comparison.current.path))
    $machineLabel = switch ($Comparison.machineIdentity.state) {
        'LikelySame' { 'Likely same workstation' }
        'PossiblySame' { 'Possibly the same workstation' }
        'Different' { 'Likely a different workstation' }
        default { 'Insufficient evidence to compare machines' }
    }
    Write-Host ('Machine:   {0}' -f $machineLabel)

    if ($Comparison.summary.totalChanges -eq 0) {
        Write-Host ''
        Write-Host 'No changes detected.'
        return
    }

    $toolsChanged = @($Comparison.changes.tools | Where-Object kind -eq 'Changed')
    $toolsAdded = @($Comparison.changes.tools | Where-Object kind -eq 'Added')
    $toolsRemoved = @($Comparison.changes.tools | Where-Object kind -eq 'Removed')

    if ($toolsChanged.Count -gt 0 -or $toolsAdded.Count -gt 0 -or $toolsRemoved.Count -gt 0) {
        Write-Host ''
        Write-Host 'TOOLS'
        if ($toolsChanged.Count -gt 0) {
            Write-Host ''
            Write-Host '  Changed'
            foreach ($tool in $toolsChanged) {
                Write-Host ('    {0}' -f $tool.displayName)
                foreach ($field in $tool.fields) {
                    Write-Host ('      {0}: {1} -> {2}' -f $field.field, $field.before, $field.after)
                }
            }
        }
        if ($toolsAdded.Count -gt 0) {
            Write-Host ''
            Write-Host '  Added'
            foreach ($tool in $toolsAdded) {
                Write-Host ('    {0}' -f $tool.displayName)
            }
        }
        if ($toolsRemoved.Count -gt 0) {
            Write-Host ''
            Write-Host '  Removed'
            foreach ($tool in $toolsRemoved) {
                Write-Host ('    {0}' -f $tool.displayName)
            }
        }
    }

    $newFindings = @($Comparison.changes.findings | Where-Object kind -eq 'NewFinding')
    $resolvedFindings = @($Comparison.changes.findings | Where-Object kind -eq 'ResolvedFinding')
    $severityChanges = @($Comparison.changes.findings | Where-Object kind -eq 'SeverityChanged')

    if ($newFindings.Count -gt 0 -or $resolvedFindings.Count -gt 0 -or $severityChanges.Count -gt 0) {
        Write-Host ''
        Write-Host 'FINDINGS'
        if ($newFindings.Count -gt 0) {
            Write-Host ''
            Write-Host '  New'
            foreach ($finding in $newFindings) {
                Write-Host ('    [{0}] {1}' -f $finding.severity, $finding.code)
                Write-Host ('      {0}' -f $finding.affectedComponent)
            }
        }
        if ($resolvedFindings.Count -gt 0) {
            Write-Host ''
            Write-Host '  Resolved'
            foreach ($finding in $resolvedFindings) {
                Write-Host ('    {0}' -f $finding.code)
                Write-Host ('      {0}' -f $finding.affectedComponent)
            }
        }
        if ($severityChanges.Count -gt 0) {
            Write-Host ''
            Write-Host '  Severity changed'
            foreach ($finding in $severityChanges) {
                Write-Host ('    {0}' -f $finding.code)
                Write-Host ('      {0} -> {1}' -f $finding.severityBefore, $finding.severityAfter)
            }
        }
    }

    Write-Host ''
    Write-Host 'SUMMARY'
    Write-Host ('  Tool changes:       {0}' -f ($Comparison.summary.toolsAdded + $Comparison.summary.toolsRemoved + $Comparison.summary.toolsChanged))
    Write-Host ('  New findings:       {0}' -f $Comparison.summary.newFindings)
    Write-Host ('  Resolved findings:  {0}' -f $Comparison.summary.resolvedFindings)
    Write-Host ('  Severity changes:   {0}' -f $Comparison.summary.severityChanges)
}
