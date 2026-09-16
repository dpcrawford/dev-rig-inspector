function ConvertTo-ComparisonMarkdown {
    param([Parameter(Mandatory)] [object] $Comparison)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Dev Rig Inspector Comparison')
    $lines.Add('')
    $lines.Add(('**Reference:** {0}' -f (ConvertTo-MarkdownText (Get-ComparisonSourceLabel $Comparison.reference))))
    $lines.Add(('**Current:** {0}' -f (ConvertTo-MarkdownText (Get-ComparisonSourceLabel $Comparison.current))))
    $machineLabel = switch ($Comparison.machineIdentity.state) {
        'LikelySame' { 'Likely same workstation' }
        'PossiblySame' { 'Possibly the same workstation' }
        'Different' { 'Likely a different workstation' }
        default { 'Insufficient evidence to compare machines' }
    }
    $lines.Add(('**Machine:** {0}' -f (ConvertTo-MarkdownText $machineLabel)))
    $lines.Add(('**Comparison schema:** {0}' -f (ConvertTo-MarkdownCode $Comparison.comparisonSchemaVersion)))
    $lines.Add(('**Comparison version:** {0}' -f (ConvertTo-MarkdownCode $Comparison.comparisonVersion)))
    $lines.Add(('**Reference collected:** {0}' -f (ConvertTo-MarkdownText $Comparison.reference.collectedAt)))
    $lines.Add(('**Current collected:** {0}' -f (ConvertTo-MarkdownText $Comparison.current.collectedAt)))
    $lines.Add('')

    $lines.Add('## Summary')
    $lines.Add('')
    $toolChangeCount = $Comparison.summary.toolsAdded + $Comparison.summary.toolsRemoved + $Comparison.summary.toolsChanged
    $lines.Add(('- Tool changes: {0}' -f $toolChangeCount))
    $lines.Add(('- Health changes: {0}' -f $Comparison.summary.healthChanges))
    $lines.Add(('- New findings: {0}' -f $Comparison.summary.newFindings))
    $lines.Add(('- Resolved findings: {0}' -f $Comparison.summary.resolvedFindings))
    $lines.Add(('- Severity changes: {0}' -f $Comparison.summary.severityChanges))
    $lines.Add('')

    if ($Comparison.summary.totalChanges -eq 0) {
        $lines.Add('No changes detected.')
        $lines.Add('')
        return ($lines -join [Environment]::NewLine).TrimEnd() + [Environment]::NewLine
    }

    $newFindings = @($Comparison.changes.findings | Where-Object kind -eq 'NewFinding')
    $resolvedFindings = @($Comparison.changes.findings | Where-Object kind -eq 'ResolvedFinding')
    $severityChanges = @($Comparison.changes.findings | Where-Object kind -eq 'SeverityChanged')

    if ($newFindings.Count -gt 0) {
        $lines.Add('## New Attention')
        $lines.Add('')
        foreach ($finding in $newFindings) {
            $lines.Add(('### {0}: {1}' -f $finding.severity, (ConvertTo-MarkdownText $finding.title)))
            $lines.Add('')
            $lines.Add(('**Component:** {0}' -f (ConvertTo-MarkdownCode $finding.affectedComponent)))
            $lines.Add('')
            $lines.Add((ConvertTo-MarkdownParagraph $finding.message))
            $lines.Add('')
        }
    }

    if ($severityChanges.Count -gt 0) {
        $lines.Add('## Severity Changes')
        $lines.Add('')
        foreach ($finding in $severityChanges) {
            $lines.Add(('### {0}' -f (ConvertTo-MarkdownText $finding.code)))
            $lines.Add('')
            $lines.Add(('**Component:** {0}' -f (ConvertTo-MarkdownCode $finding.affectedComponent)))
            $lines.Add('')
            $lines.Add(('{0} → {1}' -f (ConvertTo-MarkdownCode $finding.severityBefore), (ConvertTo-MarkdownCode $finding.severityAfter)))
            $lines.Add('')
        }
    }

    if ($resolvedFindings.Count -gt 0) {
        $lines.Add('## Resolved')
        $lines.Add('')
        foreach ($finding in $resolvedFindings) {
            $lines.Add(('### {0}' -f (ConvertTo-MarkdownText $finding.title)))
            $lines.Add('')
            $lines.Add(('**Component:** {0}' -f (ConvertTo-MarkdownCode $finding.affectedComponent)))
            $lines.Add('')
            $lines.Add((ConvertTo-MarkdownParagraph $finding.message))
            $lines.Add('')
        }
    }

    $healthChanges = @($Comparison.changes.health)
    if ($healthChanges.Count -gt 0) {
        $lines.Add('## Health Changes')
        $lines.Add('')
        foreach ($group in ($healthChanges | Group-Object subsystem)) {
            $lines.Add(('### {0}' -f (ConvertTo-MarkdownText (Get-HealthSubsystemLabel $group.Name))))
            $lines.Add('')
            foreach ($item in @($group.Group | Where-Object kind -eq 'Changed')) {
                $lines.Add(('**{0}**' -f (ConvertTo-MarkdownText (Get-HealthFieldLabel $item.field))))
                $lines.Add('')
                $lines.Add(('{0} → {1}' -f (ConvertTo-MarkdownCode $item.before), (ConvertTo-MarkdownCode $item.after)))
                $lines.Add('')
            }
            foreach ($item in @($group.Group | Where-Object kind -eq 'Added')) {
                $lines.Add(('Added: {0}' -f (ConvertTo-MarkdownCode $item.after)))
                $lines.Add('')
            }
            foreach ($item in @($group.Group | Where-Object kind -eq 'Removed')) {
                $lines.Add(('Removed: {0}' -f (ConvertTo-MarkdownCode $item.before)))
                $lines.Add('')
            }
        }
    }

    $toolsChanged = @($Comparison.changes.tools | Where-Object kind -eq 'Changed')
    $toolsAdded = @($Comparison.changes.tools | Where-Object kind -eq 'Added')
    $toolsRemoved = @($Comparison.changes.tools | Where-Object kind -eq 'Removed')

    if ($toolsChanged.Count -gt 0 -or $toolsAdded.Count -gt 0 -or $toolsRemoved.Count -gt 0) {
        $lines.Add('## Tool Changes')
        $lines.Add('')
        foreach ($tool in $toolsChanged) {
            $lines.Add(('### {0}' -f (ConvertTo-MarkdownText $tool.displayName)))
            $lines.Add('')
            foreach ($field in $tool.fields) {
                $lines.Add(('**{0}:** {1} → {2}' -f (ConvertTo-MarkdownText $field.field), (ConvertTo-MarkdownCode $field.before), (ConvertTo-MarkdownCode $field.after)))
                $lines.Add('')
            }
        }
        foreach ($tool in $toolsAdded) {
            $lines.Add(('### {0}' -f (ConvertTo-MarkdownText $tool.displayName)))
            $lines.Add('')
            $lines.Add('Added.')
            $lines.Add('')
        }
        foreach ($tool in $toolsRemoved) {
            $lines.Add(('### {0}' -f (ConvertTo-MarkdownText $tool.displayName)))
            $lines.Add('')
            $lines.Add('Removed.')
            $lines.Add('')
        }
    }

    ($lines -join [Environment]::NewLine).TrimEnd() + [Environment]::NewLine
}
