$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

Describe 'PowerShell health' {
    It 'uses PowerShell execution-policy precedence to select the effective scope' {
        InModuleScope DevRigInspector {
            Mock Get-ExecutionPolicy {
                @(
                    [pscustomobject]@{ Scope = 'MachinePolicy'; ExecutionPolicy = 'Restricted' }
                    [pscustomobject]@{ Scope = 'UserPolicy'; ExecutionPolicy = 'Undefined' }
                    [pscustomobject]@{ Scope = 'Process'; ExecutionPolicy = 'RemoteSigned' }
                    [pscustomobject]@{ Scope = 'CurrentUser'; ExecutionPolicy = 'AllSigned' }
                    [pscustomobject]@{ Scope = 'LocalMachine'; ExecutionPolicy = 'RemoteSigned' }
                )
            }
            Mock Resolve-ToolCommand {
                [pscustomobject]@{ selected = $null; candidates = @() }
            }
            Mock Get-Process { [pscustomobject]@{ Path = 'C:\PowerShell\pwsh.exe' } }
            Mock Get-Module { @() }

            $result = Get-PowerShellHealthInventory
            $result.data.effectiveExecutionPolicy.scope | Should Be 'MachinePolicy'
            $result.data.effectiveExecutionPolicy.policy | Should Be 'Restricted'
            $result.data.executionPolicies.Count | Should Be 5
        }
    }

    It 'does not warn for a restrictive policy in a non-effective lower-precedence scope' {
        InModuleScope DevRigInspector {
            $health = [pscustomobject]@{
                windowsPowerShell = [pscustomobject]@{ present = $false; version = $null }
                powerShell7 = [pscustomobject]@{ commandCandidates = @(); selectedCommand = $null }
                effectiveExecutionPolicy = [pscustomobject]@{ scope = 'Process'; policy = 'RemoteSigned' }
                executionPolicies = @(
                    [pscustomobject]@{ scope = 'MachinePolicy'; policy = 'Undefined' }
                    [pscustomobject]@{ scope = 'UserPolicy'; policy = 'Undefined' }
                    [pscustomobject]@{ scope = 'Process'; policy = 'RemoteSigned' }
                    [pscustomobject]@{ scope = 'CurrentUser'; policy = 'Restricted' }
                    [pscustomobject]@{ scope = 'LocalMachine'; policy = 'RemoteSigned' }
                )
                psModulePath = @()
                pester = @()
            }

            @(Get-PowerShellHealthDiagnostics -PowerShellHealth $health) |
                Where-Object code -eq 'ExecutionPolicyRestrictsWorkflow' | Should BeNullOrEmpty
        }
    }

    It 'warns when the effective execution policy restricts local development' {
        InModuleScope DevRigInspector {
            $health = [pscustomobject]@{
                windowsPowerShell = [pscustomobject]@{ present = $false }
                powerShell7 = [pscustomobject]@{ commandCandidates = @(); selectedCommand = $null }
                effectiveExecutionPolicy = [pscustomobject]@{ scope = 'CurrentUser'; policy = 'AllSigned' }
                executionPolicies = @([pscustomobject]@{ scope = 'CurrentUser'; policy = 'AllSigned' })
                psModulePath = @()
                pester = @()
            }

            $finding = @(Get-PowerShellHealthDiagnostics -PowerShellHealth $health) |
                Where-Object code -eq 'ExecutionPolicyRestrictsWorkflow'
            $finding.severity | Should Be 'Warning'
            $finding.evidence.effective.scope | Should Be 'CurrentUser'
        }
    }

    It 'reports missing and duplicate PSModulePath entries without treating profile absence as a problem' {
        InModuleScope DevRigInspector {
            $health = [pscustomobject]@{
                windowsPowerShell = [pscustomobject]@{ present = $false }
                powerShell7 = [pscustomobject]@{ commandCandidates = @(); selectedCommand = $null }
                effectiveExecutionPolicy = $null
                executionPolicies = @()
                profiles = @(
                    [pscustomobject]@{ name = 'CurrentUserCurrentHost'; path = 'C:\Missing\profile.ps1'; exists = $false }
                )
                psModulePath = @(
                    [pscustomobject]@{ raw = 'C:\Missing\Modules'; expanded = 'C:\Missing\Modules'; normalized = 'C:\Missing\Modules'; exists = $false }
                    [pscustomobject]@{ raw = 'C:\Modules'; expanded = 'C:\Modules'; normalized = 'C:\Modules'; exists = $true }
                    [pscustomobject]@{ raw = 'c:\modules\'; expanded = 'c:\modules\'; normalized = 'c:\modules'; exists = $true }
                )
                pester = @()
            }

            $findings = @(Get-PowerShellHealthDiagnostics -PowerShellHealth $health)
            $missing = @($findings | Where-Object code -eq 'PSModulePathEntryMissing')
            $missing.Count | Should Be 1
            $missing.severity | Should Be 'Info'
            $missing.message | Should Match 'may be benign'
            $missing.evidence.raw | Should Be 'C:\Missing\Modules'
            $missing.evidence.expanded | Should Be 'C:\Missing\Modules'
            $missing.evidence.normalized | Should Be 'C:\Missing\Modules'
            $missing.evidence.exists | Should Be $false
            @($findings | Where-Object { $_.code -eq 'PSModulePathEntryMissing' -and $_.severity -eq 'Warning' }).Count | Should Be 0
            @($findings | Where-Object code -eq 'PSModulePathEntryDuplicate').Count | Should Be 1
            @($findings | Where-Object code -like '*Profile*').Count | Should Be 0
        }
    }

    It 'classifies Windows PowerShell and PowerShell 7 coexistence as informational' {
        InModuleScope DevRigInspector {
            $health = [pscustomobject]@{
                windowsPowerShell = [pscustomobject]@{ present = $true; version = '5.1.22621.1' }
                powerShell7 = [pscustomobject]@{
                    commandCandidates = @([pscustomobject]@{ path = 'C:\Program Files\PowerShell\7\pwsh.exe'; normalizedParentDirectory = 'C:\Program Files\PowerShell\7'; order = 1 })
                    selectedCommand = [pscustomobject]@{ path = 'C:\Program Files\PowerShell\7\pwsh.exe' }
                }
                effectiveExecutionPolicy = $null
                executionPolicies = @()
                psModulePath = @()
                pester = @()
            }

            $finding = @(Get-PowerShellHealthDiagnostics -PowerShellHealth $health) |
                Where-Object code -eq 'PowerShellEditionCoexistence'
            $finding.severity | Should Be 'Info'
        }
    }

    It 'treats same-install pwsh launchers as benign' {
        InModuleScope DevRigInspector {
            $health = [pscustomobject]@{
                windowsPowerShell = [pscustomobject]@{ present = $false }
                powerShell7 = [pscustomobject]@{
                    commandCandidates = @(
                        [pscustomobject]@{ name = 'pwsh.exe'; path = 'C:\PowerShell\pwsh.exe'; source = 'C:\PowerShell\pwsh.exe'; normalizedParentDirectory = 'C:\PowerShell'; order = 1 }
                        [pscustomobject]@{ name = 'pwsh.exe'; path = 'C:\PowerShell\pwsh.cmd'; source = 'C:\PowerShell\pwsh.cmd'; normalizedParentDirectory = 'C:\PowerShell'; order = 2 }
                    )
                    selectedCommand = [pscustomobject]@{ path = 'C:\PowerShell\pwsh.exe' }
                }
                effectiveExecutionPolicy = $null
                executionPolicies = @()
                psModulePath = @()
                pester = @()
            }

            @(Get-PowerShellHealthDiagnostics -PowerShellHealth $health) |
                Where-Object code -eq 'PowerShellLauncherResolution' | Should BeNullOrEmpty
        }
    }

    It 'warns when a WindowsApps pwsh alias wins over another location' {
        InModuleScope DevRigInspector {
            $health = [pscustomobject]@{
                windowsPowerShell = [pscustomobject]@{ present = $false }
                powerShell7 = [pscustomobject]@{
                    commandCandidates = @(
                        [pscustomobject]@{ name = 'pwsh.exe'; path = 'C:\Users\test\AppData\Local\Microsoft\WindowsApps\pwsh.exe'; source = 'alias'; normalizedParentDirectory = 'C:\Users\test\AppData\Local\Microsoft\WindowsApps'; order = 1 }
                        [pscustomobject]@{ name = 'pwsh.exe'; path = 'C:\PowerShell\pwsh.exe'; source = 'Path'; normalizedParentDirectory = 'C:\PowerShell'; order = 2 }
                    )
                    selectedCommand = [pscustomobject]@{ path = 'C:\Users\test\AppData\Local\Microsoft\WindowsApps\pwsh.exe' }
                }
                effectiveExecutionPolicy = $null
                executionPolicies = @()
                psModulePath = @()
                pester = @()
            }

            $finding = @(Get-PowerShellHealthDiagnostics -PowerShellHealth $health) |
                Where-Object code -eq 'PowerShellLauncherResolution'
            $finding.severity | Should Be 'Warning'
        }
    }

    It 'reports multiple Pester versions as informational and preserves their paths in JSON' {
        InModuleScope DevRigInspector {
            $health = [pscustomobject]@{
                windowsPowerShell = [pscustomobject]@{ present = $false }
                powerShell7 = [pscustomobject]@{ commandCandidates = @(); selectedCommand = $null }
                effectiveExecutionPolicy = $null
                executionPolicies = @()
                psModulePath = @()
                pester = @(
                    [pscustomobject]@{ version = '3.4.0'; path = 'C:\Modules\Pester\3.4.0' }
                    [pscustomobject]@{ version = '5.6.1'; path = 'C:\Modules\Pester\5.6.1' }
                )
            }

            $finding = @(Get-PowerShellHealthDiagnostics -PowerShellHealth $health) |
                Where-Object code -eq 'PesterVersionCompatibility'
            $finding.severity | Should Be 'Info'
            $json = [pscustomobject]@{ diagnostics = [pscustomobject]@{ health = [pscustomobject]@{ powerShell = $health } } } | ConvertTo-Json -Depth 12
            $json | Should Match '5.6.1'
            ($json.Contains('C:\\Modules\\Pester\\3.4.0')) | Should Be $true
        }
    }

    It 'does not warn for one old Pester version without compatibility evidence' {
        InModuleScope DevRigInspector {
            $health = [pscustomobject]@{
                windowsPowerShell = [pscustomobject]@{ present = $false }
                powerShell7 = [pscustomobject]@{ commandCandidates = @(); selectedCommand = $null }
                effectiveExecutionPolicy = $null
                executionPolicies = @()
                psModulePath = @()
                pester = @([pscustomobject]@{ version = '3.4.0'; path = 'C:\Modules\Pester\3.4.0' })
            }

            @(Get-PowerShellHealthDiagnostics -PowerShellHealth $health) |
                Where-Object { $_.code -eq 'PesterVersionCompatibility' -and $_.severity -eq 'Warning' } | Should BeNullOrEmpty
        }
    }
}