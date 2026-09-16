$repoRoot = Split-Path -Parent $PSScriptRoot
$launcherPath = Join-Path $repoRoot 'Start-DevRigInspector.ps1'
$cmdPath = Join-Path $repoRoot 'Start-DevRigInspector.cmd'

Describe 'Start-DevRigInspector.ps1 version guard' {
    BeforeAll {
        # Dot-sourcing (InvocationName '.') must expose the helper function without running the real entry point.
        . $launcherPath
    }

    It 'requests import for PowerShell 7 or later' {
        $result = Get-DevRigInspectorVersionGuardResult -DetectedVersion ([version] '7.4.0') -PwshAvailable $true
        $result.ShouldImport | Should Be $true
        $result.Message | Should Be $null
    }

    It 'requests import for a PowerShell 7 prerelease-style version above 7' {
        $result = Get-DevRigInspectorVersionGuardResult -DetectedVersion ([version] '10.0.0') -PwshAvailable $true
        $result.ShouldImport | Should Be $true
    }

    It 'produces a requirement message and blocks import for PowerShell below 7' {
        $result = Get-DevRigInspectorVersionGuardResult -DetectedVersion ([version] '5.1.26100.9444') -PwshAvailable $true
        $result.ShouldImport | Should Be $false
        $result.Message | Should Not BeNullOrEmpty
        $result.Message | Should Match 'requires PowerShell 7 or later'
        $result.Message | Should Match '5\.1\.26100\.9444'
    }

    It 'tells a Windows PowerShell user with pwsh installed that they launched the wrong shell' {
        $result = Get-DevRigInspectorVersionGuardResult -DetectedVersion ([version] '5.1.26100.9444') -PwshAvailable $true
        $result.Message | Should Match 'PowerShell 7 \(pwsh\) is already installed'
        $result.Message | Should Match 'launched Windows PowerShell instead of PowerShell 7'
        $result.Message | Should Match '  pwsh'
    }

    It 'provides installation guidance when pwsh is not discoverable' {
        $result = Get-DevRigInspectorVersionGuardResult -DetectedVersion ([version] '5.1.26100.9444') -PwshAvailable $false
        $result.Message | Should Match 'was not found on this computer'
        $result.Message | Should Match 'winget install --id Microsoft\.PowerShell --source winget'
        $result.Message | Should Match 'https://learn\.microsoft\.com'
    }

    It 'never installs or modifies PowerShell automatically according to its own message' {
        $result = Get-DevRigInspectorVersionGuardResult -DetectedVersion ([version] '5.1.26100.9444') -PwshAvailable $false
        $result.Message | Should Match 'does not install or modify PowerShell automatically'
    }

    It 'the version-guard decision function performs no module import as a side effect' {
        $before = @(Get-Module -Name DevRigInspector -ErrorAction SilentlyContinue).Count
        Get-DevRigInspectorVersionGuardResult -DetectedVersion ([version] '5.1.26100.9444') -PwshAvailable $true | Out-Null
        $after = @(Get-Module -Name DevRigInspector -ErrorAction SilentlyContinue).Count
        $after | Should Be $before
    }
}

Describe 'Start-DevRigInspector.ps1 real launch under PowerShell 7' {
    It 'imports the module and runs Invoke-DevRigInspection producing normal output' {
        $output = & pwsh -NoLogo -NoProfile -File $launcherPath 2>&1 | Out-String
        $LASTEXITCODE | Should Be 0
        $output | Should Match 'Dev Rig Inspector'
        $output | Should Match 'Overall:'
    }

    It 'resolves the module path independently of the caller current directory' {
        Push-Location $env:TEMP
        try {
            $output = & pwsh -NoLogo -NoProfile -File $launcherPath 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        $exitCode | Should Be 0
        $output | Should Match 'Overall:'
    }
}

Describe 'Start-DevRigInspector.cmd' {
    It 'does not forward passthrough parameters to the PowerShell 7 launcher' {
        # Slice 1 defines a simple first-run entry point with no parameter-forwarding contract.
        $cmdContent = Get-Content -Raw $cmdPath
        $cmdContent | Should Not Match '-File "%~dp0Start-DevRigInspector\.ps1"\s+%\*'
        $cmdContent | Should Match '-File "%~dp0Start-DevRigInspector\.ps1"\s*[\r\n]'
    }

    It 'discovers pwsh, launches the PowerShell 7 launcher, and propagates a successful exit code' {
        $output = & cmd.exe /c "`"$cmdPath`"" 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        $exitCode | Should Be 0
        $output | Should Match 'Overall:'
    }

    It 'exits nonzero with installation guidance when pwsh cannot be found on PATH' {
        # Restrict PATH only for this one child cmd.exe process; the real session/workstation PATH is untouched.
        $argString = 'set "PATH=C:\Windows\System32;C:\Windows" && "' + $cmdPath + '"'
        $output = & cmd.exe /c $argString 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        $exitCode | Should Not Be 0
        $output | Should Match 'PowerShell 7 was not found on this computer'
        $output | Should Match 'winget install --id Microsoft\.PowerShell --source winget'
        $output | Should Match 'does not install or modify PowerShell automatically'
    }
}
