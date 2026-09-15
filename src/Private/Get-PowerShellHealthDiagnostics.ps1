function Get-PowerShellHealthDiagnostics {
    param([Parameter(Mandatory)] [object] $PowerShellHealth)

    $findings = @()
    $windowsPowerShellPresent = $PowerShellHealth.windowsPowerShell.present
    $powerShell7Present = @($PowerShellHealth.powerShell7.commandCandidates).Count -gt 0

    if ($windowsPowerShellPresent -and $powerShell7Present) {
        $findings += New-DiagnosticFinding `
            -Code 'PowerShellEditionCoexistence' `
            -Severity Info `
            -Category 'PowerShell' `
            -Title 'Windows PowerShell and PowerShell 7 coexist' `
            -Message 'Windows PowerShell 5.1 and PowerShell 7 are both available, which is normal on Windows development systems.' `
            -AffectedComponent 'PowerShell' `
            -Evidence @([pscustomobject]@{
                windowsPowerShellVersion = $PowerShellHealth.windowsPowerShell.version
                powerShell7Candidates = @($PowerShellHealth.powerShell7.commandCandidates)
            }) `
            -Recommendation 'Use PowerShell 7 for new development while retaining Windows PowerShell for compatibility when required.'
    }

    $effectivePolicy = $PowerShellHealth.effectiveExecutionPolicy
    if ($effectivePolicy -and $effectivePolicy.policy -in @('Restricted', 'AllSigned')) {
        $findings += New-DiagnosticFinding `
            -Code 'ExecutionPolicyRestrictsWorkflow' `
            -Severity Warning `
            -Category 'PowerShell' `
            -Title 'Effective PowerShell execution policy may restrict development' `
            -Message ('The effective execution policy is {0} at {1}, which can prevent expected local script or test execution.' -f $effectivePolicy.policy, $effectivePolicy.scope) `
            -AffectedComponent 'PowerShell.ExecutionPolicy' `
            -Evidence @([pscustomobject]@{
                effective = $effectivePolicy
                scopes = @($PowerShellHealth.executionPolicies)
            }) `
            -Recommendation 'Review the effective policy at the reported scope and choose an organization-approved policy that permits required local development workflows.'
    }

    $moduleEntries = @($PowerShellHealth.psModulePath)
    foreach ($entry in $moduleEntries | Where-Object { -not $_.exists }) {
        $findings += New-DiagnosticFinding `
            -Code 'PSModulePathEntryMissing' `
            -Severity Info `
            -Category 'PowerShell' `
            -Title 'PowerShell module-search location is not present' `
            -Message ('The configured PSModulePath search location does not currently exist: {0}. This may be benign until modules are installed there.' -f $entry.raw.Trim()) `
            -AffectedComponent 'PSModulePath' `
            -Evidence @($entry) `
            -Recommendation 'No action is required unless modules are expected at this location or module resolution is failing.'
    }

    foreach ($group in $moduleEntries | Group-Object normalized | Where-Object Count -gt 1) {
        $findings += New-DiagnosticFinding `
            -Code 'PSModulePathEntryDuplicate' `
            -Severity Info `
            -Category 'PowerShell' `
            -Title 'PowerShell module path contains duplicate entries' `
            -Message ('The PSModulePath contains the same normalized directory more than once: {0}' -f $group.Name) `
            -AffectedComponent 'PSModulePath' `
            -Evidence @($group.Group) `
            -Recommendation 'Consider removing duplicate entries if they are not intentional.'
    }

    $candidateLocations = @($PowerShellHealth.powerShell7.commandCandidates | ForEach-Object { $_.normalizedParentDirectory } | Select-Object -Unique)
    if ($candidateLocations.Count -gt 1) {
        $selected = $PowerShellHealth.powerShell7.commandCandidates |
            Where-Object { $_.path -ieq $PowerShellHealth.powerShell7.selectedCommand.path } |
            Select-Object -First 1
        if (-not $selected) {
            $selected = $PowerShellHealth.powerShell7.selectedCommand
        }
        $selectedIsAlias = $selected.normalizedParentDirectory -match '\\Microsoft\\WindowsApps$'
        $severity = if ($selectedIsAlias) { 'Warning' } else { 'Info' }
        $message = if ($severity -eq 'Warning') {
            'A WindowsApps PowerShell alias is first in command resolution ahead of another PowerShell location.'
        } else {
            'Multiple PowerShell 7 command locations resolve in a defined order; coexistence may be intentional.'
        }
        $recommendation = if ($severity -eq 'Warning') {
            'Confirm that the WindowsApps alias is intended to win resolution; otherwise review PATH order.'
        } else {
            'No action is required unless the selected PowerShell installation is not the intended one.'
        }
        $findings += New-DiagnosticFinding `
            -Code 'PowerShellLauncherResolution' `
            -Severity $severity `
            -Category 'PowerShell' `
            -Title 'Multiple PowerShell 7 command locations found' `
            -Message $message `
            -AffectedComponent 'pwsh' `
            -Evidence @([pscustomobject]@{
                selectedWinner = $selected
                candidates = @($PowerShellHealth.powerShell7.commandCandidates)
                locations = $candidateLocations
            }) `
            -Recommendation $recommendation
    }

    if (@($PowerShellHealth.pester).Count -gt 1) {
        $findings += New-DiagnosticFinding `
            -Code 'PesterVersionCompatibility' `
            -Severity Info `
            -Category 'PowerShell' `
            -Title 'Multiple Pester versions are installed' `
            -Message 'Multiple installed Pester versions were detected; PowerShell module resolution determines which one is imported.' `
            -AffectedComponent 'Pester' `
            -Evidence @($PowerShellHealth.pester) `
            -Recommendation 'Review the selected Pester version only if test behavior differs between environments.'
    }

    @($findings)
}