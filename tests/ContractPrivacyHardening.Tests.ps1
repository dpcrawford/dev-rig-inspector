$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

function global:New-ContractTestInventory {
    param(
        [string] $SchemaVersion = '0.2',
        [object[]] $Tools = @(),
        [object[]] $Findings = @(),
        [string] $Hostname = 'CONTRACT-HOST'
    )
    [pscustomobject]@{
        schemaVersion = $SchemaVersion
        collectorVersion = '0.5.0'
        collectedAt = '2026-01-01T00:00:00Z'
        computer = [pscustomobject]@{ hostname = $Hostname; cpu = [pscustomobject]@{ name = 'Test CPU' }; physicalMemoryBytes = 34359738368 }
        tools = @($Tools)
        diagnostics = [pscustomobject]@{ collectorResults = @(); findings = @($Findings); health = [pscustomobject]@{} }
    }
}

function global:New-ContractTestTool {
    param(
        [string] $Id,
        [string] $DisplayName = $Id,
        [string] $Version = '1.0.0',
        [string] $Status = 'Available',
        [switch] $IncludeLegacyRawFields
    )
    $tool = [pscustomobject]@{ id = $Id; displayName = $DisplayName; status = $Status; version = $Version }
    if ($IncludeLegacyRawFields) {
        # Simulates a pre-Slice-3 (schemaVersion 0.1) inventory that still carries the raw probe object.
        $tool | Add-Member -NotePropertyName rawVersion -NotePropertyValue "$DisplayName $Version (raw)"
        $tool | Add-Member -NotePropertyName command -NotePropertyValue ([pscustomobject]@{
            arguments = @('--version')
            exitCode = 0
            standardOutput = "$DisplayName $Version"
            standardError = ''
            timedOut = $false
            durationMilliseconds = 3
        })
    }
    $tool
}

Describe 'Development tool inventory privacy contract' {
    It 'does not serialize raw stdout, stderr, or secret-like probe output for tools' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand {
                [pscustomobject]@{
                    selected = [pscustomobject]@{ path = 'C:\Tools\secrettool.exe'; source = 'Path' }
                    candidates = @([pscustomobject]@{ path = 'C:\Tools\secrettool.exe'; source = 'Path' })
                }
            }
            Mock Invoke-ExternalCommand {
                [pscustomobject]@{
                    arguments = @('--version')
                    exitCode = 0
                    standardOutput = "SecretTool 9.9.9`nAuthorization: Bearer ghp_FAKE_SECRET_SHOULD_NOT_SERIALIZE"
                    standardError = 'npm_FAKE_SECRET_SHOULD_NOT_SERIALIZE password=FAKE stderr-secret-value'
                    timedOut = $false
                    durationMilliseconds = 5
                }
            }

            $result = Get-DevelopmentToolInventory
            $json = $result.data | ConvertTo-Json -Depth 10

            $json | Should Not Match 'ghp_FAKE_SECRET_SHOULD_NOT_SERIALIZE'
            $json | Should Not Match 'npm_FAKE_SECRET_SHOULD_NOT_SERIALIZE'
            $json | Should Not Match 'Authorization: Bearer'
            $json | Should Not Match 'password=FAKE'
            $json | Should Not Match 'stderr-secret-value'
            $json | Should Not Match 'SecretTool 9\.9\.9'

            $tool = $result.data[0]
            ($tool.PSObject.Properties.Name -contains 'command') | Should Be $false
            ($tool.PSObject.Properties.Name -contains 'rawVersion') | Should Be $false
        }
    }

    It 'retains required version, status, and selected-path fields' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand {
                [pscustomobject]@{
                    selected = [pscustomobject]@{ path = 'C:\Tools\git.exe'; source = 'Path' }
                    candidates = @([pscustomobject]@{ path = 'C:\Tools\git.exe'; source = 'Path' })
                }
            }
            Mock Invoke-ExternalCommand {
                [pscustomobject]@{ arguments = @('--version'); exitCode = 0; standardOutput = 'git version 2.55.0'; standardError = ''; timedOut = $false; durationMilliseconds = 3 }
            }

            $result = Get-DevelopmentToolInventory
            $tool = $result.data[0]
            $tool.version | Should Be '2.55.0'
            $tool.status | Should Be 'Available'
            $tool.selectedCommand.path | Should Be 'C:\Tools\git.exe'
        }
    }
}

