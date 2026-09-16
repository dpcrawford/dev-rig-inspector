$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

function global:New-TestHealthDefaults {
    [pscustomobject]@{
        powerShell = [pscustomobject]@{
            active = [pscustomobject]@{ edition = 'Core'; version = '7.6.6'; executable = 'C:\Program Files\PowerShell\7\pwsh.exe' }
            windowsPowerShell = [pscustomobject]@{ present = $true; version = '5.1.22621.1' }
            powerShell7 = [pscustomobject]@{ selectedCommand = [pscustomobject]@{ path = 'C:\Program Files\PowerShell\7\pwsh.exe' } }
            effectiveExecutionPolicy = [pscustomobject]@{ scope = 'CurrentUser'; policy = 'RemoteSigned' }
        }
        git = [pscustomobject]@{
            git = [pscustomobject]@{
                installed = $true
                version = 'git version 2.55.0'
                identity = [pscustomobject]@{
                    name = [pscustomobject]@{ configured = $true }
                    email = [pscustomobject]@{ configured = $true }
                }
                defaultBranch = [pscustomobject]@{ configured = $true; value = 'main' }
                autocrlf = [pscustomobject]@{ configured = $true; value = 'true' }
                credentialHelper = [pscustomobject]@{ configured = $true; types = @('manager-core') }
            }
            githubCli = [pscustomobject]@{
                installed = $true
                version = 'gh version 2.101.0'
                authentication = [pscustomobject]@{ authenticated = $true; hosts = @('github.com', 'internal.example') }
            }
        }
        python = [pscustomobject]@{
            selected = [pscustomobject]@{ path = 'C:\Program Files\Python314\python.exe'; version = '3.14.7'; runnable = $true }
            runtimes = @(
                [pscustomobject]@{ path = 'C:\Program Files\Python314\python.exe'; version = '3.14.7' },
                [pscustomobject]@{ path = 'C:\Program Files\Python313\python.exe'; version = '3.13.7' }
            )
            pyLauncher = [pscustomobject]@{ available = $true; reportedPythonVersion = '3.14.7' }
            uv = [pscustomobject]@{ available = $true; version = '0.12.15' }
            virtualEnvironment = [pscustomobject]@{ active = $false; path = $null; interpreterExists = $null }
            pip = [pscustomobject]@{ available = $true; version = '24.0' }
        }
        node = [pscustomobject]@{
            node = [pscustomobject]@{ selected = [pscustomobject]@{ path = 'C:\Program Files\nodejs\node.exe'; version = '24.19.0' }; runnable = $true }
            npm = [pscustomobject]@{
                selectedCommand = [pscustomobject]@{ path = 'C:\Program Files\nodejs\npm.ps1' }
                probeCommand = [pscustomobject]@{ path = 'C:\Program Files\nodejs\npm.cmd' }
                version = '11.17.0'
                prefix = 'C:\Users\test\AppData\Roaming\npm'
                globalCommandPath = 'C:\Users\test\AppData\Roaming\npm'
                globalPathExists = $false
                globalPathOnPath = $true
            }
        }
        virtualization = [pscustomobject]@{
            virtualizationCapability = 'Available'
            hypervisorState = 'Present'
            firmwareVirtualization = 'Enabled'
            readiness = [pscustomobject]@{ wsl2Ready = 'Ready' }
            wsl = [pscustomobject]@{
                installed = $true
                version = "WSL version: 2.7.14.0`r`nKernel version: 6.18.33.2-2"
                status = "Default Version: 2`r`nWSL1 is not supported with your current machine configuration."
                distributionParseStatus = 'Parsed'
                distributions = @(
                    [pscustomobject]@{ name = 'Ubuntu'; version = 2; state = 'Running'; isDefault = $true },
                    [pscustomobject]@{ name = 'Debian'; version = 1; state = 'Stopped'; isDefault = $false }
                )
            }
        }
    }
}

function global:New-TestFullInventoryJson {
    param(
        [object] $Health,
        [switch] $NoHealth
    )
    $diagnostics = [pscustomobject]@{
        collectorResults = @()
        findings = @()
    }
    if (-not $NoHealth) {
        $diagnostics | Add-Member -NotePropertyName health -NotePropertyValue $Health
    }
    [pscustomobject]@{
        schemaVersion = '0.1'
        collectorVersion = '0.4.0'
        collectedAt = [DateTime]::UtcNow.ToString('o')
        computer = [pscustomobject]@{ hostname = 'TEST-HOST'; cpu = [pscustomobject]@{ name = 'Test CPU' }; physicalMemoryBytes = 34359738368 }
        tools = @()
        diagnostics = $diagnostics
    } | ConvertTo-Json -Depth 20
}

