$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

function global:New-TestPythonHealth {
    param(
        [object[]] $Runtimes = @(),
        [object] $Selected = $null,
        [bool] $PyAvailable = $false,
        [bool] $UvAvailable = $false,
        [bool] $EnvironmentActive = $false,
        [object] $InterpreterExists = $null,
        [bool] $PipAvailable = $true
    )

    [pscustomobject]@{
        selected = $Selected
        runtimes = @($Runtimes)
        commandCandidates = @($Runtimes)
        pyLauncher = [pscustomobject]@{ available = $PyAvailable; reportedPythonVersion = if ($PyAvailable) { '3.12.0' } else { $null }; selectedCommand = $null }
        uv = [pscustomobject]@{ available = $UvAvailable; version = if ($UvAvailable) { '0.12.15' } else { $null }; selectedCommand = $null }
        virtualEnvironment = [pscustomobject]@{ active = $EnvironmentActive; path = if ($EnvironmentActive) { 'C:\env' } else { $null }; expectedInterpreterPath = if ($EnvironmentActive) { 'C:\env\Scripts\python.exe' } else { $null }; interpreterExists = if ($EnvironmentActive) { $InterpreterExists } else { $null } }
        pip = [pscustomobject]@{ available = $PipAvailable; version = if ($PipAvailable) { '24.0' } else { $null } }
    }
}

