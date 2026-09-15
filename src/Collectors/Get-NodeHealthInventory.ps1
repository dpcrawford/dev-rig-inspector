function Get-NodeVersionEvidence {
    param([Parameter(Mandatory)] [object] $Candidate)

    $execution = $null
    try {
        $execution = Invoke-ExternalCommand -FilePath $Candidate.path -Arguments @('--version')
    } catch {
        $execution = [pscustomobject]@{ exitCode = $null; standardOutput = ''; standardError = $_.Exception.Message }
    }
    $text = ($execution.standardOutput + "`n" + $execution.standardError).Trim()
    [pscustomobject]@{
        name = $Candidate.name
        commandType = $Candidate.commandType
        path = $Candidate.path
        source = $Candidate.source
        normalizedParentDirectory = $Candidate.normalizedParentDirectory
        order = $Candidate.order
        version = if ($execution.exitCode -eq 0) { if ($text -match '(?<!\d)(\d+\.\d+(?:\.\d+){0,2})') { $Matches[1] } else { $text } } else { $null }
        runnable = $execution.exitCode -eq 0
    }
}

function Get-NpmRawLauncherEvidence {
    $commands = @(Get-Command -Name 'npm' -All -ErrorAction SilentlyContinue | Where-Object Path)
    $seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @(
        for ($index = 0; $index -lt $commands.Count; $index++) {
            $command = $commands[$index]
            if ($seenPaths.Add($command.Path)) {
                [pscustomobject]@{
                    name = $command.Name
                    commandType = [string] $command.CommandType
                    path = $command.Path
                    source = $command.Source
                    normalizedParentDirectory = (ConvertTo-NormalizedPathEntry -RawEntry (Split-Path -Parent $command.Path)).normalized
                    order = $index + 1
                }
            }
        }
    )
}

function Get-NodeHealthInventory {
    $nodeResolution = Resolve-ToolCommand -CommandName 'node'
    $npmResolution = Resolve-ToolCommand -CommandName 'npm'
    $nodeCandidates = @($nodeResolution.candidates | ForEach-Object { Get-NodeVersionEvidence -Candidate $_ })
    $nodeSelected = if ($nodeResolution.selected) { $nodeCandidates | Where-Object { $_.path -ieq $nodeResolution.selected.path } | Select-Object -First 1 } else { $null }

    $npmCandidates = @($npmResolution.candidates | ForEach-Object { Get-NodeVersionEvidence -Candidate $_ })
    $probeNpm = @($npmCandidates | Where-Object runnable)
    $npmSelected = if ($npmResolution.selected) { $npmCandidates | Where-Object { $_.path -ieq $npmResolution.selected.path } | Select-Object -First 1 } else { $null }
    $npmLaunchers = @(Get-NpmRawLauncherEvidence)
    $selectedNpmLauncher = if ($npmLaunchers.Count -gt 0) { $npmLaunchers[0] } else { $npmSelected }
    $npmVersion = if ($npmSelected -and $npmSelected.runnable) { $npmSelected.version } elseif ($probeNpm.Count -gt 0) { $probeNpm[0].version } else { $null }

    $npmPrefix = $null
    if ($probeNpm.Count -gt 0) {
        $prefixExecution = Invoke-ExternalCommand -FilePath $probeNpm[0].path -Arguments @('prefix', '-g')
        if ($prefixExecution.exitCode -eq 0) { $npmPrefix = $prefixExecution.standardOutput.Trim() }
    }

    $globalCommandPath = $null
    if ($npmPrefix) {
        $globalCommandPath = if ($IsWindows) { $npmPrefix } else { Join-Path $npmPrefix 'bin' }
    }
    $globalPathEntry = if ($globalCommandPath) { ConvertTo-NormalizedPathEntry -RawEntry $globalCommandPath } else { $null }
    $pathEntries = @(
        ($env:PATH -split [IO.Path]::PathSeparator) |
            Where-Object { $_.Trim().Length -gt 0 } |
            ForEach-Object { ConvertTo-NormalizedPathEntry -RawEntry $_ }
    )

    $npm = [pscustomobject]@{
        selectedCommand = $selectedNpmLauncher
        probeCommand = if ($probeNpm.Count -gt 0) { $probeNpm[0] } else { $null }
        commandCandidates = @($npmCandidates)
        launcherVariants = $npmLaunchers
        version = $npmVersion
        runnable = $probeNpm.Count -gt 0
        prefix = $npmPrefix
        globalCommandPath = $globalCommandPath
        globalPathExists = if ($globalCommandPath) { [IO.Directory]::Exists($globalCommandPath) } else { $null }
        globalPath = $globalPathEntry
        globalPathOnPath = $null -ne $globalPathEntry -and @($pathEntries | Where-Object { $_.normalized -ieq $globalPathEntry.normalized }).Count -gt 0
    }

    New-CollectorResult -CollectorId 'NodeHealth' -Status Available -Data ([pscustomobject]@{
        node = [pscustomobject]@{
            selected = $nodeSelected
            commandCandidates = @($nodeCandidates)
            runnable = $null -ne $nodeSelected -and $nodeSelected.runnable
        }
        npm = $npm
    })
}