$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

function global:New-TestNodeHealth {
    param(
        [bool] $NodeRunnable = $true,
        [bool] $NpmRunnable = $true,
        [bool] $GlobalPathExists = $true,
        [bool] $GlobalPathOnPath = $true,
        [bool] $Ps1Selected = $false
    )

    $node = [pscustomobject]@{ name = 'node.exe'; path = 'C:\Node\node.exe'; version = if ($NodeRunnable) { '24.19.0' } else { $null }; runnable = $NodeRunnable; order = 1 }
    $npmCmd = [pscustomobject]@{ name = 'npm.cmd'; commandType = 'Application'; path = 'C:\Node\npm.cmd'; normalizedParentDirectory = 'C:\Node'; order = 2; runnable = $NpmRunnable; version = if ($NpmRunnable) { '11.17.0' } else { $null } }
    $npmPs1 = [pscustomobject]@{ name = 'npm.ps1'; commandType = 'ExternalScript'; path = 'C:\Node\npm.ps1'; normalizedParentDirectory = 'C:\Node'; order = 1; runnable = $false; version = $null }
    $selectedCommand = if ($Ps1Selected) { $npmPs1 } else { $npmCmd }
    [pscustomobject]@{
        node = [pscustomobject]@{ selected = $node; commandCandidates = @($node); runnable = $NodeRunnable }
        npm = [pscustomobject]@{
            selectedCommand = $selectedCommand
            probeCommand = $npmCmd
            commandCandidates = @($npmCmd)
            launcherVariants = @($npmPs1, $npmCmd, [pscustomobject]@{ name = 'npm'; commandType = 'Application'; path = 'C:\Node\npm'; normalizedParentDirectory = 'C:\Node'; order = 3 })
            version = if ($NpmRunnable) { '11.17.0' } else { $null }
            runnable = $NpmRunnable
            prefix = 'C:\Users\test\AppData\Roaming\npm'
            globalCommandPath = 'C:\Users\test\AppData\Roaming\npm'
            globalPathExists = $GlobalPathExists
            globalPathOnPath = $GlobalPathOnPath
        }
    }
}

