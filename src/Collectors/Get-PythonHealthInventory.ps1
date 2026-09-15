function Get-PythonVersionText {
    param([Parameter(Mandatory)] [object] $Execution)

    $text = ($Execution.standardOutput + "`n" + $Execution.standardError).Trim()
    if ($text -match '(?<!\d)(\d+\.\d+(?:\.\d+){0,2})') { $Matches[1] } else { $text }
}

function Invoke-PythonHealthProbe {
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [Parameter(Mandatory)] [string[]] $Arguments
    )

    try {
        Invoke-ExternalCommand -FilePath $FilePath -Arguments $Arguments
    } catch {
        [pscustomobject]@{
            arguments = @($Arguments)
            exitCode = $null
            standardOutput = ''
            standardError = ''
            timedOut = $false
            probeFailed = $true
            probeError = $_.Exception.Message
        }
    }
}

function Get-PythonCandidateEvidence {
    param([Parameter(Mandatory)] [object] $Candidate)

    $execution = Invoke-PythonHealthProbe -FilePath $Candidate.path -Arguments @('--version')
    [pscustomobject]@{
        name = $Candidate.name
        commandType = $Candidate.commandType
        path = $Candidate.path
        source = $Candidate.source
        normalizedParentDirectory = $Candidate.normalizedParentDirectory
        order = $Candidate.order
        version = if ($execution.exitCode -eq 0) { Get-PythonVersionText -Execution $execution } else { $null }
        runnable = $execution.exitCode -eq 0
        probeFailed = $execution.probeFailed
        probeError = $execution.probeError
        windowsAppsAlias = $Candidate.normalizedParentDirectory -match '\\Microsoft\\WindowsApps$'
    }
}

function Get-PythonHealthInventory {
    $pythonResolution = Resolve-ToolCommand -CommandName 'python'
    $pyResolution = Resolve-ToolCommand -CommandName 'py'
    $uvResolution = Resolve-ToolCommand -CommandName 'uv'
    $seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $pythonCandidates = @(
        foreach ($candidate in $pythonResolution.candidates) {
            if ($seenPaths.Add($candidate.path)) {
                Get-PythonCandidateEvidence -Candidate $candidate
            }
        }
    )
    $selected = if ($pythonResolution.selected) {
        $pythonCandidates | Where-Object { $_.path -ieq $pythonResolution.selected.path } | Select-Object -First 1
    } else { $null }

    $pip = [pscustomobject]@{
        available = $false
        version = $null
        probeFailed = $false
        probeError = $null
    }
    if ($pythonResolution.selected) {
        $pipExecution = Invoke-PythonHealthProbe -FilePath $pythonResolution.selected.path -Arguments @('-m', 'pip', '--version')
        if ($pipExecution.exitCode -eq 0) {
            $pip.available = $true
            $pip.version = Get-PythonVersionText -Execution $pipExecution
        }
        $pip.probeFailed = $pipExecution.probeFailed
        $pip.probeError = $pipExecution.probeError
    }

    $pyLauncher = [pscustomobject]@{
        available = $false
        reportedPythonVersion = $null
        selectedCommand = $pyResolution.selected
        probeFailed = $false
        probeError = $null
    }
    if ($pyResolution.selected) {
        $pyExecution = Invoke-PythonHealthProbe -FilePath $pyResolution.selected.path -Arguments @('--version')
        $pyLauncher.available = $pyExecution.exitCode -eq 0
        $pyLauncher.probeFailed = $pyExecution.probeFailed
        $pyLauncher.probeError = $pyExecution.probeError
        if ($pyLauncher.available) { $pyLauncher.reportedPythonVersion = Get-PythonVersionText -Execution $pyExecution }
    }

    $uv = [pscustomobject]@{
        available = $false
        version = $null
        selectedCommand = $uvResolution.selected
        probeFailed = $false
        probeError = $null
    }
    if ($uvResolution.selected) {
        $uvExecution = Invoke-PythonHealthProbe -FilePath $uvResolution.selected.path -Arguments @('--version')
        $uv.available = $uvExecution.exitCode -eq 0
        $uv.probeFailed = $uvExecution.probeFailed
        $uv.probeError = $uvExecution.probeError
        if ($uv.available) { $uv.version = Get-PythonVersionText -Execution $uvExecution }
    }

    $virtualEnvironment = [pscustomobject]@{
        active = -not [string]::IsNullOrWhiteSpace($env:VIRTUAL_ENV)
        path = if ([string]::IsNullOrWhiteSpace($env:VIRTUAL_ENV)) { $null } else { $env:VIRTUAL_ENV }
        expectedInterpreterPath = $null
        interpreterExists = $null
    }
    if ($virtualEnvironment.active) {
        $virtualEnvironment.expectedInterpreterPath = Join-Path -Path $virtualEnvironment.path -ChildPath 'Scripts\python.exe'
        $virtualEnvironment.interpreterExists = [IO.File]::Exists($virtualEnvironment.expectedInterpreterPath)
    }

    New-CollectorResult -CollectorId 'PythonHealth' -Status Available -Data ([pscustomobject]@{
        selected = $selected
        runtimes = @($pythonCandidates)
        commandCandidates = @($pythonResolution.candidates)
        pyLauncher = $pyLauncher
        uv = $uv
        virtualEnvironment = $virtualEnvironment
        pip = $pip
    })
}