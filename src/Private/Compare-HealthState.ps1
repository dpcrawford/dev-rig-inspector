function Test-ComparableEvidenceGroup {
    param(
        $Reference,
        $Current,
        [string] $EvidenceKey
    )

    $referenceAvailable = $false
    $currentAvailable = $false

    if ($null -ne $Reference) {
        $referenceAvailable = $Reference.PSObject.Properties.Match($EvidenceKey).Count -gt 0 -and $null -ne $Reference.$EvidenceKey
    }
    if ($null -ne $Current) {
        $currentAvailable = $Current.PSObject.Properties.Match($EvidenceKey).Count -gt 0 -and $null -ne $Current.$EvidenceKey
    }

    $referenceAvailable -and $currentAvailable
}

function Compare-HealthScalarField {
    param(
        [Parameter(Mandatory)] [string] $Subsystem,
        [Parameter(Mandatory)] [string] $Field,
        [Parameter(Mandatory)] [string] $ChangeType,
        $Before,
        $After,
        [bool] $ReferenceAvailable = $true,
        [bool] $CurrentAvailable = $true
    )

    if (-not $ReferenceAvailable -or -not $CurrentAvailable) { return @() }

    $beforeIsNull = $null -eq $Before
    $afterIsNull = $null -eq $After
    if ($beforeIsNull -and $afterIsNull) { return @() }
    if (-not $beforeIsNull -and -not $afterIsNull -and $Before -eq $After) { return @() }

    @([pscustomobject]@{
        kind = 'Changed'
        subsystem = $Subsystem
        field = $Field
        changeType = $ChangeType
        before = $Before
        after = $After
    })
}

function Compare-HealthSet {
    param(
        [Parameter(Mandatory)] [string] $Subsystem,
        [Parameter(Mandatory)] [string] $FieldPrefix,
        [Parameter(Mandatory)] [string] $ChangeType,
        [object[]] $ReferenceItems = @(),
        [object[]] $CurrentItems = @(),
        [bool] $ReferenceAvailable = $true,
        [bool] $CurrentAvailable = $true
    )

    if (-not $ReferenceAvailable -or -not $CurrentAvailable) { return @() }

    $refSet = @($ReferenceItems | Select-Object -Unique)
    $curSet = @($CurrentItems | Select-Object -Unique)
    $changes = @()

    foreach ($item in $curSet) {
        if ($refSet -notcontains $item) {
            $changes += [pscustomobject]@{ kind = 'Added'; subsystem = $Subsystem; field = $FieldPrefix; changeType = $ChangeType; before = $null; after = $item }
        }
    }
    foreach ($item in $refSet) {
        if ($curSet -notcontains $item) {
            $changes += [pscustomobject]@{ kind = 'Removed'; subsystem = $Subsystem; field = $FieldPrefix; changeType = $ChangeType; before = $item; after = $null }
        }
    }

    @($changes)
}

function Compare-PythonRuntimeSet {
    param(
        [object[]] $Reference = @(),
        [object[]] $Current = @(),
        [bool] $ReferenceAvailable = $true,
        [bool] $CurrentAvailable = $true
    )

    if (-not $ReferenceAvailable -or -not $CurrentAvailable) { return @() }

    $refByKey = @{}
    foreach ($item in $Reference) { $refByKey[$item.path.ToLowerInvariant()] = $item }
    $curByKey = @{}
    foreach ($item in $Current) { $curByKey[$item.path.ToLowerInvariant()] = $item }

    $changes = @()
    foreach ($key in $curByKey.Keys) {
        if (-not $refByKey.ContainsKey($key)) {
            $item = $curByKey[$key]
            $changes += [pscustomobject]@{ kind = 'Added'; subsystem = 'python'; field = 'runtimes'; changeType = 'Availability'; before = $null; after = ('{0} ({1})' -f $item.path, $item.version) }
        }
    }
    foreach ($key in $refByKey.Keys) {
        if (-not $curByKey.ContainsKey($key)) {
            $item = $refByKey[$key]
            $changes += [pscustomobject]@{ kind = 'Removed'; subsystem = 'python'; field = 'runtimes'; changeType = 'Availability'; before = ('{0} ({1})' -f $item.path, $item.version); after = $null }
        }
    }

    @($changes)
}

