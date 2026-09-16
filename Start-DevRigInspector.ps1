function Get-DevRigInspectorVersionGuardResult {
    # Pure decision helper so both the message text and the import/no-import outcome are unit-testable.
    param(
        [Parameter(Mandatory)] $DetectedVersion,
        [bool] $PwshAvailable
    )

    if ($DetectedVersion.Major -ge 7) {
        return [pscustomobject]@{ ShouldImport = $true; Message = $null }
    }

    $lines = @(
        'Dev Rig Inspector requires PowerShell 7 or later.'
        ''
        ('Detected PowerShell version: {0}' -f $DetectedVersion)
        ''
    )

    if ($PwshAvailable) {
        $lines += @(
            'PowerShell 7 (pwsh) is already installed on this computer.'
            'It looks like you launched Windows PowerShell instead of PowerShell 7.'
            ''
            'Start PowerShell 7 with:'
            '  pwsh'
        )
    } else {
        $lines += @(
            'PowerShell 7 was not found on this computer.'
            ''
            'Install it with:'
            '  winget install --id Microsoft.PowerShell --source winget'
            ''
            'Official installation guidance:'
            '  https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows'
        )
    }

    $lines += @(
        ''
        'Dev Rig Inspector does not install or modify PowerShell automatically.'
    )

    [pscustomobject]@{ ShouldImport = $false; Message = ($lines -join [Environment]::NewLine) }
}

# Guard the real entry-point behavior so this file can be dot-sourced (InvocationName '.') by tests
# to reuse Get-DevRigInspectorVersionGuardResult without importing the module or running an inspection.
if ($MyInvocation.InvocationName -ne '.') {
    $pwshAvailable = [bool] (Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue)
    $guardResult = Get-DevRigInspectorVersionGuardResult -DetectedVersion $PSVersionTable.PSVersion -PwshAvailable $pwshAvailable

    if (-not $guardResult.ShouldImport) {
        Write-Host ''
        Write-Host $guardResult.Message
        Write-Host ''
        exit 1
    }

    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'src\DevRigInspector.psd1'
    Import-Module $modulePath -Force
    Invoke-DevRigInspection
}
