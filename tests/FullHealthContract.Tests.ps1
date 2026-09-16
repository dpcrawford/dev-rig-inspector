$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

Describe 'Full v0.3 health contract' {
    It 'contains all additive health sections without depending on workstation state' {
        InModuleScope DevRigInspector {
            Mock Get-SystemInventory {
                New-CollectorResult -CollectorId 'System' -Status Available -Data ([pscustomobject]@{ hostname = 'test'; windows = [pscustomobject]@{}; cpu = [pscustomobject]@{}; logicalVolumes = @(); physicalMemoryBytes = 0 })
            }
            Mock Get-DevelopmentToolInventory { New-CollectorResult -CollectorId 'DevelopmentTools' -Status Available -Data @([pscustomobject]@{}) }
            Mock Get-InventoryDiagnostics { @() }
            Mock Get-PowerShellHealthDiagnostics { @() }
            Mock Get-GitHealthDiagnostics { @() }
            Mock Get-PythonHealthDiagnostics { @() }
            Mock Get-NodeHealthDiagnostics { @() }
            Mock Get-VirtualizationHealthDiagnostics { @() }
            Mock Get-PowerShellHealthInventory { New-CollectorResult -CollectorId 'PowerShellHealth' -Status Available -Data ([pscustomobject]@{}) }
            Mock Get-GitHealthInventory { New-CollectorResult -CollectorId 'GitHealth' -Status Available -Data ([pscustomobject]@{}) }
            Mock Get-PythonHealthInventory { New-CollectorResult -CollectorId 'PythonHealth' -Status Available -Data ([pscustomobject]@{}) }
            Mock Get-NodeHealthInventory { New-CollectorResult -CollectorId 'NodeHealth' -Status Available -Data ([pscustomobject]@{}) }
            Mock Get-VirtualizationHealthInventory { New-CollectorResult -CollectorId 'VirtualizationHealth' -Status Available -Data ([pscustomobject]@{}) }

            $inventory = Invoke-DevRigInspection -PassThru 6>$null
            $inventory.schemaVersion | Should Be '0.1'
            $inventory.collectorVersion | Should Be '0.4.0'
            $null -ne $inventory.computer | Should Be $true
            $null -ne $inventory.tools | Should Be $true
            $inventory.diagnostics.collectorResults.Count | Should Be 2
            $null -ne $inventory.diagnostics.findings | Should Be $true
            $null -ne $inventory.diagnostics.health.powerShell | Should Be $true
            $null -ne $inventory.diagnostics.health.git | Should Be $true
            $null -ne $inventory.diagnostics.health.python | Should Be $true
            $null -ne $inventory.diagnostics.health.node | Should Be $true
            $null -ne $inventory.diagnostics.health.virtualization | Should Be $true
        }
    }
}