function Compare-WslDistributionSet {
    param(
        [object[]] $Reference = @(),
        [object[]] $Current = @(),
        [bool] $ReferenceAvailable = $true,
        [bool] $CurrentAvailable = $true
    )

    if (-not $ReferenceAvailable -or -not $CurrentAvailable) { return @() }

    $refByKey = @{}
    foreach ($item in $Reference) { $refByKey[$item.name.ToLowerInvariant()] = $item }
    $curByKey = @{}
    foreach ($item in $Current) { $curByKey[$item.name.ToLowerInvariant()] = $item }

    $changes = @()
    foreach ($key in $curByKey.Keys) {
        if (-not $refByKey.ContainsKey($key)) {
            $item = $curByKey[$key]
            $changes += [pscustomobject]@{ kind = 'Added'; subsystem = 'virtualization'; field = 'wsl.distributions'; changeType = 'Availability'; before = $null; after = ('{0} (WSL {1})' -f $item.name, $item.version) }
        }
    }
    foreach ($key in $refByKey.Keys) {
        if (-not $curByKey.ContainsKey($key)) {
            $item = $refByKey[$key]
            $changes += [pscustomobject]@{ kind = 'Removed'; subsystem = 'virtualization'; field = 'wsl.distributions'; changeType = 'Availability'; before = ('{0} (WSL {1})' -f $item.name, $item.version); after = $null }
        }
    }
    foreach ($key in $refByKey.Keys) {
        if (-not $curByKey.ContainsKey($key)) { continue }
        $before = $refByKey[$key]
        $after = $curByKey[$key]
        if ($before.version -ne $after.version) {
            $changes += [pscustomobject]@{ kind = 'Changed'; subsystem = 'virtualization'; field = ('wsl.distributions.{0}.version' -f $after.name); changeType = 'State'; before = $before.version; after = $after.version }
        }
    }

    @($changes)
}

function Compare-PowerShellHealthState {
    param([Parameter(Mandatory)] [object] $Reference, [Parameter(Mandatory)] [object] $Current)

    $changes = @()
    $changes += Compare-HealthScalarField -Subsystem 'powerShell' -Field 'active.edition' -ChangeType 'State' -Before $Reference.activeEdition -After $Current.activeEdition -ReferenceAvailable $Reference.activeEvidenceAvailable -CurrentAvailable $Current.activeEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'powerShell' -Field 'active.version' -ChangeType 'Version' -Before $Reference.activeVersion -After $Current.activeVersion -ReferenceAvailable $Reference.activeEvidenceAvailable -CurrentAvailable $Current.activeEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'powerShell' -Field 'active.executable' -ChangeType 'Resolution' -Before $Reference.activeExecutable -After $Current.activeExecutable -ReferenceAvailable $Reference.activeEvidenceAvailable -CurrentAvailable $Current.activeEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'powerShell' -Field 'effectiveExecutionPolicy.policy' -ChangeType 'Configuration' -Before $Reference.effectivePolicyValue -After $Current.effectivePolicyValue -ReferenceAvailable $Reference.executionPolicyEvidenceAvailable -CurrentAvailable $Current.executionPolicyEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'powerShell' -Field 'effectiveExecutionPolicy.scope' -ChangeType 'Configuration' -Before $Reference.effectivePolicyScope -After $Current.effectivePolicyScope -ReferenceAvailable $Reference.executionPolicyEvidenceAvailable -CurrentAvailable $Current.executionPolicyEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'powerShell' -Field 'windowsPowerShell.present' -ChangeType 'Availability' -Before $Reference.windowsPowerShellPresent -After $Current.windowsPowerShellPresent -ReferenceAvailable $Reference.windowsPowerShellEvidenceAvailable -CurrentAvailable $Current.windowsPowerShellEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'powerShell' -Field 'windowsPowerShell.version' -ChangeType 'Version' -Before $Reference.windowsPowerShellVersion -After $Current.windowsPowerShellVersion -ReferenceAvailable $Reference.windowsPowerShellEvidenceAvailable -CurrentAvailable $Current.windowsPowerShellEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'powerShell' -Field 'powerShell7.selectedCommand.path' -ChangeType 'Resolution' -Before $Reference.pwshSelectedPath -After $Current.pwshSelectedPath -ReferenceAvailable $Reference.pwshSelectedPathEvidenceAvailable -CurrentAvailable $Current.pwshSelectedPathEvidenceAvailable
    @($changes)
}

