$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

Describe 'Diagnostic findings' {
    It 'does not report npm launchers in one directory as command shadowing' {
        InModuleScope DevRigInspector {
            $tool = [pscustomobject]@{
                id = 'npm'
                displayName = 'npm'
                selectedCommand = [pscustomobject]@{ path = 'C:\Node\npm.cmd' }
                allCommandCandidates = @(
                    [pscustomobject]@{ path = 'C:\Node\npm' }
                    [pscustomobject]@{ path = 'C:\Node\npm.cmd' }
                    [pscustomobject]@{ path = 'C:\Node\npm.ps1' }
                )
            }

            @(Get-InventoryDiagnostics -Tools @($tool) -PathValue '') |
                Where-Object code -eq 'CommandShadowing' | Should BeNullOrEmpty
        }
    }

    It 'preserves same-install legacy shadowing in JSON but omits it from console output' {
        InModuleScope DevRigInspector {
            Mock Write-Host {}
            $tool = [pscustomobject]@{
                id = 'npm'
                displayName = 'npm'
                status = 'Available'
                version = '11.0.0'
                allCommandCandidates = @(
                    [pscustomobject]@{ path = 'C:\Node\npm' }
                    [pscustomobject]@{ path = 'C:\Node\npm.cmd' }
                    [pscustomobject]@{ path = 'C:\Node\npm.ps1' }
                )
                diagnostics = @(
                    [pscustomobject]@{
                        code = 'PathShadowing'
                        severity = 'Warning'
                        message = 'Multiple matching commands were found.'
                    }
                    [pscustomobject]@{
                        code = 'ToolNotice'
                        severity = 'Info'
                        message = 'This unrelated diagnostic remains visible.'
                    }
                )
            }

            $inventory = [pscustomobject]@{
                computer = [pscustomobject]@{
                    hostname = 'test'
                    windows = [pscustomobject]@{ productName = 'Windows'; buildNumber = '1' }
                    cpu = [pscustomobject]@{ name = 'CPU'; logicalProcessors = 1 }
                    physicalMemoryBytes = 1GB
                    logicalVolumes = @()
                }
                tools = @($tool)
                diagnostics = [pscustomobject]@{ findings = @() }
            }

            Write-InventoryConsole -Inventory $inventory
            Assert-MockCalled Write-Host -Times 0 -ParameterFilter { $Object -like '*Multiple matching commands were found.*' }
            Assert-MockCalled Write-Host -Times 1 -ParameterFilter { $Object -like '*This unrelated diagnostic remains visible.*' }
        }
    }

    It 'reports matching commands in two directories as command shadowing' {
        InModuleScope DevRigInspector {
            $tool = [pscustomobject]@{
                id = 'npm'
                displayName = 'npm'
                selectedCommand = [pscustomobject]@{ path = 'C:\First\npm.cmd' }
                allCommandCandidates = @(
                    [pscustomobject]@{ name = 'npm.cmd'; commandType = 'Application'; path = 'C:\First\npm.cmd'; source = 'C:\First\npm.cmd' }
                    [pscustomobject]@{ name = 'npm.cmd'; commandType = 'Application'; path = 'C:\Second\npm.cmd'; source = 'C:\Second\npm.cmd' }
                )
            }

            $finding = @(Get-InventoryDiagnostics -Tools @($tool) -PathValue '') |
                Where-Object code -eq 'CommandShadowing'
            $finding.Count | Should Be 1
            $finding.severity | Should Be 'Info'
            $finding.evidence.selectedWinner.path | Should Be 'C:\First\npm.cmd'
            $finding.evidence.competingCandidates.directory | Should Be 'C:\Second'
            $finding.evidence.candidates.order | Should Be @(1, 2)
            $finding.evidence.candidates.name | Should Be @('npm.cmd', 'npm.cmd')
            $finding.evidence.candidates.commandType | Should Be @('Application', 'Application')
            $finding.evidence.candidates.source | Should Be @('C:\First\npm.cmd', 'C:\Second\npm.cmd')
        }
    }

    It 'reports a WindowsApps alias winning over another location as a warning' {
        InModuleScope DevRigInspector {
            $tool = [pscustomobject]@{
                id = 'python'
                displayName = 'Python'
                selectedCommand = [pscustomobject]@{ path = 'C:\Users\test\AppData\Local\Microsoft\WindowsApps\python.exe' }
                allCommandCandidates = @(
                    [pscustomobject]@{ name = 'python.exe'; commandType = 'Application'; path = 'C:\Users\test\AppData\Local\Microsoft\WindowsApps\python.exe'; source = 'C:\Users\test\AppData\Local\Microsoft\WindowsApps\python.exe' }
                    [pscustomobject]@{ name = 'python.exe'; commandType = 'Application'; path = 'C:\Program Files\Python314\python.exe'; source = 'C:\Program Files\Python314\python.exe' }
                )
            }

            $finding = @(Get-InventoryDiagnostics -Tools @($tool) -PathValue '') |
                Where-Object code -eq 'CommandShadowing'
            $finding.severity | Should Be 'Warning'
            $finding.evidence.selectedWinner.order | Should Be 1
            $finding.evidence.competingCandidates.normalizedParentDirectory | Should Be 'C:\Program Files\Python314'
        }
    }

    It 'reports side-by-side versioned runtimes as informational' {
        InModuleScope DevRigInspector {
            $tools = @(
                [pscustomobject]@{
                    id = 'python'
                    displayName = 'Python'
                    selectedCommand = [pscustomobject]@{ path = 'C:\Program Files\Python314\python.exe' }
                    allCommandCandidates = @(
                        [pscustomobject]@{ path = 'C:\Program Files\Python314\python.exe' }
                        [pscustomobject]@{ path = 'C:\Program Files\Python313\python.exe' }
                        [pscustomobject]@{ path = 'C:\Program Files\Python312\python.exe' }
                    )
                }
                [pscustomobject]@{
                    id = 'dotnet'
                    displayName = '.NET'
                    selectedCommand = [pscustomobject]@{ path = 'C:\Program Files\dotnet\dotnet.exe' }
                    allCommandCandidates = @(
                        [pscustomobject]@{ path = 'C:\Program Files\dotnet\dotnet.exe' }
                        [pscustomobject]@{ path = 'C:\Program Files (x86)\dotnet\dotnet.exe' }
                    )
                }
            )

            $findings = @(Get-InventoryDiagnostics -Tools $tools -PathValue '') |
                Where-Object code -eq 'CommandShadowing'
            $findings.Count | Should Be 2
            @($findings.severity | Select-Object -Unique).Count | Should Be 1
            $findings.severity | Should Be @('Info', 'Info')
        }
    }

    It 'normalizes quoted and environment-variable PATH entries while preserving raw evidence' {
        InModuleScope DevRigInspector {
            $root = Join-Path $env:TEMP ('dev-rig-inspector-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $root | Out-Null
            $oldValue = $env:DRI_TEST_PATH
            try {
                $env:DRI_TEST_PATH = $root
                $findings = @(Get-PathDiagnostics -PathValue ('"%DRI_TEST_PATH%\";' + $root.ToUpperInvariant() + '\'))
                $duplicate = $findings | Where-Object code -eq 'PathEntryDuplicate'
                $duplicate.Count | Should Be 1
                (@($duplicate.evidence.raw) -contains '"%DRI_TEST_PATH%\"') | Should Be $true
                (@($duplicate.evidence.raw) -contains ($root.ToUpperInvariant() + '\')) | Should Be $true
                (@($duplicate.evidence.normalized)[0] -ieq @($duplicate.evidence.normalized)[1]) | Should Be $true
            } finally {
                if ($null -eq $oldValue) { Remove-Item Env:DRI_TEST_PATH -ErrorAction SilentlyContinue }
                else { $env:DRI_TEST_PATH = $oldValue }
                Remove-Item -LiteralPath $root -Recurse -Force
            }
        }
    }

    It 'detects trailing-slash and case-only duplicate PATH entries' {
        InModuleScope DevRigInspector {
            $root = Join-Path $env:TEMP ('dev-rig-inspector-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $root | Out-Null
            try {
                $findings = @(Get-PathDiagnostics -PathValue ($root + '\\;' + $root.ToUpperInvariant()))
                @($findings | Where-Object code -eq 'PathEntryDuplicate').Count | Should Be 1
            } finally {
                Remove-Item -LiteralPath $root -Recurse -Force
            }
        }
    }
}