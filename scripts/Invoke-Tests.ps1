if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host ''
    Write-Host 'Dev Rig Inspector tests require PowerShell 7+.'
    Write-Host ("Detected PowerShell version: {0}" -f $PSVersionTable.PSVersion)
    Write-Host 'Start PowerShell 7 with: pwsh'
    Write-Host ''
    exit 1
}

$ErrorActionPreference = 'Stop'
Import-Module Pester -ErrorAction Stop
Invoke-Pester -Path (Join-Path $PSScriptRoot '..\tests')