Describe 'Node and npm health' {
    It 'reports functioning Node and npm without warnings' {
        InModuleScope DevRigInspector {
            $findings = @(Get-NodeHealthDiagnostics -NodeHealth (New-TestNodeHealth))
            ($findings | Where-Object code -eq 'NodeRuntimeDetected').severity | Should Be 'Info'
            ($findings | Where-Object code -eq 'NpmDetected').severity | Should Be 'Info'
            ($findings | Where-Object code -eq 'NodeNpmPairing').severity | Should Be 'Info'
            @($findings | Where-Object severity -eq 'Warning').Count | Should Be 0
        }
    }

    It 'reports a selected Node executable failure as Error' {
        InModuleScope DevRigInspector {
            $finding = @(Get-NodeHealthDiagnostics -NodeHealth (New-TestNodeHealth -NodeRunnable $false)) |
                Where-Object code -eq 'NodeRuntimeUnavailable'
            $finding.severity | Should Be 'Error'
        }
    }

    It 'treats same-directory npm launcher variants as benign' {
        InModuleScope DevRigInspector {
            $findings = @(Get-NodeHealthDiagnostics -NodeHealth (New-TestNodeHealth))
            ($findings | Where-Object code -eq 'NpmLauncherVariants').severity | Should Be 'Info'
            @($findings | Where-Object { $_.code -eq 'NpmLauncherResolution' -and $_.severity -eq 'Warning' }).Count | Should Be 0
        }
    }

    It 'does not warn when npm.ps1 is selected but npm.cmd executes successfully' {
        InModuleScope DevRigInspector {
            $finding = @(Get-NodeHealthDiagnostics -NodeHealth (New-TestNodeHealth -Ps1Selected $true)) |
                Where-Object code -eq 'NpmLauncherResolution'
            $finding.severity | Should Be 'Info'
            $finding.message | Should Match 'noninteractive external-process probes'
        }
    }

    It 'reports npm unavailable without claiming Node is broken' {
        InModuleScope DevRigInspector {
            $findings = @(Get-NodeHealthDiagnostics -NodeHealth (New-TestNodeHealth -NpmRunnable $false))
            @($findings | Where-Object code -eq 'NodeRuntimeUnavailable').Count | Should Be 0
            @($findings | Where-Object code -eq 'NpmDetected').Count | Should Be 0
        }
    }

    It 'reports global path existence, missing path context, and path reachability conservatively' {
        InModuleScope DevRigInspector {
            $missing = @(Get-NodeHealthDiagnostics -NodeHealth (New-TestNodeHealth -GlobalPathExists $false -GlobalPathOnPath $false))
            ($missing | Where-Object code -eq 'NpmGlobalPathMissing').severity | Should Be 'Info'
            @($missing | Where-Object code -eq 'NpmGlobalPathNotOnPath').Count | Should Be 0

            $notOnPath = @(Get-NodeHealthDiagnostics -NodeHealth (New-TestNodeHealth -GlobalPathExists $true -GlobalPathOnPath $false))
            ($notOnPath | Where-Object code -eq 'NpmGlobalPathNotOnPath').severity | Should Be 'Warning'
        }
    }

    It 'does not serialize npm credentials or raw configuration' {
        InModuleScope DevRigInspector {
            $health = New-TestNodeHealth
            $json = $health | ConvertTo-Json -Depth 12
            $json | Should Not Match 'NPM_TOKEN'
            $json | Should Not Match '_authToken'
            $json | Should Not Match 'registry.npmjs.org'
            $json | Should Match '11.17.0'
        }
    }

    It 'preserves Node resolver precedence and collects npm prefix through existing helpers' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand {
                param([string] $CommandName)
                $path = if ($CommandName -eq 'node') { 'C:\Node\node.exe' } else { 'C:\Node\npm.cmd' }
                $name = if ($CommandName -eq 'node') { 'node.exe' } else { 'npm.cmd' }
                [pscustomobject]@{
                    selected = [pscustomobject]@{ name = $name; commandType = 'Application'; path = $path; source = $path; normalizedParentDirectory = 'C:\Node'; order = 1 }
                    candidates = @([pscustomobject]@{ name = $name; commandType = 'Application'; path = $path; source = $path; normalizedParentDirectory = 'C:\Node'; order = 1 })
                }
            }
            Mock Get-Command {
                param([string[]] $Name)
                if ($Name -contains 'npm') {
                    @(
                        [pscustomobject]@{ Name = 'npm.ps1'; CommandType = 'ExternalScript'; Path = 'C:\Node\npm.ps1'; Source = 'C:\Node\npm.ps1' }
                        [pscustomobject]@{ Name = 'npm.cmd'; CommandType = 'Application'; Path = 'C:\Node\npm.cmd'; Source = 'C:\Node\npm.cmd' }
                    )
                } else { @() }
            }
            Mock Invoke-ExternalCommand {
                param([string] $FilePath, [string[]] $Arguments)
                $output = if ($Arguments -contains 'prefix') { 'C:\Users\test\AppData\Roaming\npm' } elseif ($FilePath -like '*node.exe') { 'v24.19.0' } else { '11.17.0' }
                [pscustomobject]@{ exitCode = 0; standardOutput = $output; standardError = ''; timedOut = $false; durationMilliseconds = 1 }
            }
            $result = Get-NodeHealthInventory
            $result.status | Should Be 'Available'
            $result.data.node.selected.order | Should Be 1
            $result.data.node.selected.path | Should Be 'C:\Node\node.exe'
            $result.data.npm.prefix | Should Be 'C:\Users\test\AppData\Roaming\npm'
            $result.data.npm.runnable | Should Be $true
            $result.data.npm.selectedCommand.name | Should Be 'npm.ps1'
            $result.data.npm.probeCommand.name | Should Be 'npm.cmd'
        }
    }
}