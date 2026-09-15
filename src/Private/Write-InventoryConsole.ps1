function Write-InventoryConsole {
    param([Parameter(Mandatory)] [object] $Inventory)

    Write-Host 'System'
    Write-Host ('  Hostname:       {0}' -f $Inventory.computer.hostname)
    Write-Host ('  Windows:        {0} (build {1})' -f $Inventory.computer.windows.productName, $Inventory.computer.windows.buildNumber)
    Write-Host ('  CPU:            {0}' -f $Inventory.computer.cpu.name)
    Write-Host ('  Logical CPUs:   {0}' -f $Inventory.computer.cpu.logicalProcessors)
    Write-Host ('  Physical RAM:   {0:N1} GB' -f ($Inventory.computer.physicalMemoryBytes / 1GB))
    Write-Host '  Logical volumes:'
    foreach ($volume in $Inventory.computer.logicalVolumes) {
        Write-Host ('    {0}: {1:N1} GB free of {2:N1} GB' -f $volume.driveLetter, ($volume.freeBytes / 1GB), ($volume.sizeBytes / 1GB))
    }

    $powerShell = $Inventory.diagnostics.health.powerShell
    if ($powerShell -and $powerShell.active) {
        Write-Host ''
        Write-Host 'PowerShell'
        Write-Host ('  Active:         {0} {1}' -f $powerShell.active.edition, $powerShell.active.version)
        $windowsPowerShell = if ($powerShell.windowsPowerShell.present) { 'Present ({0})' -f $powerShell.windowsPowerShell.version } else { 'Not found' }
        Write-Host ('  Windows PS:     {0}' -f $windowsPowerShell)
        if ($powerShell.effectiveExecutionPolicy) {
            Write-Host ('  Execution:      {0} ({1})' -f $powerShell.effectiveExecutionPolicy.policy, $powerShell.effectiveExecutionPolicy.scope)
        }
        $pesterVersion = if (@($powerShell.pester).Count -gt 0) { ($powerShell.pester | Select-Object -First 1).version } else { 'Not found' }
        Write-Host ('  Pester:         {0}' -f $pesterVersion)
    }

    $gitHealth = $Inventory.diagnostics.health.git
    if ($gitHealth -and $gitHealth.git) {
        Write-Host ''
        Write-Host 'Git / GitHub'
        Write-Host ('  Git:            {0}' -f $(if ($gitHealth.git.version) { $gitHealth.git.version -replace '^git version ', '' } else { 'Not found' }))
        $identity = if ($gitHealth.git.identity.name.configured -and $gitHealth.git.identity.email.configured) { 'Explicitly configured' } else { 'Missing explicit configuration' }
        Write-Host ('  Identity:       {0}' -f $identity)
        $defaultBranch = if ($gitHealth.git.defaultBranch.configured) { $gitHealth.git.defaultBranch.value } else { 'Not configured' }
        Write-Host ('  Default branch: {0}' -f $defaultBranch)
        $autocrlf = if ($gitHealth.git.autocrlf.configured) { $gitHealth.git.autocrlf.value } else { 'Not configured' }
        Write-Host ('  Line endings:   {0}' -f $autocrlf)
        $ghVersion = if ($gitHealth.githubCli.version) { $gitHealth.githubCli.version -replace '^gh version\s+', '' -replace '\s+.*$', '' } else { 'Not found' }
        Write-Host ('  GitHub CLI:     {0}' -f $ghVersion)
        $authStatus = if ($gitHealth.githubCli.authentication.authenticated) { 'Authenticated' } elseif ($gitHealth.githubCli.authentication.checked) { 'Not authenticated' } else { 'Unavailable' }
        Write-Host ('  GitHub auth:    {0}' -f $authStatus)
    }

    $pythonHealth = $Inventory.diagnostics.health.python
    if ($pythonHealth -and $pythonHealth.selected) {
        Write-Host ''
        Write-Host 'Python'
        Write-Host ('  Active:         {0}' -f $pythonHealth.selected.version)
        Write-Host ('  Executable:     {0}' -f $pythonHealth.selected.path)
        $otherVersions = @($pythonHealth.runtimes | Where-Object { $_.path -ine $pythonHealth.selected.path } | Select-Object -ExpandProperty version -Unique)
        Write-Host ('  Also found:     {0}' -f $(if ($otherVersions.Count -gt 0) { $otherVersions -join ', ' } else { 'None' }))
        Write-Host ('  py launcher:    {0}' -f $(if ($pythonHealth.pyLauncher.available) { 'Available' } else { 'Unavailable' }))
        Write-Host ('  uv:              {0}' -f $(if ($pythonHealth.uv.available) { $pythonHealth.uv.version } else { 'Unavailable' }))
        $environment = if ($pythonHealth.virtualEnvironment.active) { $pythonHealth.virtualEnvironment.path } else { 'None active' }
        Write-Host ('  Environment:    {0}' -f $environment)
        Write-Host ('  pip:             {0}' -f $(if ($pythonHealth.pip.available) { 'Available' } else { 'Unavailable' }))
    }

    Write-Host ''
    Write-Host 'Development tools'
    $shadowedComponents = @($Inventory.diagnostics.findings |
        Where-Object { $_.code -eq 'CommandShadowing' } |
        ForEach-Object { $_.affectedComponent })
    foreach ($tool in $Inventory.tools) {
        $version = if ($tool.version) { $tool.version } else { '-' }
        Write-Host ('  {0,-16} {1,-12} {2}' -f $tool.displayName, $tool.status, $version)
        foreach ($diagnostic in $tool.diagnostics) {
            $sameInstallLocation = $false
            if ($diagnostic.code -eq 'PathShadowing') {
                $candidateDirectories = @($tool.allCommandCandidates |
                    ForEach-Object {
                        $directory = Split-Path -Parent $_.path
                        (ConvertTo-NormalizedPathEntry -RawEntry $directory).normalized
                    } |
                    Select-Object -Unique)
                $sameInstallLocation = $candidateDirectories.Count -le 1
            }
            if ($diagnostic.code -eq 'PathShadowing' -and ($sameInstallLocation -or $shadowedComponents -contains $tool.id)) {
                continue
            }
            Write-Host ('    [{0}] {1}' -f $diagnostic.severity, $diagnostic.message)
        }
    }

    if (@($Inventory.diagnostics.findings).Count -gt 0) {
        Write-Host ''
        Write-Host 'Diagnostics'
        foreach ($finding in $Inventory.diagnostics.findings) {
            Write-Host ('  [{0}] {1}: {2}' -f $finding.severity, $finding.code, $finding.message)
            Write-Host ('    Recommendation: {0}' -f $finding.recommendation)
        }
    }
}