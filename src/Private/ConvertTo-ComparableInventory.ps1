function Test-ComparableHealthSectionAvailable {
    param([object] $Section)
    $null -ne $Section -and @($Section.PSObject.Properties).Count -gt 0
}

function ConvertTo-ComparablePowerShellHealth {
    param([object] $Section)
    if (-not (Test-ComparableHealthSectionAvailable -Section $Section)) {
        return [pscustomobject]@{
            available = $false
            activeEvidenceAvailable = $false
            executionPolicyEvidenceAvailable = $false
            windowsPowerShellEvidenceAvailable = $false
            pwshSelectedPathEvidenceAvailable = $false
        }
    }

    $activeEvidenceAvailable = $null -ne $Section.active
    $executionPolicyEvidenceAvailable = $null -ne $Section.effectiveExecutionPolicy
    $windowsPowerShellEvidenceAvailable = $null -ne $Section.windowsPowerShell
    $pwshSelectedPathEvidenceAvailable = $null -ne $Section.powerShell7 -and $null -ne $Section.powerShell7.selectedCommand

    [pscustomobject]@{
        available = $true
        activeEvidenceAvailable = $activeEvidenceAvailable
        executionPolicyEvidenceAvailable = $executionPolicyEvidenceAvailable
        windowsPowerShellEvidenceAvailable = $windowsPowerShellEvidenceAvailable
        pwshSelectedPathEvidenceAvailable = $pwshSelectedPathEvidenceAvailable
        activeEdition = $Section.active.edition
        activeVersion = $Section.active.version
        activeExecutable = $Section.active.executable
        effectivePolicyScope = $Section.effectiveExecutionPolicy.scope
        effectivePolicyValue = $Section.effectiveExecutionPolicy.policy
        windowsPowerShellPresent = $Section.windowsPowerShell.present
        windowsPowerShellVersion = $Section.windowsPowerShell.version
        pwshSelectedPath = $Section.powerShell7.selectedCommand.path
    }
}

function ConvertTo-ComparableGitHealth {
    param([object] $Section)
    if (-not (Test-ComparableHealthSectionAvailable -Section $Section)) {
        return [pscustomobject]@{
            available = $false
            gitEvidenceAvailable = $false
            identityEvidenceAvailable = $false
            defaultBranchEvidenceAvailable = $false
            credentialHelperEvidenceAvailable = $false
            githubEvidenceAvailable = $false
            githubAuthEvidenceAvailable = $false
        }
    }

    $gitEvidenceAvailable = $null -ne $Section.git
    $identityEvidenceAvailable = $null -ne $Section.git.identity
    $defaultBranchEvidenceAvailable = $null -ne $Section.git.defaultBranch
    $credentialHelperEvidenceAvailable = $null -ne $Section.git.credentialHelper
    $githubEvidenceAvailable = $null -ne $Section.githubCli
    $githubAuthEvidenceAvailable = $null -ne $Section.githubCli.authentication

    [pscustomobject]@{
        available = $true
        gitEvidenceAvailable = $gitEvidenceAvailable
        identityEvidenceAvailable = $identityEvidenceAvailable
        defaultBranchEvidenceAvailable = $defaultBranchEvidenceAvailable
        credentialHelperEvidenceAvailable = $credentialHelperEvidenceAvailable
        githubEvidenceAvailable = $githubEvidenceAvailable
        githubAuthEvidenceAvailable = $githubAuthEvidenceAvailable
        gitInstalled = $Section.git.installed
        gitVersion = $Section.git.version
        identityNameConfigured = $Section.git.identity.name.configured
        identityEmailConfigured = $Section.git.identity.email.configured
        defaultBranchValue = $Section.git.defaultBranch.value
        autocrlfValue = $Section.git.autocrlf.value
        credentialHelperConfigured = $Section.git.credentialHelper.configured
        credentialHelperTypes = @($Section.git.credentialHelper.types)
        githubInstalled = $Section.githubCli.installed
        githubVersion = $Section.githubCli.version
        githubAuthenticated = $Section.githubCli.authentication.authenticated
        githubAuthHosts = @($Section.githubCli.authentication.hosts)
    }
}