Describe 'Inventory schema version support' {
    It 'rejects present but malformed tools and diagnostics on either side' {
        foreach ($field in @('tools', 'diagnostics')) {
            $cases = @(
                @{ value = $null }, @{ value = 'invalid' }, @{ value = [pscustomobject]@{} }
            )
            if ($field -eq 'tools') {
                $cases += @{ value = @(42) }, @{ value = @([pscustomobject]@{ id = 'git' }) }
            } else {
                $cases += @{ value = @() }, @{ value = [pscustomobject]@{ findings = 'invalid' } }
            }
            foreach ($case in $cases) {
                $valid = New-ContractTestInventory
                $invalid = New-ContractTestInventory
                $invalid.$field = $case.value
                $rejected = $false
                try { Compare-DevRigInspection -Reference $valid -Current $invalid -JsonOnly | Out-Null } catch { $rejected = $true }
                if (-not $rejected) { throw "Accepted malformed $field : $($case | ConvertTo-Json -Compress -Depth 5)" }
                $rejected = $false
                try { Compare-DevRigInspection -Reference $invalid -Current $valid -JsonOnly | Out-Null } catch { $rejected = $true }
                if (-not $rejected) { throw "Accepted malformed reference $field : $($case | ConvertTo-Json -Compress -Depth 5)" }
            }
        }
    }

    It 'accepts historical schemaVersion 0.1' {
        $reference = New-ContractTestInventory -SchemaVersion '0.1' -Tools @((New-ContractTestTool -Id 'git' -Version '2.55.0'))
        $current = New-ContractTestInventory -SchemaVersion '0.1' -Tools @((New-ContractTestTool -Id 'git' -Version '2.55.0'))
        { Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null } | Should Not Throw
    }

    It 'accepts the current schemaVersion 0.2' {
        $reference = New-ContractTestInventory -SchemaVersion '0.2' -Tools @((New-ContractTestTool -Id 'git' -Version '2.55.0'))
        $current = New-ContractTestInventory -SchemaVersion '0.2' -Tools @((New-ContractTestTool -Id 'git' -Version '2.55.0'))
        { Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null } | Should Not Throw
    }

    It 'rejects an unsupported future schema version' {
        $reference = New-ContractTestInventory -SchemaVersion '0.2'
        $current = New-ContractTestInventory -SchemaVersion '9.9'
        $threw = $false
        try { Compare-DevRigInspection -Reference $reference -Current $current 6>$null } catch { $threw = $true }
        $threw | Should Be $true
    }

    It 'rejects an inventory missing schemaVersion' {
        $reference = New-ContractTestInventory -SchemaVersion '0.2'
        $current = New-ContractTestInventory -SchemaVersion '0.2'
        $current.PSObject.Properties.Remove('schemaVersion')
        $threw = $false
        try { Compare-DevRigInspection -Reference $reference -Current $current 6>$null } catch { $threw = $true }
        $threw | Should Be $true
    }

    It 'rejects an inventory with a malformed tools structure' {
        $reference = New-ContractTestInventory -SchemaVersion '0.2'
        $current = New-ContractTestInventory -SchemaVersion '0.2'
        $current.PSObject.Properties.Remove('tools')
        $threw = $false
        try { Compare-DevRigInspection -Reference $reference -Current $current 6>$null } catch { $threw = $true }
        $threw | Should Be $true
    }

    It 'rejects an inventory with a malformed diagnostics structure' {
        $reference = New-ContractTestInventory -SchemaVersion '0.2'
        $current = New-ContractTestInventory -SchemaVersion '0.2'
        $current.PSObject.Properties.Remove('diagnostics')
        $threw = $false
        try { Compare-DevRigInspection -Reference $reference -Current $current 6>$null } catch { $threw = $true }
        $threw | Should Be $true
    }
}