function Compare-GitHealthState {
    param([Parameter(Mandatory)] [object] $Reference, [Parameter(Mandatory)] [object] $Current)

    $changes = @()
    $changes += Compare-HealthScalarField -Subsystem 'git' -Field 'git.installed' -ChangeType 'Availability' -Before $Reference.gitInstalled -After $Current.gitInstalled -ReferenceAvailable $Reference.gitEvidenceAvailable -CurrentAvailable $Current.gitEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'git' -Field 'git.version' -ChangeType 'Version' -Before $Reference.gitVersion -After $Current.gitVersion -ReferenceAvailable $Reference.gitEvidenceAvailable -CurrentAvailable $Current.gitEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'git' -Field 'git.identity.name.configured' -ChangeType 'Configuration' -Before $Reference.identityNameConfigured -After $Current.identityNameConfigured -ReferenceAvailable $Reference.identityEvidenceAvailable -CurrentAvailable $Current.identityEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'git' -Field 'git.identity.email.configured' -ChangeType 'Configuration' -Before $Reference.identityEmailConfigured -After $Current.identityEmailConfigured -ReferenceAvailable $Reference.identityEvidenceAvailable -CurrentAvailable $Current.identityEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'git' -Field 'git.defaultBranch.value' -ChangeType 'Configuration' -Before $Reference.defaultBranchValue -After $Current.defaultBranchValue -ReferenceAvailable $Reference.defaultBranchEvidenceAvailable -CurrentAvailable $Current.defaultBranchEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'git' -Field 'git.autocrlf.value' -ChangeType 'Configuration' -Before $Reference.autocrlfValue -After $Current.autocrlfValue -ReferenceAvailable $Reference.gitEvidenceAvailable -CurrentAvailable $Current.gitEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'git' -Field 'git.credentialHelper.configured' -ChangeType 'Configuration' -Before $Reference.credentialHelperConfigured -After $Current.credentialHelperConfigured -ReferenceAvailable $Reference.credentialHelperEvidenceAvailable -CurrentAvailable $Current.credentialHelperEvidenceAvailable
    $changes += Compare-HealthSet -Subsystem 'git' -FieldPrefix 'git.credentialHelper.types' -ChangeType 'Configuration' -ReferenceItems $Reference.credentialHelperTypes -CurrentItems $Current.credentialHelperTypes -ReferenceAvailable $Reference.credentialHelperEvidenceAvailable -CurrentAvailable $Current.credentialHelperEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'git' -Field 'githubCli.installed' -ChangeType 'Availability' -Before $Reference.githubInstalled -After $Current.githubInstalled -ReferenceAvailable $Reference.githubEvidenceAvailable -CurrentAvailable $Current.githubEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'git' -Field 'githubCli.version' -ChangeType 'Version' -Before $Reference.githubVersion -After $Current.githubVersion -ReferenceAvailable $Reference.githubEvidenceAvailable -CurrentAvailable $Current.githubEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'git' -Field 'githubCli.authentication.authenticated' -ChangeType 'State' -Before $Reference.githubAuthenticated -After $Current.githubAuthenticated -ReferenceAvailable $Reference.githubAuthEvidenceAvailable -CurrentAvailable $Current.githubAuthEvidenceAvailable
    $changes += Compare-HealthSet -Subsystem 'git' -FieldPrefix 'githubCli.authentication.hosts' -ChangeType 'State' -ReferenceItems $Reference.githubAuthHosts -CurrentItems $Current.githubAuthHosts -ReferenceAvailable $Reference.githubAuthEvidenceAvailable -CurrentAvailable $Current.githubAuthEvidenceAvailable
    @($changes)
}

