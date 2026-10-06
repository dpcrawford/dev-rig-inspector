function Get-NodeHealthDiagnostics {
    param([Parameter(Mandatory)] [object] $NodeHealth)

    $findings = @()
    $node = $NodeHealth.node
    $npm = $NodeHealth.npm

    if ($node.selected -and -not $node.runnable) {
        $findings += New-DiagnosticFinding `
            -Code 'NodeRuntimeUnavailable' `
            -Severity Error `
            -Category 'Node' `
            -Title 'Selected Node runtime cannot run' `
            -Message 'The selected node executable was not available or did not execute successfully.' `
            -AffectedComponent 'Node' `
            -Evidence @([pscustomobject]@{ selected = $node.selected; candidates = @($node.commandCandidates) }) `
            -Recommendation 'Review the selected Node installation without changing it automatically.'
    } elseif ($node.selected -and $node.runnable) {
        $findings += New-DiagnosticFinding `
            -Code 'NodeRuntimeDetected' `
            -Severity Info `
            -Category 'Node' `
            -Title 'Node runtime is available' `
            -Message ('Node {0} runs successfully.' -f $node.selected.version) `
            -AffectedComponent 'Node' `
            -Evidence @($node.selected) `
            -Recommendation 'No action is required.'
    }

    if ($npm.runnable) {
        $findings += New-DiagnosticFinding `
            -Code 'NpmDetected' `
            -Severity Info `
            -Category 'Node' `
            -Title 'npm is available' `
            -Message ('npm {0} runs successfully.' -f $npm.version) `
            -AffectedComponent 'npm' `
            -Evidence @([pscustomobject]@{ selected = $npm.selectedCommand; probeCommand = $npm.probeCommand }) `
            -Recommendation 'No action is required.'
    }

    if ($node.runnable -and $npm.runnable) {
        $findings += New-DiagnosticFinding `
            -Code 'NodeNpmPairing' `
            -Severity Info `
            -Category 'Node' `
            -Title 'Node and npm both run' `
            -Message 'The selected Node and npm commands execute successfully; no compatibility conclusion is inferred from version numbers alone.' `
            -AffectedComponent 'Node/npm' `
            -Evidence @([pscustomobject]@{ node = $node.selected; npm = $npm.probeCommand; npmVersion = $npm.version }) `
            -Recommendation 'No action is required.'
    }

    $launcherLocations = @($npm.launcherVariants | ForEach-Object normalizedParentDirectory | Select-Object -Unique)
    if (@($npm.launcherVariants).Count -gt 1) {
        $findings += New-DiagnosticFinding `
            -Code 'NpmLauncherVariants' `
            -Severity Info `
            -Category 'Node' `
            -Title 'Multiple npm launcher variants were found' `
            -Message 'npm launcher variants coexist; same-install variants are not treated as command shadowing.' `
            -AffectedComponent 'npm' `
            -Evidence @([pscustomobject]@{ variants = @($npm.launcherVariants); locations = $launcherLocations }) `
            -Recommendation 'No action is required when the intended npm launcher executes successfully.'
    }

    if ($npm.selectedCommand -and $npm.probeCommand -and $npm.selectedCommand.path -ine $npm.probeCommand.path) {
        $selectedLauncher = $npm.launcherVariants | Where-Object { $_.path -ieq $npm.selectedCommand.path } | Select-Object -First 1
        $sameInstallation = $selectedLauncher.normalizedParentDirectory -ieq $npm.probeCommand.normalizedParentDirectory
        $message = if ($sameInstallation) {
            'PowerShell resolves npm to {0}. Dev Rig Inspector used {1} for noninteractive external-process probes. Both launchers belong to the same Node.js installation.' -f $npm.selectedCommand.name, $npm.probeCommand.name
        } else {
            'PowerShell resolves npm to {0}. Dev Rig Inspector used {1} for noninteractive external-process probes; the launcher locations differ.' -f $npm.selectedCommand.name, $npm.probeCommand.name
        }
        $findings += New-DiagnosticFinding `
            -Code 'NpmLauncherResolution' `
            -Severity Info `
            -Category 'Node' `
            -Title 'npm shell launcher and probe launcher differ' `
            -Message $message `
            -AffectedComponent 'npm' `
            -Evidence @([pscustomobject]@{ selectedCommand = $npm.selectedCommand; probeCommand = $npm.probeCommand; sameInstallation = $sameInstallation; variants = @($npm.launcherVariants) }) `
            -Recommendation 'No action is required; the probe launcher is an implementation detail unless npm behavior is surprising in the current shell.'
    }

    if ($npm.prefix) {
        $globalStatus = if ($npm.globalPathExists) { 'exists' } else { 'missing' }
        $findings += New-DiagnosticFinding `
            -Code 'NpmGlobalPrefixDetected' `
            -Severity Info `
            -Category 'Node' `
            -Title 'npm global command location was detected' `
            -Message ('npm reports global command location {0}, which {1}.' -f $npm.globalCommandPath, $globalStatus) `
            -AffectedComponent 'npm.globalPath' `
            -Evidence @([pscustomobject]@{ prefix = $npm.prefix; globalCommandPath = $npm.globalCommandPath; exists = $npm.globalPathExists; onPath = $npm.globalPathOnPath }) `
            -Recommendation 'No action is required unless global npm commands are expected and cannot be resolved.'
    }

    if ($npm.prefix -and -not $npm.globalPathExists) {
        $findings += New-DiagnosticFinding `
            -Code 'NpmGlobalPathMissing' `
            -Severity Info `
            -Category 'Node' `
            -Title 'npm global command location is missing' `
            -Message 'The npm global command location does not currently exist; this may be benign until global packages are installed.' `
            -AffectedComponent 'npm.globalPath' `
            -Evidence @([pscustomobject]@{ prefix = $npm.prefix; globalCommandPath = $npm.globalCommandPath; exists = $npm.globalPathExists }) `
            -Recommendation 'No action is required unless global npm commands are expected at this location.'
    } elseif ($npm.prefix -and $npm.globalPathExists -and -not $npm.globalPathOnPath) {
        $findings += New-DiagnosticFinding `
            -Code 'NpmGlobalPathNotOnPath' `
            -Severity Warning `
            -Category 'Node' `
            -Title 'npm global command location is not on PATH' `
            -Message 'The existing npm global command location is not represented in the effective PATH, so globally installed commands may not resolve.' `
            -AffectedComponent 'npm.globalPath' `
            -Evidence @([pscustomobject]@{ globalCommandPath = $npm.globalCommandPath; exists = $npm.globalPathExists; onPath = $npm.globalPathOnPath }) `
            -Recommendation 'Review the effective PATH and npm global command location before changing either configuration.'
    }

    @($findings)
}