function ConvertTo-ComparablePythonHealth {
    param([object] $Section)
    if (-not (Test-ComparableHealthSectionAvailable -Section $Section)) {
        return [pscustomobject]@{
            available = $false
            selectedEvidenceAvailable = $false
            runtimesEvidenceAvailable = $false
            pyLauncherEvidenceAvailable = $false
            uvEvidenceAvailable = $false
            virtualEnvironmentEvidenceAvailable = $false
            pipEvidenceAvailable = $false
        }
    }

    $selectedEvidenceAvailable = $null -ne $Section.selected
    $runtimesEvidenceAvailable = $null -ne $Section.runtimes
    $pyLauncherEvidenceAvailable = $null -ne $Section.pyLauncher
    $uvEvidenceAvailable = $null -ne $Section.uv
    $virtualEnvironmentEvidenceAvailable = $null -ne $Section.virtualEnvironment
    $pipEvidenceAvailable = $null -ne $Section.pip

    [pscustomobject]@{
        available = $true
        selectedEvidenceAvailable = $selectedEvidenceAvailable
        runtimesEvidenceAvailable = $runtimesEvidenceAvailable
        pyLauncherEvidenceAvailable = $pyLauncherEvidenceAvailable
        uvEvidenceAvailable = $uvEvidenceAvailable
        virtualEnvironmentEvidenceAvailable = $virtualEnvironmentEvidenceAvailable
        pipEvidenceAvailable = $pipEvidenceAvailable
        selectedPath = $Section.selected.path
        selectedVersion = $Section.selected.version
        selectedRunnable = $Section.selected.runnable
        runtimes = @($Section.runtimes | ForEach-Object {
            [pscustomobject]@{ path = [string] $_.path; version = [string] $_.version }
        })
        pyLauncherAvailable = $Section.pyLauncher.available
        pyLauncherReportedVersion = $Section.pyLauncher.reportedPythonVersion
        uvAvailable = $Section.uv.available
        uvVersion = $Section.uv.version
        virtualEnvironmentActive = $Section.virtualEnvironment.active
        virtualEnvironmentPath = $Section.virtualEnvironment.path
        virtualEnvironmentInterpreterExists = $Section.virtualEnvironment.interpreterExists
        pipAvailable = $Section.pip.available
        pipVersion = $Section.pip.version
    }
}

function ConvertTo-ComparableNodeHealth {
    param([object] $Section)
    if (-not (Test-ComparableHealthSectionAvailable -Section $Section)) {
        return [pscustomobject]@{
            available = $false
            nodeSelectedEvidenceAvailable = $false
            npmSelectedEvidenceAvailable = $false
            npmProbeEvidenceAvailable = $false
            npmPrefixEvidenceAvailable = $false
            npmGlobalPathEvidenceAvailable = $false
        }
    }

    $nodeSelectedEvidenceAvailable = $null -ne $Section.node -and $null -ne $Section.node.selected
    $npmSelectedEvidenceAvailable = $null -ne $Section.npm -and $null -ne $Section.npm.selectedCommand
    $npmProbeEvidenceAvailable = $null -ne $Section.npm -and $null -ne $Section.npm.probeCommand
    $npmPrefixEvidenceAvailable = $null -ne $Section.npm -and $null -ne $Section.npm.prefix
    $npmGlobalPathEvidenceAvailable = $null -ne $Section.npm -and ($null -ne $Section.npm.globalCommandPath -or $null -ne $Section.npm.globalPathExists -or $null -ne $Section.npm.globalPathOnPath)

    [pscustomobject]@{
        available = $true
        nodeSelectedEvidenceAvailable = $nodeSelectedEvidenceAvailable
        npmSelectedEvidenceAvailable = $npmSelectedEvidenceAvailable
        npmProbeEvidenceAvailable = $npmProbeEvidenceAvailable
        npmPrefixEvidenceAvailable = $npmPrefixEvidenceAvailable
        npmGlobalPathEvidenceAvailable = $npmGlobalPathEvidenceAvailable
        nodeSelectedPath = $Section.node.selected.path
        nodeVersion = $Section.node.selected.version
        nodeRunnable = $Section.node.runnable
        npmSelectedPath = $Section.npm.selectedCommand.path
        npmProbePath = $Section.npm.probeCommand.path
        npmVersion = $Section.npm.version
        npmPrefix = $Section.npm.prefix
        npmGlobalCommandPath = $Section.npm.globalCommandPath
        npmGlobalPathExists = $Section.npm.globalPathExists
        npmGlobalPathOnPath = $Section.npm.globalPathOnPath
    }
}

function Get-WslVersionToken {
    # The raw wsl --version text is multi-line and noisy; only the leading package version is stable enough to compare.
    param([string] $RawVersionText)
    if ([string]::IsNullOrWhiteSpace($RawVersionText)) { return $null }
    if ($RawVersionText -match '(?im)^\s*WSL version:\s*(\S+)') { return $Matches[1] }
    $null
}