Describe 'Cross-version inventory comparison' {
    It 'has zero equivalent changes for every supported schema pair' {
        foreach ($before in @('0.1', '0.2')) {
            foreach ($after in @('0.1', '0.2')) {
                $reference = New-ContractTestInventory -SchemaVersion $before -Tools @((New-ContractTestTool -Id git -IncludeLegacyRawFields:($before -eq '0.1')))
                $current = New-ContractTestInventory -SchemaVersion $after -Tools @((New-ContractTestTool -Id git -IncludeLegacyRawFields:($after -eq '0.1')))
                $result = Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null
                $result.summary.totalChanges | Should Be 0
                $result.comparisonSchemaVersion | Should Be '0.1'
            }
        }
    }

    It 'produces no false tool drift comparing a legacy 0.1 inventory to an equivalent current 0.2 inventory' {
        $reference = New-ContractTestInventory -SchemaVersion '0.1' -Tools @((New-ContractTestTool -Id 'git' -Version '2.55.0' -IncludeLegacyRawFields))
        $current = New-ContractTestInventory -SchemaVersion '0.2' -Tools @((New-ContractTestTool -Id 'git' -Version '2.55.0'))
        $result = Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null
        $result.summary.toolsChanged | Should Be 0
        $result.summary.totalChanges | Should Be 0
    }

    It 'produces no false tool drift comparing a current 0.2 inventory to an equivalent legacy 0.1 inventory' {
        $reference = New-ContractTestInventory -SchemaVersion '0.2' -Tools @((New-ContractTestTool -Id 'git' -Version '2.55.0'))
        $current = New-ContractTestInventory -SchemaVersion '0.1' -Tools @((New-ContractTestTool -Id 'git' -Version '2.55.0' -IncludeLegacyRawFields))
        $result = Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null
        $result.summary.totalChanges | Should Be 0
    }

    It 'still detects a genuine version change across schema versions' {
        $reference = New-ContractTestInventory -SchemaVersion '0.1' -Tools @((New-ContractTestTool -Id 'git' -Version '2.55.0' -IncludeLegacyRawFields))
        $current = New-ContractTestInventory -SchemaVersion '0.2' -Tools @((New-ContractTestTool -Id 'git' -Version '2.56.1'))
        $result = Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null
        $result.summary.toolsChanged | Should Be 1
        $result.summary.totalChanges | Should Be 1
        $change = $result.changes.tools | Where-Object id -eq 'git'
        $change.fields.field | Should Be 'version'
        $change.fields.before | Should Be '2.55.0'
        $change.fields.after | Should Be '2.56.1'
    }

    It 'does not generate drift from the legacy command field alone when nothing else differs' {
        $reference = New-ContractTestInventory -SchemaVersion '0.1' -Tools @((New-ContractTestTool -Id 'node' -Version '24.19.0'))
        $current = New-ContractTestInventory -SchemaVersion '0.1' -Tools @((New-ContractTestTool -Id 'node' -Version '24.19.0' -IncludeLegacyRawFields))
        $result = Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null
        $result.summary.totalChanges | Should Be 0
    }

    It 'does not include raw legacy tool evidence in the comparison JSON output' {
        $reference = New-ContractTestInventory -SchemaVersion '0.1' -Tools @((New-ContractTestTool -Id 'git' -Version '2.55.0' -IncludeLegacyRawFields))
        $current = New-ContractTestInventory -SchemaVersion '0.2' -Tools @((New-ContractTestTool -Id 'git' -Version '2.56.1'))
        $json = Compare-DevRigInspection -Reference $reference -Current $current -JsonOnly 6>$null
        $json | Should Not Match 'standardOutput'
        $json | Should Not Match 'standardError'
        $json | Should Not Match '"command"\s*:\s*\{'
    }
}