function Compare-PythonHealthState {
    param([Parameter(Mandatory)] [object] $Reference, [Parameter(Mandatory)] [object] $Current)

    $changes = @()
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'selected.path' -ChangeType 'Resolution' -Before $Reference.selectedPath -After $Current.selectedPath -ReferenceAvailable $Reference.selectedEvidenceAvailable -CurrentAvailable $Current.selectedEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'selected.version' -ChangeType 'Version' -Before $Reference.selectedVersion -After $Current.selectedVersion -ReferenceAvailable $Reference.selectedEvidenceAvailable -CurrentAvailable $Current.selectedEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'selected.runnable' -ChangeType 'State' -Before $Reference.selectedRunnable -After $Current.selectedRunnable -ReferenceAvailable $Reference.selectedEvidenceAvailable -CurrentAvailable $Current.selectedEvidenceAvailable
    if ($Reference.runtimesEvidenceAvailable -and $Current.runtimesEvidenceAvailable) {
        $changes += Compare-PythonRuntimeSet -Reference $Reference.runtimes -Current $Current.runtimes -ReferenceAvailable $Reference.runtimesEvidenceAvailable -CurrentAvailable $Current.runtimesEvidenceAvailable
    }
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'pyLauncher.available' -ChangeType 'Availability' -Before $Reference.pyLauncherAvailable -After $Current.pyLauncherAvailable -ReferenceAvailable $Reference.pyLauncherEvidenceAvailable -CurrentAvailable $Current.pyLauncherEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'pyLauncher.reportedPythonVersion' -ChangeType 'Version' -Before $Reference.pyLauncherReportedVersion -After $Current.pyLauncherReportedVersion -ReferenceAvailable $Reference.pyLauncherEvidenceAvailable -CurrentAvailable $Current.pyLauncherEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'uv.available' -ChangeType 'Availability' -Before $Reference.uvAvailable -After $Current.uvAvailable -ReferenceAvailable $Reference.uvEvidenceAvailable -CurrentAvailable $Current.uvEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'uv.version' -ChangeType 'Version' -Before $Reference.uvVersion -After $Current.uvVersion -ReferenceAvailable $Reference.uvEvidenceAvailable -CurrentAvailable $Current.uvEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'virtualEnvironment.active' -ChangeType 'State' -Before $Reference.virtualEnvironmentActive -After $Current.virtualEnvironmentActive -ReferenceAvailable $Reference.virtualEnvironmentEvidenceAvailable -CurrentAvailable $Current.virtualEnvironmentEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'virtualEnvironment.path' -ChangeType 'Configuration' -Before $Reference.virtualEnvironmentPath -After $Current.virtualEnvironmentPath -ReferenceAvailable $Reference.virtualEnvironmentEvidenceAvailable -CurrentAvailable $Current.virtualEnvironmentEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'virtualEnvironment.interpreterExists' -ChangeType 'State' -Before $Reference.virtualEnvironmentInterpreterExists -After $Current.virtualEnvironmentInterpreterExists -ReferenceAvailable $Reference.virtualEnvironmentEvidenceAvailable -CurrentAvailable $Current.virtualEnvironmentEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'pip.available' -ChangeType 'Availability' -Before $Reference.pipAvailable -After $Current.pipAvailable -ReferenceAvailable $Reference.pipEvidenceAvailable -CurrentAvailable $Current.pipEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'python' -Field 'pip.version' -ChangeType 'Version' -Before $Reference.pipVersion -After $Current.pipVersion -ReferenceAvailable $Reference.pipEvidenceAvailable -CurrentAvailable $Current.pipEvidenceAvailable
    @($changes)
}

function Compare-NodeHealthState {
    param([Parameter(Mandatory)] [object] $Reference, [Parameter(Mandatory)] [object] $Current)

    $changes = @()
    $changes += Compare-HealthScalarField -Subsystem 'node' -Field 'node.selected.path' -ChangeType 'Resolution' -Before $Reference.nodeSelectedPath -After $Current.nodeSelectedPath -ReferenceAvailable $Reference.nodeSelectedEvidenceAvailable -CurrentAvailable $Current.nodeSelectedEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'node' -Field 'node.selected.version' -ChangeType 'Version' -Before $Reference.nodeVersion -After $Current.nodeVersion -ReferenceAvailable $Reference.nodeSelectedEvidenceAvailable -CurrentAvailable $Current.nodeSelectedEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'node' -Field 'node.runnable' -ChangeType 'State' -Before $Reference.nodeRunnable -After $Current.nodeRunnable -ReferenceAvailable $Reference.nodeSelectedEvidenceAvailable -CurrentAvailable $Current.nodeSelectedEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'node' -Field 'npm.selectedCommand.path' -ChangeType 'Resolution' -Before $Reference.npmSelectedPath -After $Current.npmSelectedPath -ReferenceAvailable $Reference.npmSelectedEvidenceAvailable -CurrentAvailable $Current.npmSelectedEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'node' -Field 'npm.probeCommand.path' -ChangeType 'Resolution' -Before $Reference.npmProbePath -After $Current.npmProbePath -ReferenceAvailable $Reference.npmProbeEvidenceAvailable -CurrentAvailable $Current.npmProbeEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'node' -Field 'npm.version' -ChangeType 'Version' -Before $Reference.npmVersion -After $Current.npmVersion -ReferenceAvailable $Reference.npmSelectedEvidenceAvailable -CurrentAvailable $Current.npmSelectedEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'node' -Field 'npm.prefix' -ChangeType 'Configuration' -Before $Reference.npmPrefix -After $Current.npmPrefix -ReferenceAvailable $Reference.npmPrefixEvidenceAvailable -CurrentAvailable $Current.npmPrefixEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'node' -Field 'npm.globalCommandPath' -ChangeType 'Configuration' -Before $Reference.npmGlobalCommandPath -After $Current.npmGlobalCommandPath -ReferenceAvailable $Reference.npmGlobalPathEvidenceAvailable -CurrentAvailable $Current.npmGlobalPathEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'node' -Field 'npm.globalPathExists' -ChangeType 'State' -Before $Reference.npmGlobalPathExists -After $Current.npmGlobalPathExists -ReferenceAvailable $Reference.npmGlobalPathEvidenceAvailable -CurrentAvailable $Current.npmGlobalPathEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'node' -Field 'npm.globalPathOnPath' -ChangeType 'State' -Before $Reference.npmGlobalPathOnPath -After $Current.npmGlobalPathOnPath -ReferenceAvailable $Reference.npmGlobalPathEvidenceAvailable -CurrentAvailable $Current.npmGlobalPathEvidenceAvailable
    @($changes)
}