function Get-WslDefaultVersionToken {
    param([string] $RawStatusText)
    if ([string]::IsNullOrWhiteSpace($RawStatusText)) { return $null }
    if ($RawStatusText -match '(?im)^\s*Default Version:\s*(\d+)') { return $Matches[1] }
    $null
}

function ConvertTo-ComparableVirtualizationHealth {
    param([object] $Section)
    if (-not (Test-ComparableHealthSectionAvailable -Section $Section)) {
        return [pscustomobject]@{
            available = $false
            capabilityEvidenceAvailable = $false
            hypervisorEvidenceAvailable = $false
            firmwareEvidenceAvailable = $false
            readinessEvidenceAvailable = $false
            wslEvidenceAvailable = $false
            wslDistributionsEvidenceAvailable = $false
        }
    }

    $capabilityEvidenceAvailable = $null -ne $Section.virtualizationCapability
    $hypervisorEvidenceAvailable = $null -ne $Section.hypervisorState
    $firmwareEvidenceAvailable = $null -ne $Section.firmwareVirtualization
    $readinessEvidenceAvailable = $null -ne $Section.readiness
    $wslEvidenceAvailable = $null -ne $Section.wsl
    # Windows optional features are not compared in Slice 2; no evidence-availability flag is modeled for them.
    $distributionsAvailable = $wslEvidenceAvailable -and $null -ne $Section.wsl.distributions -and $Section.wsl.distributionParseStatus -ne 'Unavailable'

    [pscustomobject]@{
        available = $true
        capabilityEvidenceAvailable = $capabilityEvidenceAvailable
        hypervisorEvidenceAvailable = $hypervisorEvidenceAvailable
        firmwareEvidenceAvailable = $firmwareEvidenceAvailable
        readinessEvidenceAvailable = $readinessEvidenceAvailable
        wslEvidenceAvailable = $wslEvidenceAvailable
        wslDistributionsEvidenceAvailable = $distributionsAvailable
        virtualizationCapability = $Section.virtualizationCapability
        hypervisorState = $Section.hypervisorState
        firmwareVirtualization = $Section.firmwareVirtualization
        wsl2Ready = $Section.readiness.wsl2Ready
        wslInstalled = $Section.wsl.installed
        wslPackageVersion = Get-WslVersionToken -RawVersionText $Section.wsl.version
        wslDefaultVersion = Get-WslDefaultVersionToken -RawStatusText $Section.wsl.status
        distributions = if ($distributionsAvailable) {
            @($Section.wsl.distributions | ForEach-Object {
                [pscustomobject]@{ name = [string] $_.name; version = [string] $_.version; state = [string] $_.state; isDefault = [bool] $_.isDefault }
            })
        } else { @() }
    }
}

function ConvertTo-ComparableInventory {
    param(
        [Parameter(Mandatory)] [object] $Inventory,
        # $null for object-sourced snapshots; never a fabricated path.
        $Path,
        [ValidateSet('File', 'Object')] [string] $SourceType = 'File'
    )

    $tools = @($Inventory.tools | ForEach-Object {
        [pscustomobject]@{
            id = [string] $_.id
            displayName = [string] $_.displayName
            status = [string] $_.status
            version = if ($null -ne $_.version) { [string] $_.version } else { $null }
        }
    })

    $findings = @($Inventory.diagnostics.findings | ForEach-Object {
        [pscustomobject]@{
            identity = Get-FindingIdentity -Finding $_
            code = [string] $_.code
            severity = [string] $_.severity
            category = [string] $_.category
            affectedComponent = [string] $_.affectedComponent
            title = [string] $_.title
            message = [string] $_.message
        }
    })

    $healthRoot = $Inventory.diagnostics.health
    $health = [pscustomobject]@{
        powerShell = ConvertTo-ComparablePowerShellHealth -Section $healthRoot.powerShell
        git = ConvertTo-ComparableGitHealth -Section $healthRoot.git
        python = ConvertTo-ComparablePythonHealth -Section $healthRoot.python
        node = ConvertTo-ComparableNodeHealth -Section $healthRoot.node
        virtualization = ConvertTo-ComparableVirtualizationHealth -Section $healthRoot.virtualization
    }

    [pscustomobject]@{
        sourceType = $SourceType
        path = $Path
        collectedAt = $Inventory.collectedAt
        schemaVersion = [string] $Inventory.schemaVersion
        collectorVersion = [string] $Inventory.collectorVersion
        hostname = $Inventory.computer.hostname
        cpuName = $Inventory.computer.cpu.name
        physicalMemoryBytes = $Inventory.computer.physicalMemoryBytes
        tools = $tools
        findings = $findings
        health = $health
    }
}
