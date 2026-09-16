function Get-HealthSubsystemLabel {
    param([string] $Subsystem)
    switch ($Subsystem) {
        'powerShell' { 'PowerShell' }
        'git' { 'Git / GitHub' }
        'python' { 'Python' }
        'node' { 'Node / npm' }
        'virtualization' { 'WSL / Virtualization' }
        default { $Subsystem }
    }
}

function Get-HealthFieldLabel {
    param([string] $Field)
    $labels = @{
        'active.edition' = 'PowerShell edition'
        'active.version' = 'PowerShell version'
        'active.executable' = 'Active executable'
        'effectiveExecutionPolicy.policy' = 'Execution policy'
        'effectiveExecutionPolicy.scope' = 'Execution policy scope'
        'windowsPowerShell.present' = 'Windows PowerShell present'
        'windowsPowerShell.version' = 'Windows PowerShell version'
        'powerShell7.selectedCommand.path' = 'Selected pwsh executable'
        'git.installed' = 'Git installed'
        'git.version' = 'Git version'
        'git.identity.name.configured' = 'Explicit name'
        'git.identity.email.configured' = 'Explicit email'
        'git.defaultBranch.value' = 'Default branch'
        'git.autocrlf.value' = 'Line-ending policy'
        'git.credentialHelper.configured' = 'Credential helper configured'
        'git.credentialHelper.types' = 'Credential helper'
        'githubCli.installed' = 'GitHub CLI installed'
        'githubCli.version' = 'GitHub CLI version'
        'githubCli.authentication.authenticated' = 'GitHub authentication'
        'githubCli.authentication.hosts' = 'GitHub authenticated host'
        'selected.path' = 'Selected interpreter'
        'selected.version' = 'Selected interpreter version'
        'selected.runnable' = 'Selected interpreter runnable'
        'runtimes' = 'Python runtime'
        'pyLauncher.available' = 'py launcher'
        'pyLauncher.reportedPythonVersion' = 'py launcher reported version'
        'uv.available' = 'uv'
        'uv.version' = 'uv version'
        'virtualEnvironment.active' = 'Virtual environment active'
        'virtualEnvironment.path' = 'Virtual environment path'
        'virtualEnvironment.interpreterExists' = 'Virtual environment interpreter'
        'pip.available' = 'pip'
        'pip.version' = 'pip version'
        'node.selected.path' = 'Selected Node executable'
        'node.selected.version' = 'Node version'
        'node.runnable' = 'Node runnable'
        'npm.selectedCommand.path' = 'npm shell launcher'
        'npm.probeCommand.path' = 'npm probe launcher'
        'npm.version' = 'npm version'
        'npm.prefix' = 'npm prefix'
        'npm.globalCommandPath' = 'npm global command path'
        'npm.globalPathExists' = 'npm global path exists'
        'npm.globalPathOnPath' = 'npm global path on PATH'
        'virtualizationCapability' = 'Virtualization capability'
        'hypervisorState' = 'Hypervisor'
        'firmwareVirtualization' = 'Firmware virtualization'
        'readiness.wsl2Ready' = 'WSL 2 readiness'
        'wsl.installed' = 'WSL installed'
        'wsl.version' = 'WSL version'
        'wsl.defaultVersion' = 'WSL default version'
        'wsl.distributions' = 'WSL distribution'
    }
    if ($labels.ContainsKey($Field)) { $labels[$Field] } else { $Field }
}

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

    $healthChanges = @($Comparison.changes.health)
    if ($healthChanges.Count -gt 0) {
        Write-Host ''
        Write-Host 'HEALTH'
        foreach ($group in ($healthChanges | Group-Object subsystem)) {
            Write-Host ''
            Write-Host ('  {0}' -f (Get-HealthSubsystemLabel $group.Name))
            foreach ($item in @($group.Group | Where-Object kind -eq 'Changed')) {
                $label = Get-HealthFieldLabel $item.field
                Write-Host ('    {0} changed' -f $item.changeType)
                Write-Host ('      {0}:' -f $label)
                Write-Host ('        Before: {0}' -f $item.before)
                Write-Host ('        Now:    {0}' -f $item.after)
            }
            $added = @($group.Group | Where-Object kind -eq 'Added')
            if ($added.Count -gt 0) {
                Write-Host '    Added'
                foreach ($item in $added) { Write-Host ('      {0}' -f $item.after) }
            }
            $removed = @($group.Group | Where-Object kind -eq 'Removed')
            if ($removed.Count -gt 0) {
                Write-Host '    Removed'
                foreach ($item in $removed) { Write-Host ('      {0}' -f $item.before) }
            }
        }
    }

    Write-Host ''
    Write-Host 'SUMMARY'
    Write-Host ('  Tool changes:       {0}' -f ($Comparison.summary.toolsAdded + $Comparison.summary.toolsRemoved + $Comparison.summary.toolsChanged))
    Write-Host ('  New findings:       {0}' -f $Comparison.summary.newFindings)
    Write-Host ('  Resolved findings:  {0}' -f $Comparison.summary.resolvedFindings)
    Write-Host ('  Severity changes:   {0}' -f $Comparison.summary.severityChanges)
    Write-Host ('  Health changes:     {0}' -f $Comparison.summary.healthChanges)
}
