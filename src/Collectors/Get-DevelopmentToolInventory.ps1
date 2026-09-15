function Get-DevelopmentToolInventory {
    $results = foreach ($definition in $ToolDefinitions.Tools) {
        $resolution = Resolve-ToolCommand -CommandName $definition.Command
        $diagnostics = @()
        if ($resolution.candidates.Count -gt 1) {
            $diagnostics += [pscustomobject]@{
                code = 'PathShadowing'
                severity = 'Warning'
                message = 'Multiple matching commands were found; the first PATH candidate was selected.'
                candidateCount = $resolution.candidates.Count
            }
        }

        if (-not $resolution.selected) {
            [pscustomobject]@{
                id = $definition.Id
                displayName = $definition.DisplayName
                status = 'Missing'
                selectedCommand = $null
                allCommandCandidates = @()
                version = $null
                rawVersion = $null
                command = $null
                diagnostics = $diagnostics
                error = $null
            }
            continue
        }

        try {
            $execution = Invoke-ExternalCommand -FilePath $resolution.selected.path -Arguments $definition.VersionArguments
            $rawVersion = ($execution.standardOutput + "`n" + $execution.standardError).Trim()
            $version = if ($rawVersion -match '(?<!\d)(\d+\.\d+(?:\.\d+){0,2})') { $Matches[1] } else { $rawVersion }
            $status = if ($execution.timedOut) { 'TimedOut' } elseif ($execution.exitCode -eq 0) { 'Available' } else { 'Error' }

            [pscustomobject]@{
                id = $definition.Id
                displayName = $definition.DisplayName
                status = $status
                selectedCommand = $resolution.selected
                allCommandCandidates = $resolution.candidates
                version = $version
                rawVersion = $rawVersion
                command = $execution
                diagnostics = $diagnostics
                error = if ($status -eq 'Error') { $execution.standardError.Trim() } else { $null }
            }
        } catch {
            [pscustomobject]@{
                id = $definition.Id
                displayName = $definition.DisplayName
                status = 'Error'
                selectedCommand = $resolution.selected
                allCommandCandidates = $resolution.candidates
                version = $null
                rawVersion = $null
                command = $null
                diagnostics = $diagnostics
                error = $_.Exception.Message
            }
        }
    }

    New-CollectorResult -CollectorId 'DevelopmentTools' -Status Available -Data @($results)
}