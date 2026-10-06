param([string[]] $Path = @((Join-Path $PSScriptRoot '..\tests')))

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host ''
    Write-Host 'Dev Rig Inspector tests require PowerShell 7+.'
    Write-Host ("Detected PowerShell version: {0}" -f $PSVersionTable.PSVersion)
    Write-Host 'Start PowerShell 7 with: pwsh'
    Write-Host ''
    exit 1
}

$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 3.4.0 -Force -ErrorAction Stop
Write-Host "PowerShell $($PSVersionTable.PSVersion); Pester $((Get-Module Pester).Version)"
# Some integration tests render real inventories. Keep those off public CI logs,
# including Pester failure details which can contain actual serialized values.
$result = Invoke-Pester -Path $Path -PassThru 6>$null
Write-Host "Tests: $($result.TotalCount); Passed: $($result.PassedCount); Failed: $($result.FailedCount); Skipped: $($result.SkippedCount)"
foreach ($failure in @($result.TestResult | Where-Object { -not $_.Passed })) {
    Write-Host "Non-passing test: $($failure.Describe) / $($failure.Name)"
    $line = $failure.ErrorRecord.InvocationInfo.ScriptLineNumber
    $exceptionType = if ($failure.ErrorRecord.Exception) { $failure.ErrorRecord.Exception.GetType().Name } else { 'Unavailable' }
    if ($line) { Write-Host "  Failure location: line $line; exception type: $exceptionType" }
}
if ($result.TotalCount -eq 0 -or $result.FailedCount -gt 0) {
    throw 'Test gate failed. Reproduce the named tests locally to inspect detailed output.'
}