function global:New-TestSnapshotFileFromHealth {
    param([object] $Health, [switch] $NoHealth)
    $path = Join-Path $env:TEMP ('dev-rig-health-comparison-' + [guid]::NewGuid() + '.json')
    Set-Content -LiteralPath $path -Value (New-TestFullInventoryJson -Health $Health -NoHealth:$NoHealth) -Encoding utf8
    $path
}

Describe 'Health comparison' {
    AfterEach {
        Remove-Item -LiteralPath $script:refPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $script:curPath -Force -ErrorAction SilentlyContinue
    }

    Context 'Compatibility and availability' {
        It 'produces zero health changes when the reference snapshot has no diagnostics.health at all' {
            $script:refPath = New-TestSnapshotFileFromHealth -NoHealth
            $script:curPath = New-TestSnapshotFileFromHealth -Health (New-TestHealthDefaults)

            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
            $result.changes.health.Count | Should Be 0
            $result.summary.healthChanges | Should Be 0
        }

        It 'does not manufacture a removal when the current subsystem is temporarily unavailable' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.python = [pscustomobject]@{}

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current

            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
            @($result.changes.health | Where-Object subsystem -eq 'python').Count | Should Be 0
        }
    }

    Context 'PowerShell' {
        It 'detects an active version change' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.powerShell.active.version = '7.7.0'

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'powerShell' -and $_.field -eq 'active.version' }
            $change.changeType | Should Be 'Version'
            $change.before | Should Be '7.6.6'
            $change.after | Should Be '7.7.0'
        }

        It 'detects an execution-policy change' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.powerShell.effectiveExecutionPolicy.policy = 'AllSigned'

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'powerShell' -and $_.field -eq 'effectiveExecutionPolicy.policy' }
            $change.changeType | Should Be 'Configuration'
            $change.before | Should Be 'RemoteSigned'
            $change.after | Should Be 'AllSigned'
        }

        It 'detects a selected pwsh path change' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.powerShell.powerShell7.selectedCommand.path = 'C:\Users\test\AppData\Local\Microsoft\WindowsApps\pwsh.exe'

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'powerShell' -and $_.field -eq 'powerShell7.selectedCommand.path' }
            $change.changeType | Should Be 'Resolution'
        }
    }

    Context 'Git and GitHub' {
        It 'detects explicit email becoming missing' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.git.git.identity.email.configured = $false

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'git' -and $_.field -eq 'git.identity.email.configured' }
            $change.changeType | Should Be 'Configuration'
            $change.before | Should Be $true
            $change.after | Should Be $false
        }

        It 'detects GitHub authenticated becoming unauthenticated' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.git.githubCli.authentication.authenticated = $false

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'git' -and $_.field -eq 'githubCli.authentication.authenticated' }
            $change.changeType | Should Be 'State'
        }

        It 'does not report a change when authenticated hosts are only reordered' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.git.githubCli.authentication.hosts = @('internal.example', 'github.com')

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            @($result.changes.health | Where-Object { $_.subsystem -eq 'git' -and $_.field -eq 'githubCli.authentication.hosts' }).Count | Should Be 0
        }
    }

    Context 'Python' {
        It 'detects the selected interpreter path changing' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.python.selected.path = 'C:\Users\test\AppData\Local\Microsoft\WindowsApps\python.exe'

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'python' -and $_.field -eq 'selected.path' }
            $change.changeType | Should Be 'Resolution'
        }

        It 'detects the selected version changing' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.python.selected.version = '3.15.0'

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'python' -and $_.field -eq 'selected.version' }
            $change.changeType | Should Be 'Version'
        }

        It 'detects a runtime being added' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.python.runtimes = @($current.python.runtimes) + [pscustomobject]@{ path = 'C:\Program Files\Python315\python.exe'; version = '3.15.0' }

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'python' -and $_.kind -eq 'Added' }
            $change.field | Should Be 'runtimes'
        }

        It 'detects a runtime being removed' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.python.runtimes = @($current.python.runtimes | Where-Object { $_.path -notlike '*Python313*' })

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'python' -and $_.kind -eq 'Removed' }
            $change.field | Should Be 'runtimes'
        }

        It 'does not report a change when the runtime array is only reordered' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.python.runtimes = @($current.python.runtimes[1], $current.python.runtimes[0])

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            @($result.changes.health | Where-Object { $_.subsystem -eq 'python' -and $_.field -eq 'runtimes' }).Count | Should Be 0
        }

        It 'detects virtual environment activation changing' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.python.virtualEnvironment.active = $true
            $current.python.virtualEnvironment.path = 'C:\project\.venv'

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'python' -and $_.field -eq 'virtualEnvironment.active' }
            $change.changeType | Should Be 'State'
        }

        It 'detects uv availability changing' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.python.uv.available = $false
            $current.python.uv.version = $null

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'python' -and $_.field -eq 'uv.available' }
            $change.changeType | Should Be 'Availability'
        }
    }

    Context 'Node and npm' {
        It 'detects a Node version change' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.node.node.selected.version = '25.0.0'

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'node' -and $_.field -eq 'node.selected.version' }
            $change.changeType | Should Be 'Version'
        }

        It 'detects the selected Node path changing' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.node.node.selected.path = 'D:\nodejs\node.exe'

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'node' -and $_.field -eq 'node.selected.path' }
            $change.changeType | Should Be 'Resolution'
        }

        It 'detects the npm shell launcher changing' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.node.npm.selectedCommand.path = 'C:\Program Files\nodejs\npm.cmd'

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'node' -and $_.field -eq 'npm.selectedCommand.path' }
            $change.changeType | Should Be 'Resolution'
        }

        It 'detects the npm probe launcher changing' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.node.npm.probeCommand.path = 'C:\Program Files\nodejs\npm'

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'node' -and $_.field -eq 'npm.probeCommand.path' }
            $change.changeType | Should Be 'Resolution'
        }

        It 'detects the npm global path going from missing to existing' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.node.npm.globalPathExists = $true

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'node' -and $_.field -eq 'npm.globalPathExists' }
            $change.before | Should Be $false
            $change.after | Should Be $true
        }
    }

    Context 'WSL and virtualization' {
        It 'detects WSL going from absent to installed' {
            $reference = New-TestHealthDefaults
            $reference.virtualization.wsl.installed = $false
            $current = New-TestHealthDefaults

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'virtualization' -and $_.field -eq 'wsl.installed' }
            $change.before | Should Be $false
            $change.after | Should Be $true
        }

        It 'detects a distribution being added' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.virtualization.wsl.distributions = @($current.virtualization.wsl.distributions) + [pscustomobject]@{ name = 'Fedora'; version = 2; state = 'Running'; isDefault = $false }

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'virtualization' -and $_.kind -eq 'Added' }
            $change.field | Should Be 'wsl.distributions'
        }

        It 'detects a distribution being removed' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.virtualization.wsl.distributions = @($current.virtualization.wsl.distributions | Where-Object name -ne 'Debian')

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'virtualization' -and $_.kind -eq 'Removed' }
            $change.field | Should Be 'wsl.distributions'
        }

        It 'detects a distribution moving from WSL 1 to WSL 2' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            ($current.virtualization.wsl.distributions | Where-Object name -eq 'Debian').version = 2

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'virtualization' -and $_.field -eq 'wsl.distributions.Debian.version' }
            $change.before | Should Be '1'
            $change.after | Should Be '2'
        }

        It 'does not report a change when the distribution array is only reordered' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.virtualization.wsl.distributions = @($current.virtualization.wsl.distributions[1], $current.virtualization.wsl.distributions[0])

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            @($result.changes.health | Where-Object { $_.subsystem -eq 'virtualization' -and $_.field -like 'wsl.distributions*' }).Count | Should Be 0
        }

        It 'detects a hypervisor state change' {
            $reference = New-TestHealthDefaults
            $reference.virtualization.hypervisorState = 'NotPresent'
            $current = New-TestHealthDefaults

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'virtualization' -and $_.field -eq 'hypervisorState' }
            $change.before | Should Be 'NotPresent'
            $change.after | Should Be 'Present'
        }

        It 'detects readiness moving from Unknown to Ready' {
            $reference = New-TestHealthDefaults
            $reference.virtualization.readiness.wsl2Ready = 'Unknown'
            $current = New-TestHealthDefaults

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'virtualization' -and $_.field -eq 'readiness.wsl2Ready' }
            $change.before | Should Be 'Unknown'
            $change.after | Should Be 'Ready'
        }
    }

    Context 'Windows optional features (not compared in Slice 2)' {
        # Feature state/queryStatus is collected but Compare-HealthState intentionally does not
        # surface it as comparable evidence; Unavailable/Error means "could not determine", not a state.
        It 'produces no feature-state drift when a feature moves from Unavailable/Error to Enabled/Success' {
            $reference = New-TestHealthDefaults
            $reference.virtualization | Add-Member -NotePropertyName features -NotePropertyValue @(
                [pscustomobject]@{ name = 'VirtualMachinePlatform'; state = 'Unavailable'; queryStatus = 'Error'; error = 'The requested operation requires elevation.' }
            )
            $current = New-TestHealthDefaults
            $current.virtualization | Add-Member -NotePropertyName features -NotePropertyValue @(
                [pscustomobject]@{ name = 'VirtualMachinePlatform'; state = 'Enabled'; queryStatus = 'Available'; error = $null }
            )

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            @($result.changes.health | Where-Object { $_.field -like 'features*' }).Count | Should Be 0
            $result.changes.health.Count | Should Be 0
        }

        It 'does not report a change when a feature moves from Enabled/Success to Disabled/Success' {
            $reference = New-TestHealthDefaults
            $reference.virtualization | Add-Member -NotePropertyName features -NotePropertyValue @(
                [pscustomobject]@{ name = 'Microsoft-Windows-Subsystem-Linux'; state = 'Enabled'; queryStatus = 'Available'; error = $null }
            )
            $current = New-TestHealthDefaults
            $current.virtualization | Add-Member -NotePropertyName features -NotePropertyValue @(
                [pscustomobject]@{ name = 'Microsoft-Windows-Subsystem-Linux'; state = 'Disabled'; queryStatus = 'Available'; error = $null }
            )

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            @($result.changes.health | Where-Object { $_.field -like 'features*' }).Count | Should Be 0
            $result.changes.health.Count | Should Be 0
        }

        It 'does not suppress an unrelated hypervisor state change when feature evidence is unavailable in both snapshots' {
            $reference = New-TestHealthDefaults
            $reference.virtualization.hypervisorState = 'NotPresent'
            $reference.virtualization | Add-Member -NotePropertyName features -NotePropertyValue @(
                [pscustomobject]@{ name = 'Microsoft-Hyper-V-All'; state = 'Unavailable'; queryStatus = 'Error'; error = 'The requested operation requires elevation.' }
            )
            $current = New-TestHealthDefaults
            $current.virtualization | Add-Member -NotePropertyName features -NotePropertyValue @(
                [pscustomobject]@{ name = 'Microsoft-Hyper-V-All'; state = 'Unavailable'; queryStatus = 'Error'; error = 'The requested operation requires elevation.' }
            )

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'virtualization' -and $_.field -eq 'hypervisorState' }
            $change.before | Should Be 'NotPresent'
            $change.after | Should Be 'Present'
        }

        It 'does not suppress WSL distribution comparison when feature evidence is unavailable in both snapshots' {
            $reference = New-TestHealthDefaults
            $reference.virtualization | Add-Member -NotePropertyName features -NotePropertyValue @(
                [pscustomobject]@{ name = 'Microsoft-Windows-Subsystem-Linux'; state = 'Unavailable'; queryStatus = 'Error'; error = 'The requested operation requires elevation.' }
            )
            $current = New-TestHealthDefaults
            $current.virtualization | Add-Member -NotePropertyName features -NotePropertyValue @(
                [pscustomobject]@{ name = 'Microsoft-Windows-Subsystem-Linux'; state = 'Unavailable'; queryStatus = 'Error'; error = 'The requested operation requires elevation.' }
            )
            $current.virtualization.wsl.distributions = @($current.virtualization.wsl.distributions) + [pscustomobject]@{ name = 'Fedora'; version = 2; state = 'Running'; isDefault = $false }

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $change = $result.changes.health | Where-Object { $_.subsystem -eq 'virtualization' -and $_.kind -eq 'Added' }
            $change.field | Should Be 'wsl.distributions'
        }
    }

    Context 'Integration' {
        It 'reports zero health changes for identical v0.4 health snapshots' {
            $health = New-TestHealthDefaults
            $script:refPath = New-TestSnapshotFileFromHealth -Health $health
            $script:curPath = New-TestSnapshotFileFromHealth -Health (New-TestHealthDefaults)

            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
            $result.changes.health.Count | Should Be 0
            $result.summary.healthChanges | Should Be 0
        }

        It 'contributes health changes to totalChanges alongside existing tool comparison' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.python.selected.version = '3.15.0'

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current
            $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null

            $result.summary.healthChanges | Should Be 1
            $result.summary.totalChanges | Should Be 1
        }

        It 'includes health changes in -PassThru and -JsonOnly output' {
            $reference = New-TestHealthDefaults
            $current = New-TestHealthDefaults
            $current.git.githubCli.authentication.authenticated = $false

            $script:refPath = New-TestSnapshotFileFromHealth -Health $reference
            $script:curPath = New-TestSnapshotFileFromHealth -Health $current

            $passThruResult = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
            $passThruResult.changes.health.Count | Should Be 1

            $json = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -JsonOnly
            $parsed = $json | ConvertFrom-Json
            $parsed.changes.health.Count | Should Be 1
            $parsed.summary.healthChanges | Should Be 1
        }
    }
}
