function Get-InventoryDiagnostics {
    param(
        [Parameter(Mandatory)] [object[]] $Tools,
        [string] $PathValue = $env:PATH
    )

    $findings = @(Get-PathDiagnostics -PathValue $PathValue)

    foreach ($tool in $Tools) {
        $candidates = @($tool.allCommandCandidates)
        if ($candidates.Count -lt 2) {
            continue
        }

        $candidateEvidence = @(
            for ($index = 0; $index -lt $candidates.Count; $index++) {
                $candidate = $candidates[$index]
                $directory = Split-Path -Parent $candidate.path
                [pscustomobject]@{
                    name = if ($candidate.name) { $candidate.name } else { Split-Path -Leaf $candidate.path }
                    commandType = if ($candidate.commandType) { $candidate.commandType } else { 'Application' }
                    path = $candidate.path
                    source = if ($candidate.source) { $candidate.source } else { 'Path' }
                    normalizedParentDirectory = (ConvertTo-NormalizedPathEntry -RawEntry $directory).normalized
                    directory = $directory
                    normalizedDirectory = (ConvertTo-NormalizedPathEntry -RawEntry $directory).normalized
                    order = $index + 1
                }
            }
        )
        $locations = @($candidateEvidence | Group-Object -Property normalizedDirectory)
        if ($locations.Count -lt 2) {
            continue
        }

        $selectedPath = $tool.selectedCommand.path
        $selected = $candidateEvidence | Where-Object { $_.path -ieq $selectedPath } | Select-Object -First 1
        $competing = @($candidateEvidence | Where-Object { $_.normalizedDirectory -ine $selected.normalizedDirectory })
        $selectedIsWindowsAppsAlias = $selected.normalizedParentDirectory -match '\\Microsoft\\WindowsApps$'
        $severity = if ($selectedIsWindowsAppsAlias -and $competing.Count -gt 0) { 'Warning' } else { 'Info' }
        $title = if ($severity -eq 'Warning') {
            'WindowsApps command alias takes precedence'
        } else {
            'Multiple command locations found'
        }
        $message = if ($severity -eq 'Warning') {
            '{0} resolves to a WindowsApps alias before another command location.' -f $tool.displayName
        } else {
            '{0} resolves to the first of multiple command locations; coexistence may be intentional.' -f $tool.displayName
        }
        $recommendation = if ($severity -eq 'Warning') {
            'Confirm that the WindowsApps alias is intended to win resolution; otherwise review PATH order.'
        } else {
            'No action is required unless the selected command is not the intended installation.'
        }

        $findings += New-DiagnosticFinding `
            -Code 'CommandShadowing' `
            -Severity $severity `
            -Category 'CommandResolution' `
            -Title $title `
            -Message $message `
            -AffectedComponent $tool.id `
            -Evidence @([pscustomobject]@{
                command = ($ToolDefinitions.Tools | Where-Object { $_.Id -eq $tool.id } | Select-Object -First 1).Command
                selectedWinner = $selected
                competingCandidates = $competing
                candidates = $candidateEvidence
                locations = @($locations | ForEach-Object { $_.Name })
            }) `
            -Recommendation $recommendation
    }

    @($findings)
}