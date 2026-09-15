$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

Describe 'Get-DevelopmentToolInventory' {
    It 'records the selected command and shadowing candidates' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand {
                [pscustomobject]@{
                    selected = [pscustomobject]@{ path = 'C:\first\git.exe'; source = 'Path' }
                    candidates = @(
                        [pscustomobject]@{ path = 'C:\first\git.exe'; source = 'Path' }
                        [pscustomobject]@{ path = 'C:\second\git.exe'; source = 'Path' }
                    )
                }
            }
            Mock Invoke-ExternalCommand {
                [pscustomobject]@{
                    arguments = @('--version')
                    exitCode = 0
                    standardOutput = 'git version 2.50.0'
                    standardError = ''
                    timedOut = $false
                    durationMilliseconds = 1
                }
            }

            $result = Get-DevelopmentToolInventory
            $result.status | Should Be 'Available'
            $result.data[0].selectedCommand.path | Should Be 'C:\first\git.exe'
            $result.data[0].allCommandCandidates.Count | Should Be 2
            $result.data[0].diagnostics[0].code | Should Be 'PathShadowing'
        }
    }

    It 'represents an absent command without throwing' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand {
                [pscustomobject]@{ selected = $null; candidates = @() }
            }
            $result = Get-DevelopmentToolInventory
            $result.data[0].status | Should Be 'Missing'
            $result.data[0].error | Should Be $null
        }
    }
}