Describe 'Python health' {
    It 'reports one functioning runtime without inventing coexistence' {
        InModuleScope DevRigInspector {
            $runtime = [pscustomobject]@{ path = 'C:\Python314\python.exe'; version = '3.14.7'; runnable = $true; windowsAppsAlias = $false; order = 1 }
            $findings = @(Get-PythonHealthDiagnostics -PythonHealth (New-TestPythonHealth -Runtimes @($runtime) -Selected $runtime))
            @($findings | Where-Object code -eq 'PythonRuntimeCoexistence').Count | Should Be 0
            @($findings | Where-Object code -eq 'PythonInterpreterUnavailable').Count | Should Be 0
        }
    }

    It 'classifies side-by-side runtimes as informational and follows resolution order instead of highest version' {
        InModuleScope DevRigInspector {
            $selected = [pscustomobject]@{ path = 'C:\Python312\python.exe'; version = '3.12.9'; runnable = $true; windowsAppsAlias = $false; order = 1 }
            $other = [pscustomobject]@{ path = 'C:\Python314\python.exe'; version = '3.14.7'; runnable = $true; windowsAppsAlias = $false; order = 2 }
            $finding = @(Get-PythonHealthDiagnostics -PythonHealth (New-TestPythonHealth -Runtimes @($selected, $other) -Selected $selected)) |
                Where-Object code -eq 'PythonRuntimeCoexistence'
            $finding.severity | Should Be 'Info'
            $finding.message | Should Match '3.12.9'
            $finding.evidence.selectedWinner.order | Should Be 1
        }
    }

    It 'reports an alias behind a real interpreter as informational and alias-first resolution as warning' {
        InModuleScope DevRigInspector {
            $real = [pscustomobject]@{ path = 'C:\Python314\python.exe'; version = '3.14.7'; runnable = $true; windowsAppsAlias = $false; order = 1 }
            $alias = [pscustomobject]@{ path = 'C:\Users\test\AppData\Local\Microsoft\WindowsApps\python.exe'; version = $null; runnable = $false; windowsAppsAlias = $true; order = 2 }
            $behind = @(Get-PythonHealthDiagnostics -PythonHealth (New-TestPythonHealth -Runtimes @($real, $alias) -Selected $real))
            ($behind | Where-Object code -eq 'PythonAliasDetected').severity | Should Be 'Info'
            @($behind | Where-Object code -eq 'PythonAliasWinsResolution').Count | Should Be 0

            $aliasFirst = [pscustomobject]@{ path = $alias.path; version = '3.14.7'; runnable = $true; windowsAppsAlias = $true; order = 1 }
            $installedSecond = [pscustomobject]@{ path = $real.path; version = '3.14.7'; runnable = $true; windowsAppsAlias = $false; order = 2 }
            $winning = @(Get-PythonHealthDiagnostics -PythonHealth (New-TestPythonHealth -Runtimes @($aliasFirst, $installedSecond) -Selected $aliasFirst)) |
                Where-Object code -eq 'PythonAliasWinsResolution'
            $winning.severity | Should Be 'Warning'
        }
    }

    It 'reports a selected interpreter that cannot run as an error' {
        InModuleScope DevRigInspector {
            $runtime = [pscustomobject]@{ path = 'C:\Python\python.exe'; version = $null; runnable = $false; windowsAppsAlias = $false; order = 1 }
            $finding = @(Get-PythonHealthDiagnostics -PythonHealth (New-TestPythonHealth -Runtimes @($runtime) -Selected $runtime)) |
                Where-Object code -eq 'PythonInterpreterUnavailable'
            $finding.severity | Should Be 'Error'
        }
    }

    It 'reports py, uv, valid and broken virtual environments, and pip conservatively' {
        InModuleScope DevRigInspector {
            $runtime = [pscustomobject]@{ path = 'C:\Python\python.exe'; version = '3.14.7'; runnable = $true; windowsAppsAlias = $false; order = 1 }
            $health = New-TestPythonHealth -Runtimes @($runtime) -Selected $runtime -PyAvailable $true -UvAvailable $true -EnvironmentActive $true -InterpreterExists $true -PipAvailable $true
            $findings = @(Get-PythonHealthDiagnostics -PythonHealth $health)
            ($findings | Where-Object code -eq 'PythonPyLauncherDetected').severity | Should Be 'Info'
            ($findings | Where-Object code -eq 'PythonUvDetected').severity | Should Be 'Info'
            ($findings | Where-Object code -eq 'PythonVirtualEnvironmentActive').severity | Should Be 'Info'
            @($findings | Where-Object code -eq 'PythonPipUnavailable').Count | Should Be 0

            $broken = @(Get-PythonHealthDiagnostics -PythonHealth (New-TestPythonHealth -Runtimes @($runtime) -Selected $runtime -EnvironmentActive $true -InterpreterExists $false -PipAvailable $false))
            ($broken | Where-Object code -eq 'PythonVirtualEnvironmentInterpreterMissing').severity | Should Be 'Warning'
            ($broken | Where-Object code -eq 'PythonPipUnavailable').severity | Should Be 'Info'
        }
    }

    It 'does not produce a finding for no active virtual environment and preserves safe JSON evidence' {
        InModuleScope DevRigInspector {
            $runtime = [pscustomobject]@{ path = 'C:\Python\python.exe'; version = '3.14.7'; runnable = $true; windowsAppsAlias = $false; order = 1 }
            $health = New-TestPythonHealth -Runtimes @($runtime) -Selected $runtime -EnvironmentActive $false
            $findings = @(Get-PythonHealthDiagnostics -PythonHealth $health)
            @($findings | Where-Object code -like '*VirtualEnvironment*').Count | Should Be 0
            $json = $health | ConvertTo-Json -Depth 12
            $json | Should Not Match 'SECRET'
            $json | Should Not Match 'PYPI_TOKEN'
            $json | Should Match '3.14.7'
        }
    }

    It 'keeps selected Python aligned with the resolver winner and candidate precedence' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand {
                param([string] $CommandName)
                if ($CommandName -eq 'python') {
                    $candidates = @(
                        [pscustomobject]@{ name = 'python.exe'; commandType = 'Application'; path = 'C:\Python314\python.exe'; source = 'C:\Python314\python.exe'; normalizedParentDirectory = 'C:\Python314'; order = 1 }
                        [pscustomobject]@{ name = 'python.exe'; commandType = 'Application'; path = 'C:\Python313\python.exe'; source = 'C:\Python313\python.exe'; normalizedParentDirectory = 'C:\Python313'; order = 2 }
                        [pscustomobject]@{ name = 'python.exe'; commandType = 'Application'; path = 'C:\Python312\python.exe'; source = 'C:\Python312\python.exe'; normalizedParentDirectory = 'C:\Python312'; order = 3 }
                    )
                    return [pscustomobject]@{ selected = $candidates[0]; candidates = $candidates }
                }
                $path = if ($CommandName -eq 'py') { 'C:\Windows\py.exe' } else { 'C:\Tools\uv.exe' }
                [pscustomobject]@{
                    selected = [pscustomobject]@{ name = "$CommandName.exe"; commandType = 'Application'; path = $path; source = $path; normalizedParentDirectory = (Split-Path -Parent $path); order = 1 }
                    candidates = @([pscustomobject]@{ name = "$CommandName.exe"; commandType = 'Application'; path = $path; source = $path; normalizedParentDirectory = (Split-Path -Parent $path); order = 1 })
                }
            }
            Mock Invoke-ExternalCommand {
                param([string] $FilePath, [string[]] $Arguments)
                $output = if ($Arguments -contains 'pip') { 'pip 24.0' } elseif ($FilePath -like '*Python314*') { 'Python 3.14.7' } elseif ($FilePath -like '*Python313*') { 'Python 3.13.7' } elseif ($FilePath -like '*Python312*') { 'Python 3.12.4' } elseif ($FilePath -like '*py.exe') { 'Python 3.14.7' } else { 'uv 0.12.15' }
                [pscustomobject]@{ exitCode = 0; standardOutput = $output; standardError = ''; timedOut = $false; durationMilliseconds = 1 }
            }

            $result = Get-PythonHealthInventory
            $result.data.selected.path | Should Be 'C:\Python314\python.exe'
            $result.data.selected.order | Should Be 1
            $result.data.runtimes.path | Should Be @('C:\Python314\python.exe', 'C:\Python313\python.exe', 'C:\Python312\python.exe')
            $result.data.runtimes.order | Should Be @(1, 2, 3)
        }
    }

    It 'collects selected runtime, launcher, uv, and pip state through existing helpers' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand {
                param([string] $CommandName)
                $path = switch ($CommandName) {
                    'python' { 'C:\Python\python.exe' }
                    'py' { 'C:\Windows\py.exe' }
                    'uv' { 'C:\Tools\uv.exe' }
                }
                [pscustomobject]@{
                    selected = [pscustomobject]@{ name = "$CommandName.exe"; commandType = 'Application'; path = $path; source = $path; normalizedParentDirectory = (Split-Path -Parent $path); order = 1 }
                    candidates = @([pscustomobject]@{ name = "$CommandName.exe"; commandType = 'Application'; path = $path; source = $path; normalizedParentDirectory = (Split-Path -Parent $path); order = 1 })
                }
            }
            Mock Invoke-ExternalCommand {
                param([string] $FilePath, [string[]] $Arguments)
                $output = if ($Arguments -contains 'pip') { 'pip 24.0 from C:\Python\Lib\site-packages\pip' } elseif ($FilePath -like '*uv.exe') { 'uv 0.12.15' } elseif ($FilePath -like '*py.exe') { 'Python Launcher for Windows 3.12' } else { 'Python 3.14.7' }
                [pscustomobject]@{ exitCode = 0; standardOutput = $output; standardError = ''; timedOut = $false; durationMilliseconds = 1 }
            }
            $oldVirtualEnv = $env:VIRTUAL_ENV
            try {
                Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
                $result = Get-PythonHealthInventory
                $result.status | Should Be 'Available'
                $result.data.selected.version | Should Be '3.14.7'
                $result.data.pyLauncher.available | Should Be $true
                $result.data.pyLauncher.reportedPythonVersion | Should Be '3.12'
                $result.data.pyLauncher.version | Should Be $null
                $result.data.uv.available | Should Be $true
                $result.data.pip.available | Should Be $true
                $result.data.virtualEnvironment.active | Should Be $false
            } finally {
                if ($null -eq $oldVirtualEnv) { Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue } else { $env:VIRTUAL_ENV = $oldVirtualEnv }
            }
        }
    }

    It 'does not terminate collection when Python, py, uv, or pip probes throw' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand {
                param([string] $CommandName)
                $path = "C:\$CommandName.exe"
                [pscustomobject]@{
                    selected = [pscustomobject]@{ name = "$CommandName.exe"; commandType = 'Application'; path = $path; source = $path; normalizedParentDirectory = 'C:\'; order = 1 }
                    candidates = @([pscustomobject]@{ name = "$CommandName.exe"; commandType = 'Application'; path = $path; source = $path; normalizedParentDirectory = 'C:\'; order = 1 })
                }
            }
            Mock Invoke-ExternalCommand { throw 'probe start failed' }
            $result = Get-PythonHealthInventory
            $result.status | Should Be 'Available'
            $result.data.selected.runnable | Should Be $false
            $result.data.selected.probeFailed | Should Be $true
            $result.data.pip.available | Should Be $false
            $result.data.pyLauncher.available | Should Be $false
            $result.data.uv.available | Should Be $false
        }
    }
}