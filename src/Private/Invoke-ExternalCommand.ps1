function Invoke-ExternalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [string[]] $Arguments = @(),
        [int] $TimeoutMilliseconds = 10000
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void] $startInfo.ArgumentList.Add([string] $argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw "Process did not start: $FilePath"
        }

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $completed = $process.WaitForExit($TimeoutMilliseconds)
        $timedOut = -not $completed

        if ($timedOut) {
            try {
                $process.Kill($true)
            } catch {
                Write-Verbose "Unable to terminate process ${FilePath}: $($_.Exception.Message)"
            }
            [void] $process.WaitForExit(2000)
        }

        [pscustomobject]@{
            arguments = @($Arguments)
            exitCode = if ($timedOut) { $null } else { $process.ExitCode }
            standardOutput = $stdoutTask.GetAwaiter().GetResult()
            standardError = $stderrTask.GetAwaiter().GetResult()
            timedOut = $timedOut
            durationMilliseconds = [int] $stopwatch.ElapsedMilliseconds
        }
    } finally {
        $process.Dispose()
        $stopwatch.Stop()
    }
}