function Compare-VirtualizationHealthState {
    param([Parameter(Mandatory)] [object] $Reference, [Parameter(Mandatory)] [object] $Current)

    $changes = @()
    $changes += Compare-HealthScalarField -Subsystem 'virtualization' -Field 'virtualizationCapability' -ChangeType 'State' -Before $Reference.virtualizationCapability -After $Current.virtualizationCapability -ReferenceAvailable $Reference.capabilityEvidenceAvailable -CurrentAvailable $Current.capabilityEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'virtualization' -Field 'hypervisorState' -ChangeType 'State' -Before $Reference.hypervisorState -After $Current.hypervisorState -ReferenceAvailable $Reference.hypervisorEvidenceAvailable -CurrentAvailable $Current.hypervisorEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'virtualization' -Field 'firmwareVirtualization' -ChangeType 'State' -Before $Reference.firmwareVirtualization -After $Current.firmwareVirtualization -ReferenceAvailable $Reference.firmwareEvidenceAvailable -CurrentAvailable $Current.firmwareEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'virtualization' -Field 'readiness.wsl2Ready' -ChangeType 'State' -Before $Reference.wsl2Ready -After $Current.wsl2Ready -ReferenceAvailable $Reference.readinessEvidenceAvailable -CurrentAvailable $Current.readinessEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'virtualization' -Field 'wsl.installed' -ChangeType 'Availability' -Before $Reference.wslInstalled -After $Current.wslInstalled -ReferenceAvailable $Reference.wslEvidenceAvailable -CurrentAvailable $Current.wslEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'virtualization' -Field 'wsl.version' -ChangeType 'Version' -Before $Reference.wslPackageVersion -After $Current.wslPackageVersion -ReferenceAvailable $Reference.wslEvidenceAvailable -CurrentAvailable $Current.wslEvidenceAvailable
    $changes += Compare-HealthScalarField -Subsystem 'virtualization' -Field 'wsl.defaultVersion' -ChangeType 'Configuration' -Before $Reference.wslDefaultVersion -After $Current.wslDefaultVersion -ReferenceAvailable $Reference.wslEvidenceAvailable -CurrentAvailable $Current.wslEvidenceAvailable
    if ($Reference.wslDistributionsEvidenceAvailable -and $Current.wslDistributionsEvidenceAvailable) {
        $changes += Compare-WslDistributionSet -Reference $Reference.distributions -Current $Current.distributions -ReferenceAvailable $Reference.wslDistributionsEvidenceAvailable -CurrentAvailable $Current.wslDistributionsEvidenceAvailable
    }
    @($changes)
}

function Compare-HealthState {
    param(
        [Parameter(Mandatory)] [object] $Reference,
        [Parameter(Mandatory)] [object] $Current
    )

    $changes = @()
    $changes += Compare-PowerShellHealthState -Reference $Reference.powerShell -Current $Current.powerShell
    $changes += Compare-GitHealthState -Reference $Reference.git -Current $Current.git
    $changes += Compare-PythonHealthState -Reference $Reference.python -Current $Current.python
    $changes += Compare-NodeHealthState -Reference $Reference.node -Current $Current.node
    $changes += Compare-VirtualizationHealthState -Reference $Reference.virtualization -Current $Current.virtualization
    @($changes)
}
