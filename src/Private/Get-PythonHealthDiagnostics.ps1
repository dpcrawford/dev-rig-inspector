function Get-PythonHealthDiagnostics {
    param([Parameter(Mandatory)] [object] $PythonHealth)

    $findings = @()
    $runtimes = @($PythonHealth.runtimes)
    $selected = $PythonHealth.selected
    $workingRuntimes = @($runtimes | Where-Object runnable)
    $installedLocations = @($workingRuntimes | ForEach-Object path | Select-Object -Unique)

    if ($selected -and -not $selected.runnable) {
        $findings += New-DiagnosticFinding `
            -Code 'PythonInterpreterUnavailable' `
            -Severity Error `
            -Category 'Python' `
            -Title 'Selected Python interpreter cannot run' `
            -Message 'The command selected by Python command resolution was not available or did not execute successfully.' `
            -AffectedComponent 'Python' `
            -Evidence @([pscustomobject]@{ selected = $selected; candidates = $runtimes }) `
            -Recommendation 'Review the selected Python command and install or repair the intended interpreter without changing it automatically.'
    }

    if ($workingRuntimes.Count -gt 1) {
        $findings += New-DiagnosticFinding `
            -Code 'PythonRuntimeCoexistence' `
            -Severity Info `
            -Category 'Python' `
            -Title 'Multiple functioning Python runtimes are installed' `
            -Message ('Multiple Python runtimes are available; resolution order selects {0}.' -f $selected.version) `
            -AffectedComponent 'Python' `
            -Evidence @([pscustomobject]@{
                selectedWinner = $selected
                runtimes = $runtimes
                precedence = @($runtimes | Select-Object path, version, order)
            }) `
            -Recommendation 'No action is required unless a different installed interpreter is intended to win resolution.'
    }

    $aliases = @($runtimes | Where-Object windowsAppsAlias)
    if ($aliases.Count -gt 0) {
        $selectedIsAlias = $null -ne $selected -and $selected.windowsAppsAlias
        $realRuntimeExists = @($workingRuntimes | Where-Object { -not $_.windowsAppsAlias }).Count -gt 0
        if ($selectedIsAlias -and $realRuntimeExists) {
            $findings += New-DiagnosticFinding `
                -Code 'PythonAliasWinsResolution' `
                -Severity Warning `
                -Category 'Python' `
                -Title 'WindowsApps Python alias wins command resolution' `
                -Message 'A WindowsApps Python alias resolves before a functioning installed interpreter and may redirect python commands unexpectedly.' `
                -AffectedComponent 'Python' `
                -Evidence @([pscustomobject]@{ selectedWinner = $selected; aliases = $aliases; runtimes = $runtimes }) `
                -Recommendation 'Confirm whether the WindowsApps alias is intended; otherwise review command resolution before changing any aliases or PATH entries.'
        } else {
            $findings += New-DiagnosticFinding `
                -Code 'PythonAliasDetected' `
                -Severity Info `
                -Category 'Python' `
                -Title 'WindowsApps Python alias is present' `
                -Message 'A WindowsApps Python alias participates in command discovery but does not currently win over the selected interpreter.' `
                -AffectedComponent 'Python' `
                -Evidence @([pscustomobject]@{ aliases = $aliases; selectedWinner = $selected }) `
                -Recommendation 'No action is required unless Python command resolution is surprising.'
        }
    }

    if ($PythonHealth.pyLauncher.available) {
        $findings += New-DiagnosticFinding `
            -Code 'PythonPyLauncherDetected' `
            -Severity Info `
            -Category 'Python' `
            -Title 'Python py launcher is available' `
            -Message ('The py launcher reports Python version {0}.' -f $PythonHealth.pyLauncher.reportedPythonVersion) `
            -AffectedComponent 'py' `
            -Evidence @($PythonHealth.pyLauncher) `
            -Recommendation 'No action is required.'
    }

    if ($PythonHealth.uv.available) {
        $findings += New-DiagnosticFinding `
            -Code 'PythonUvDetected' `
            -Severity Info `
            -Category 'Python' `
            -Title 'uv is available' `
            -Message ('uv is available at version {0}.' -f $PythonHealth.uv.version) `
            -AffectedComponent 'uv' `
            -Evidence @($PythonHealth.uv) `
            -Recommendation 'No action is required.'
    }

    if ($PythonHealth.virtualEnvironment.active) {
        if ($PythonHealth.virtualEnvironment.interpreterExists) {
            $findings += New-DiagnosticFinding `
                -Code 'PythonVirtualEnvironmentActive' `
                -Severity Info `
                -Category 'Python' `
                -Title 'A Python virtual environment is active' `
                -Message 'VIRTUAL_ENV points to an environment with an existing interpreter.' `
                -AffectedComponent 'Python.VirtualEnvironment' `
                -Evidence @($PythonHealth.virtualEnvironment) `
                -Recommendation 'No action is required.'
        } else {
            $findings += New-DiagnosticFinding `
                -Code 'PythonVirtualEnvironmentInterpreterMissing' `
                -Severity Warning `
                -Category 'Python' `
                -Title 'Active Python virtual environment interpreter is missing' `
                -Message 'VIRTUAL_ENV points to an environment whose expected Scripts\\python.exe does not exist.' `
                -AffectedComponent 'Python.VirtualEnvironment' `
                -Evidence @($PythonHealth.virtualEnvironment) `
                -Recommendation 'Deactivate or recreate the environment only after confirming the intended project interpreter; Dev Rig Inspector will not modify it.'
        }
    }

    if (-not $PythonHealth.pip.available) {
        $findings += New-DiagnosticFinding `
            -Code 'PythonPipUnavailable' `
            -Severity Info `
            -Category 'Python' `
            -Title 'pip is not available through the selected interpreter' `
            -Message 'The selected interpreter could not provide pip through python -m pip.' `
            -AffectedComponent 'Python.pip' `
            -Evidence @([pscustomobject]@{ pip = $PythonHealth.pip; uvAvailable = $PythonHealth.uv.available }) `
            -Recommendation 'No action is required if uv or another approved package workflow is intentional.'
    }

    @($findings)
}
