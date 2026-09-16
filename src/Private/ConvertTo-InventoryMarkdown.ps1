function ConvertTo-InventoryMarkdown {
    param([Parameter(Mandatory)] [object] $Inventory)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Dev Rig Inspector Report')
    $lines.Add('')
    $lines.Add(('**Collected:** {0}' -f (ConvertTo-MarkdownText $Inventory.collectedAt)))
    $lines.Add(('**Computer:** {0}' -f (ConvertTo-MarkdownCode $Inventory.computer.hostname)))
    $windowsLabel = if ($Inventory.computer.windows) {
        '{0}, build {1}' -f $Inventory.computer.windows.productName, $Inventory.computer.windows.buildNumber
    } else {
        'Unavailable'
    }
    $lines.Add(('**Windows:** {0}' -f (ConvertTo-MarkdownText $windowsLabel)))
    $lines.Add(('**Collector:** {0}' -f (ConvertTo-MarkdownCode $Inventory.collectorVersion)))
    $lines.Add('')

    $findings = @($Inventory.diagnostics.findings)
    $errorFindings = @($findings | Where-Object severity -eq 'Error')
    $warningFindings = @($findings | Where-Object severity -eq 'Warning')
    $infoFindings = @($findings | Where-Object severity -eq 'Info')

    $lines.Add('## Summary')
    $lines.Add('')
    $lines.Add(('- Errors: {0}' -f $errorFindings.Count))
    $lines.Add(('- Warnings: {0}' -f $warningFindings.Count))
    $lines.Add(('- Informational findings: {0}' -f $infoFindings.Count))
    $lines.Add('')

    $attentionFindings = @($errorFindings) + @($warningFindings)
    if ($attentionFindings.Count -gt 0) {
        $lines.Add('## Attention Required')
        $lines.Add('')
        foreach ($finding in $attentionFindings) {
            $lines.Add(('### {0}: {1}' -f $finding.severity, (ConvertTo-MarkdownText $finding.title)))
            $lines.Add('')
            $lines.Add(('**Component:** {0}' -f (ConvertTo-MarkdownCode $finding.affectedComponent)))
            $lines.Add('')
            $lines.Add((ConvertTo-MarkdownParagraph $finding.message))
            $lines.Add('')
            $lines.Add(('**Recommendation:** {0}' -f (ConvertTo-MarkdownText $finding.recommendation)))
            $lines.Add('')
        }
    }

    $lines.Add('## Development Tools')
    $lines.Add('')
    $lines.Add('| Tool | Version | Status |')
    $lines.Add('|------|---------|--------|')
    foreach ($tool in $Inventory.tools) {
        $versionCell = if ($tool.version) { ConvertTo-MarkdownTableCell -Value $tool.version -AsCode } else { [char] 0x2014 }
        $lines.Add(('| {0} | {1} | {2} |' -f (ConvertTo-MarkdownTableCell $tool.displayName), $versionCell, (ConvertTo-MarkdownTableCell $tool.status)))
    }
    $lines.Add('')

    $powerShell = $Inventory.diagnostics.health.powerShell
    if ($powerShell -and $powerShell.active) {
        $lines.Add('## PowerShell')
        $lines.Add('')
        $lines.Add(('- **Active:** {0} {1}' -f (ConvertTo-MarkdownText $powerShell.active.edition), (ConvertTo-MarkdownCode $powerShell.active.version)))
        $windowsPowerShellLabel = if ($powerShell.windowsPowerShell.present) { 'Present ({0})' -f $powerShell.windowsPowerShell.version } else { 'Not found' }
        $lines.Add(('- **Windows PowerShell:** {0}' -f (ConvertTo-MarkdownText $windowsPowerShellLabel)))
        if ($powerShell.effectiveExecutionPolicy) {
            $lines.Add(('- **Execution policy:** {0} ({1})' -f (ConvertTo-MarkdownText $powerShell.effectiveExecutionPolicy.policy), (ConvertTo-MarkdownText $powerShell.effectiveExecutionPolicy.scope)))
        }
        $pesterVersion = if (@($powerShell.pester).Count -gt 0) { ($powerShell.pester | Select-Object -First 1).version } else { 'Not found' }
        $lines.Add(('- **Pester:** {0}' -f (ConvertTo-MarkdownText $pesterVersion)))
        $lines.Add('')
    }

    $gitHealth = $Inventory.diagnostics.health.git
    if ($gitHealth -and $gitHealth.git) {
        $lines.Add('## Git / GitHub')
        $lines.Add('')
        $gitVersion = if ($gitHealth.git.version) { $gitHealth.git.version -replace '^git version ', '' } else { 'Not found' }
        $lines.Add(('- **Git:** {0}' -f (ConvertTo-MarkdownText $gitVersion)))
        $identityLabel = if ($gitHealth.git.identity.name.configured -and $gitHealth.git.identity.email.configured) { 'Explicitly configured' } else { 'Missing explicit configuration' }
        $lines.Add(('- **Identity:** {0}' -f (ConvertTo-MarkdownText $identityLabel)))
        $defaultBranch = if ($gitHealth.git.defaultBranch.configured) { $gitHealth.git.defaultBranch.value } else { 'Not configured' }
        $lines.Add(('- **Default branch:** {0}' -f (ConvertTo-MarkdownText $defaultBranch)))
        $autocrlf = if ($gitHealth.git.autocrlf.configured) { $gitHealth.git.autocrlf.value } else { 'Not configured' }
        $lines.Add(('- **Line endings:** {0}' -f (ConvertTo-MarkdownText $autocrlf)))
        $ghVersion = if ($gitHealth.githubCli.version) { $gitHealth.githubCli.version -replace '^gh version\s+', '' -replace '\s+.*$', '' } else { 'Not found' }
        $lines.Add(('- **GitHub CLI:** {0}' -f (ConvertTo-MarkdownText $ghVersion)))
        $authStatus = if ($gitHealth.githubCli.authentication.authenticated) { 'Authenticated' } elseif ($gitHealth.githubCli.authentication.checked) { 'Not authenticated' } else { 'Unavailable' }
        $lines.Add(('- **GitHub auth:** {0}' -f (ConvertTo-MarkdownText $authStatus)))
        $lines.Add('')
    }

    $pythonHealth = $Inventory.diagnostics.health.python
    if ($pythonHealth -and $pythonHealth.selected) {
        $lines.Add('## Python')
        $lines.Add('')
        $lines.Add(('- **Active:** {0}' -f (ConvertTo-MarkdownCode $pythonHealth.selected.version)))
        $lines.Add(('- **Executable:** {0}' -f (ConvertTo-MarkdownCode $pythonHealth.selected.path)))
        $otherVersions = @($pythonHealth.runtimes | Where-Object { $_.path -ine $pythonHealth.selected.path } | Select-Object -ExpandProperty version -Unique)
        $lines.Add(('- **Also found:** {0}' -f $(if ($otherVersions.Count -gt 0) { ($otherVersions | ForEach-Object { ConvertTo-MarkdownCode $_ }) -join ', ' } else { 'None' })))
        $lines.Add(('- **py launcher:** {0}' -f $(if ($pythonHealth.pyLauncher.available) { 'Available' } else { 'Unavailable' })))
        $lines.Add(('- **uv:** {0}' -f $(if ($pythonHealth.uv.available) { ConvertTo-MarkdownCode $pythonHealth.uv.version } else { 'Unavailable' })))
        $environment = if ($pythonHealth.virtualEnvironment.active) { ConvertTo-MarkdownCode $pythonHealth.virtualEnvironment.path } else { 'None active' }
        $lines.Add(('- **Environment:** {0}' -f $environment))
        $lines.Add(('- **pip:** {0}' -f $(if ($pythonHealth.pip.available) { 'Available' } else { 'Unavailable' })))
        $lines.Add('')
    }

    $nodeHealth = $Inventory.diagnostics.health.node
    if ($nodeHealth -and $nodeHealth.node) {
        $lines.Add('## Node / npm')
        $lines.Add('')
        $lines.Add(('- **Node:** {0}' -f $(if ($nodeHealth.node.selected) { ConvertTo-MarkdownCode $nodeHealth.node.selected.version } else { 'Unavailable' })))
        $lines.Add(('- **Executable:** {0}' -f $(if ($nodeHealth.node.selected) { ConvertTo-MarkdownCode $nodeHealth.node.selected.path } else { 'Unavailable' })))
        $lines.Add(('- **npm:** {0}' -f $(if ($nodeHealth.npm.runnable) { ConvertTo-MarkdownCode $nodeHealth.npm.version } else { 'Unavailable' })))
        $launchers = @($nodeHealth.npm.launcherVariants | Select-Object -ExpandProperty name -Unique)
        $lines.Add(('- **Launchers:** {0}' -f $(if ($launchers.Count -gt 0) { ($launchers | ForEach-Object { ConvertTo-MarkdownCode $_ }) -join ', ' } else { 'None found' })))
        $lines.Add(('- **Global path:** {0}' -f $(if ($nodeHealth.npm.globalCommandPath) { ConvertTo-MarkdownCode $nodeHealth.npm.globalCommandPath } else { 'Unavailable' })))
        $globalStatus = if ($null -eq $nodeHealth.npm.globalPathExists) { 'Unknown' } elseif ($nodeHealth.npm.globalPathExists) { 'Exists' } else { 'Missing' }
        $lines.Add(('- **Global status:** {0}' -f $globalStatus))
        $lines.Add('')
    }

    $virtualization = $Inventory.diagnostics.health.virtualization
    if ($virtualization -and $virtualization.readiness) {
        $lines.Add('## WSL / Virtualization')
        $lines.Add('')
        $lines.Add(('- **Hypervisor:** {0}' -f (ConvertTo-MarkdownText $virtualization.readiness.hypervisorState)))
        $lines.Add(('- **Firmware VT:** {0}' -f (ConvertTo-MarkdownText $virtualization.firmwareVirtualization)))
        $lines.Add(('- **WSL:** {0}' -f (ConvertTo-MarkdownText $virtualization.readiness.wslInstalled)))
        $lines.Add(('- **WSL feature:** {0}' -f (ConvertTo-MarkdownText $virtualization.readiness.wslFeatureState)))
        $lines.Add(('- **VM Platform:** {0}' -f (ConvertTo-MarkdownText $virtualization.readiness.virtualMachinePlatformState)))
        $distributionSummary = if (@($virtualization.wsl.distributions).Count -gt 0) {
            (@($virtualization.wsl.distributions | ForEach-Object { ConvertTo-MarkdownCode ('{0} (WSL {1})' -f $_.name, $_.version) })) -join ', '
        } else {
            'None'
        }
        $lines.Add(('- **Distributions:** {0}' -f $distributionSummary))
        $lines.Add(('- **WSL 2 readiness:** {0}' -f (ConvertTo-MarkdownText $virtualization.readiness.wsl2Ready)))
        $lines.Add('')
    }

    if ($infoFindings.Count -gt 0) {
        $lines.Add('## Informational Findings')
        $lines.Add('')
        foreach ($finding in $infoFindings) {
            $lines.Add(('- **{0}:** {1}' -f (ConvertTo-MarkdownText $finding.code), (ConvertTo-MarkdownText $finding.message)))
        }
        $lines.Add('')
    }

    ($lines -join [Environment]::NewLine).TrimEnd() + [Environment]::NewLine
}