Describe 'Renderer privacy regression' {
    It 'excludes synthetic secrets from inventory, Markdown, and comparison for all probe outcomes' {
        InModuleScope DevRigInspector {
            Mock Resolve-ToolCommand {
                [pscustomobject]@{ selected = [pscustomobject]@{ path = 'C:\Tools\probe.exe' }; candidates = @([pscustomobject]@{ path = 'C:\Tools\probe.exe' }) }
            }
            $script:privacySecrets = 'ghp_FAKE_SECRET_SHOULD_NOT_SERIALIZE npm_FAKE_SECRET_SHOULD_NOT_SERIALIZE Authorization: Bearer FAKE password=FAKE stderr-secret-value'
            Mock Invoke-ExternalCommand {
                if ($script:privacyOutcome -eq 'Throw') { throw $script:privacySecrets }
                [pscustomobject]@{
                    standardOutput = $(if ($script:privacyOutcome -eq 'Version') { 'Probe 9.9.9 ' }) + $script:privacySecrets
                    standardError = $script:privacySecrets
                    exitCode = $(if ($script:privacyOutcome -eq 'Error') { 1 } else { 0 })
                    timedOut = $script:privacyOutcome -eq 'TimedOut'
                }
            }
            foreach ($outcome in @('Version', 'Unrecognized', 'Error', 'TimedOut', 'Throw')) {
                $script:privacyOutcome = $outcome
                $collector = Get-DevelopmentToolInventory
                $inventory = New-ContractTestInventory -Tools $collector.data
                $inventory.diagnostics.collectorResults = @($collector)
                $inventory.diagnostics | Add-Member -NotePropertyName summary -NotePropertyValue (New-DiagnosticSummary -Findings @())
                $legacy = New-ContractTestInventory -SchemaVersion '0.1' -Tools @((New-ContractTestTool -Id git -IncludeLegacyRawFields))
                $legacy.tools[0].command.standardOutput = $script:privacySecrets
                $legacy.tools[0].command.standardError = $script:privacySecrets
                $legacy.tools[0].rawVersion = $script:privacySecrets
                $outputs = @(
                    (ConvertTo-InventoryJson -Inventory $inventory)
                    (ConvertTo-InventoryMarkdown -Inventory $inventory)
                    (Compare-DevRigInspection -Reference $legacy -Current $inventory -JsonOnly)
                )
                foreach ($output in $outputs) {
                    foreach ($secret in @('ghp_FAKE_SECRET_SHOULD_NOT_SERIALIZE', 'npm_FAKE_SECRET_SHOULD_NOT_SERIALIZE', 'Authorization: Bearer FAKE', 'password=FAKE', 'stderr-secret-value')) {
                        $output | Should Not Match ([regex]::Escape($secret))
                    }
                }
                foreach ($tool in $collector.data) {
                    if ($outcome -eq 'Version') { $tool.version | Should Be '9.9.9' }
                    else { $null -eq $tool.version | Should Be $true }
                    if ($outcome -in @('Error', 'Throw')) { $tool.status | Should Be 'Error' }
                    elseif ($outcome -eq 'TimedOut') { $tool.status | Should Be 'TimedOut' }
                    else { $tool.status | Should Be 'Available' }
                }
            }
        }
    }

    It 'console output does not include raw tool probe evidence' {
        InModuleScope DevRigInspector {
            Mock Write-Host {}
            $tool = [pscustomobject]@{
                id = 'git'; displayName = 'Git'; status = 'Available'; version = '2.55.0'
                selectedCommand = [pscustomobject]@{ path = 'C:\Tools\git.exe' }
                allCommandCandidates = @()
                diagnostics = @()
                error = $null
            }
            $tool | Add-Member -NotePropertyName command -NotePropertyValue ([pscustomobject]@{ standardOutput = 'SECRET_SHOULD_NOT_RENDER'; standardError = ''; exitCode = 0 })

            $inventory = [pscustomobject]@{
                computer = [pscustomobject]@{ hostname = 'test'; windows = [pscustomobject]@{ productName = 'Windows'; buildNumber = '1' }; cpu = [pscustomobject]@{ name = 'CPU'; logicalProcessors = 1 }; physicalMemoryBytes = 1GB; logicalVolumes = @() }
                tools = @($tool)
                diagnostics = [pscustomobject]@{ findings = @(); summary = $null }
            }
            $inventory.diagnostics.summary = New-DiagnosticSummary -Findings @()

            Write-InventoryConsole -Inventory $inventory
            Assert-MockCalled Write-Host -Scope It -Times 0 -ParameterFilter { $Object -like '*SECRET_SHOULD_NOT_RENDER*' }
        }
    }

    It 'Markdown output does not include raw tool probe evidence' {
        InModuleScope DevRigInspector {
            $tool = [pscustomobject]@{ id = 'git'; displayName = 'Git'; status = 'Available'; version = '2.55.0' }
            $tool | Add-Member -NotePropertyName command -NotePropertyValue ([pscustomobject]@{ standardOutput = 'SECRET_SHOULD_NOT_RENDER_MD'; standardError = ''; exitCode = 0 })

            $inventory = [pscustomobject]@{
                schemaVersion = '0.2'
                collectorVersion = '0.5.0'
                collectedAt = (Get-Date).ToString('o')
                computer = [pscustomobject]@{ hostname = 'test'; windows = [pscustomobject]@{ productName = 'Windows'; buildNumber = '1' }; cpu = [pscustomobject]@{ name = 'CPU' }; physicalMemoryBytes = 1GB }
                tools = @($tool)
                diagnostics = [pscustomobject]@{ collectorResults = @(); findings = @(); health = [pscustomobject]@{}; summary = $null }
            }
            $inventory.diagnostics.summary = New-DiagnosticSummary -Findings @()

            $markdown = ConvertTo-InventoryMarkdown -Inventory $inventory
            $markdown | Should Not Match 'SECRET_SHOULD_NOT_RENDER_MD'
            $markdown | Should Match '2\.55\.0'
        }
    }
}
