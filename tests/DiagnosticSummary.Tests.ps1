$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

function global:New-SummaryTestFinding {
    param(
        [string] $Code,
        [ValidateSet('Info', 'Warning', 'Error')] [string] $Severity = 'Warning',
        [string] $Category = 'Path',
        [string] $AffectedComponent = 'PATH',
        [string] $Title = 'Finding',
        [string] $Message = 'A finding occurred.',
        [string] $Recommendation = 'No action required.',
        [string] $NormalizedPath
    )
    $evidence = if ($NormalizedPath) { @([pscustomobject]@{ raw = $NormalizedPath; expanded = $NormalizedPath; normalized = $NormalizedPath }) } else { @() }
    [pscustomobject]@{
        code = $Code
        severity = $Severity
        category = $Category
        title = $Title
        message = $Message
        affectedComponent = $AffectedComponent
        evidence = $evidence
        recommendation = $Recommendation
    }
}

Describe 'New-DiagnosticSummary' {
    Context 'Status semantics' {
        It 'reports Healthy for zero errors and zero warnings' {
            InModuleScope DevRigInspector {
                $findings = @((New-SummaryTestFinding -Severity 'Info'))
                (New-DiagnosticSummary -Findings $findings).status | Should Be 'Healthy'
            }
        }

        It 'reports Attention for zero errors and at least one warning' {
            InModuleScope DevRigInspector {
                $findings = @((New-SummaryTestFinding -Severity 'Warning'), (New-SummaryTestFinding -Severity 'Info'))
                (New-DiagnosticSummary -Findings $findings).status | Should Be 'Attention'
            }
        }

        It 'reports Problems when at least one error is present' {
            InModuleScope DevRigInspector {
                $findings = @((New-SummaryTestFinding -Severity 'Error'), (New-SummaryTestFinding -Severity 'Warning'))
                (New-DiagnosticSummary -Findings $findings).status | Should Be 'Problems'
            }
        }

        It 'reports Healthy for info-only findings regardless of count' {
            InModuleScope DevRigInspector {
                $findings = @(1..5 | ForEach-Object { New-SummaryTestFinding -Severity 'Info' -Code "Info$_" })
                (New-DiagnosticSummary -Findings $findings).status | Should Be 'Healthy'
            }
        }
    }

    Context 'Counts' {
        It 'reports exact error, warning, and info counts matching the source findings' {
            InModuleScope DevRigInspector {
                $findings = @(
                    (New-SummaryTestFinding -Severity 'Error' -Code 'E1')
                    (New-SummaryTestFinding -Severity 'Error' -Code 'E2')
                    (New-SummaryTestFinding -Severity 'Warning' -Code 'W1')
                    (New-SummaryTestFinding -Severity 'Warning' -Code 'W2')
                    (New-SummaryTestFinding -Severity 'Warning' -Code 'W3')
                    (New-SummaryTestFinding -Severity 'Info' -Code 'I1')
                )
                $summary = New-DiagnosticSummary -Findings $findings
                $summary.errorCount | Should Be (@($findings | Where-Object severity -eq 'Error')).Count
                $summary.warningCount | Should Be (@($findings | Where-Object severity -eq 'Warning')).Count
                $summary.infoCount | Should Be (@($findings | Where-Object severity -eq 'Info')).Count
                $summary.errorCount | Should Be 2
                $summary.warningCount | Should Be 3
                $summary.infoCount | Should Be 1
            }
        }
    }

    Context 'Attention list' {
        It 'contains only Error and Warning findings' {
            InModuleScope DevRigInspector {
                $findings = @(
                    (New-SummaryTestFinding -Severity 'Error' -Code 'E1')
                    (New-SummaryTestFinding -Severity 'Warning' -Code 'W1')
                    (New-SummaryTestFinding -Severity 'Info' -Code 'I1')
                )
                $summary = New-DiagnosticSummary -Findings $findings
                $summary.attention.Count | Should Be 2
                @($summary.attention | Where-Object severity -eq 'Info').Count | Should Be 0
            }
        }

        It 'orders Errors before Warnings' {
            InModuleScope DevRigInspector {
                $findings = @(
                    (New-SummaryTestFinding -Severity 'Warning' -Code 'W1')
                    (New-SummaryTestFinding -Severity 'Error' -Code 'E1')
                )
                $summary = New-DiagnosticSummary -Findings $findings
                $summary.attention[0].severity | Should Be 'Error'
                $summary.attention[1].severity | Should Be 'Warning'
            }
        }

        It 'produces identical ordering regardless of source-array order' {
            InModuleScope DevRigInspector {
                $a = New-SummaryTestFinding -Severity 'Error' -Code 'Alpha' -AffectedComponent 'Comp1'
                $b = New-SummaryTestFinding -Severity 'Warning' -Code 'Bravo' -AffectedComponent 'Comp2'
                $c = New-SummaryTestFinding -Severity 'Warning' -Code 'Charlie' -AffectedComponent 'Comp3'
                $d = New-SummaryTestFinding -Severity 'Error' -Code 'Delta' -AffectedComponent 'Comp4'

                $summary1 = New-DiagnosticSummary -Findings @($a, $b, $c, $d)
                $summary2 = New-DiagnosticSummary -Findings @($d, $c, $b, $a)
                $summary3 = New-DiagnosticSummary -Findings @($c, $a, $d, $b)

                $json1 = $summary1.attention | ConvertTo-Json -Depth 5
                $json2 = $summary2.attention | ConvertTo-Json -Depth 5
                $json3 = $summary3.attention | ConvertTo-Json -Depth 5

                $json2 | Should Be $json1
                $json3 | Should Be $json1
            }
        }

        It 'produces identical ordering for two same-code PATH findings differing only by target, regardless of source order' {
            InModuleScope DevRigInspector {
                $first = New-SummaryTestFinding -Severity 'Warning' -Code 'PathEntryMissing' -AffectedComponent 'PATH' -NormalizedPath 'C:\First\Missing'
                $second = New-SummaryTestFinding -Severity 'Warning' -Code 'PathEntryMissing' -AffectedComponent 'PATH' -NormalizedPath 'C:\Second\Missing'

                $summaryA = New-DiagnosticSummary -Findings @($first, $second)
                $summaryB = New-DiagnosticSummary -Findings @($second, $first)

                ($summaryA.attention | ConvertTo-Json -Depth 5) | Should Be ($summaryB.attention | ConvertTo-Json -Depth 5)
                $summaryA.attention.Count | Should Be 2
            }
        }

        It 'contains only concise summary fields without duplicating evidence arrays' {
            InModuleScope DevRigInspector {
                $finding = New-SummaryTestFinding -Severity 'Warning' -Code 'PathEntryMissing' -NormalizedPath 'C:\Some\Path'
                $summary = New-DiagnosticSummary -Findings @($finding)
                $item = $summary.attention[0]
                $properties = @($item.PSObject.Properties.Name | Sort-Object)
                ($properties -join ',') | Should Be 'affectedComponent,category,code,identity,severity,title'
                ($properties -contains 'evidence') | Should Be $false
                ($properties -contains 'message') | Should Be $false
                ($properties -contains 'recommendation') | Should Be $false
            }
        }
    }

    Context 'Affected subsystems' {
        It 'derives affected subsystems only from non-Info findings' {
            InModuleScope DevRigInspector {
                $findings = @(
                    (New-SummaryTestFinding -Severity 'Warning' -Category 'Path')
                    (New-SummaryTestFinding -Severity 'Info' -Category 'Virtualization')
                )
                $summary = New-DiagnosticSummary -Findings $findings
                $summary.affectedSubsystems | Should Be @('Path')
            }
        }

        It 'deduplicates affected subsystems' {
            InModuleScope DevRigInspector {
                $findings = @(
                    (New-SummaryTestFinding -Severity 'Warning' -Category 'Path' -Code 'W1')
                    (New-SummaryTestFinding -Severity 'Error' -Category 'Path' -Code 'W2')
                    (New-SummaryTestFinding -Severity 'Warning' -Category 'Node' -Code 'W3')
                )
                $summary = New-DiagnosticSummary -Findings $findings
                @($summary.affectedSubsystems).Count | Should Be 2
            }
        }

        It 'orders affected subsystems deterministically regardless of source order' {
            InModuleScope DevRigInspector {
                $findings1 = @(
                    (New-SummaryTestFinding -Severity 'Warning' -Category 'Python' -Code 'W1')
                    (New-SummaryTestFinding -Severity 'Warning' -Category 'Git' -Code 'W2')
                    (New-SummaryTestFinding -Severity 'Warning' -Category 'Node' -Code 'W3')
                )
                $findings2 = @($findings1[2], $findings1[0], $findings1[1])

                $summary1 = New-DiagnosticSummary -Findings $findings1
                $summary2 = New-DiagnosticSummary -Findings $findings2

                ($summary1.affectedSubsystems -join ',') | Should Be ($summary2.affectedSubsystems -join ',')
                $summary1.affectedSubsystems | Should Be @('Git', 'Node', 'Python')
            }
        }
    }
}

Describe 'Summary renderer integration' {
    It 'console renders the Dev Rig Inspector overview using diagnostics.summary' {
        InModuleScope DevRigInspector {
            Mock Write-Host {}
            $inventory = [pscustomobject]@{
                computer = [pscustomobject]@{ hostname = 'test'; windows = [pscustomobject]@{ productName = 'Windows'; buildNumber = '1' }; cpu = [pscustomobject]@{ name = 'CPU'; logicalProcessors = 1 }; physicalMemoryBytes = 1GB; logicalVolumes = @() }
                tools = @()
                diagnostics = [pscustomobject]@{
                    findings = @((New-SummaryTestFinding -Severity 'Warning' -Title 'Something needs attention'))
                    health = [pscustomobject]@{}
                    summary = $null
                }
            }
            $inventory.diagnostics.summary = New-DiagnosticSummary -Findings $inventory.diagnostics.findings

            Write-InventoryConsole -Inventory $inventory
            Assert-MockCalled Write-Host -Times 1 -Scope It -ParameterFilter { $Object -eq 'Overall: Attention' }
            Assert-MockCalled Write-Host -Times 1 -Scope It -ParameterFilter { $Object -eq 'ATTENTION' }
        }
    }

    It 'console omits the ATTENTION block when the summary is Healthy' {
        InModuleScope DevRigInspector {
            Mock Write-Host {}
            $inventory = [pscustomobject]@{
                computer = [pscustomobject]@{ hostname = 'test'; windows = [pscustomobject]@{ productName = 'Windows'; buildNumber = '1' }; cpu = [pscustomobject]@{ name = 'CPU'; logicalProcessors = 1 }; physicalMemoryBytes = 1GB; logicalVolumes = @() }
                tools = @()
                diagnostics = [pscustomobject]@{
                    findings = @((New-SummaryTestFinding -Severity 'Info'))
                    health = [pscustomobject]@{}
                    summary = $null
                }
            }
            $inventory.diagnostics.summary = New-DiagnosticSummary -Findings $inventory.diagnostics.findings

            Write-InventoryConsole -Inventory $inventory
            Assert-MockCalled Write-Host -Times 1 -Scope It -ParameterFilter { $Object -eq 'Overall: Healthy' }
            Assert-MockCalled Write-Host -Times 0 -Scope It -ParameterFilter { $Object -eq 'ATTENTION' }
        }
    }

    It 'Markdown renders counts and attention content sourced from diagnostics.summary' {
        InModuleScope DevRigInspector {
            $inventory = [pscustomobject]@{
                schemaVersion = '0.1'
                collectorVersion = '0.4.0'
                collectedAt = '2026-09-16T08:30:00Z'
                computer = [pscustomobject]@{ hostname = 'MD-TEST'; windows = [pscustomobject]@{ productName = 'Windows 11 Pro'; buildNumber = '26200' }; cpu = [pscustomobject]@{ name = 'CPU' }; physicalMemoryBytes = 1GB }
                tools = @()
                diagnostics = [pscustomobject]@{
                    collectorResults = @()
                    findings = @((New-SummaryTestFinding -Severity 'Warning' -Title 'Needs attention' -Message 'Detailed message body.' -Recommendation 'Do the thing.'))
                    health = [pscustomobject]@{}
                    summary = $null
                }
            }
            $inventory.diagnostics.summary = New-DiagnosticSummary -Findings $inventory.diagnostics.findings

            $markdown = ConvertTo-InventoryMarkdown -Inventory $inventory
            $markdown | Should Match '- Errors: 0'
            $markdown | Should Match '- Warnings: 1'
            $markdown | Should Match '- Informational findings: 0'
            $markdown | Should Match '## Attention Required'
            $markdown | Should Match 'Needs attention'
            $markdown | Should Match 'Detailed message body\.'
            $markdown | Should Match 'Do the thing\.'
        }
    }

    It 'Markdown omits Attention Required when the summary is Healthy' {
        InModuleScope DevRigInspector {
            $inventory = [pscustomobject]@{
                schemaVersion = '0.1'
                collectorVersion = '0.4.0'
                collectedAt = '2026-09-16T08:30:00Z'
                computer = [pscustomobject]@{ hostname = 'MD-TEST'; windows = [pscustomobject]@{ productName = 'Windows 11 Pro'; buildNumber = '26200' }; cpu = [pscustomobject]@{ name = 'CPU' }; physicalMemoryBytes = 1GB }
                tools = @()
                diagnostics = [pscustomobject]@{
                    collectorResults = @()
                    findings = @((New-SummaryTestFinding -Severity 'Info'))
                    health = [pscustomobject]@{}
                    summary = $null
                }
            }
            $inventory.diagnostics.summary = New-DiagnosticSummary -Findings $inventory.diagnostics.findings

            $markdown = ConvertTo-InventoryMarkdown -Inventory $inventory
            $markdown | Should Not Match '## Attention Required'
            $markdown | Should Match '## Informational Findings'
        }
    }
}

Describe 'Summary is excluded from comparison' {
    function global:New-SummaryComparisonTestInventory {
        param(
            [string] $Hostname = 'SUMMARY-COMPARE-HOST',
            [object[]] $Tools = @(),
            [object[]] $Findings = @()
        )
        [pscustomobject]@{
            schemaVersion = '0.1'
            collectorVersion = '0.4.0'
            collectedAt = [DateTime]::UtcNow.ToString('o')
            computer = [pscustomobject]@{ hostname = $Hostname; cpu = [pscustomobject]@{ name = 'Test CPU' }; physicalMemoryBytes = 34359738368 }
            tools = @($Tools)
            diagnostics = [pscustomobject]@{
                collectorResults = @()
                findings = @($Findings)
                health = [pscustomobject]@{}
            }
        }
    }

    It 'is not part of comparable inventory state' {
        InModuleScope DevRigInspector {
            $inventory = New-SummaryComparisonTestInventory -Findings @((New-SummaryTestFinding -Severity 'Warning'))
            $comparable = ConvertTo-ComparableInventory -Inventory $inventory -Path 'test.json'
            ($comparable.PSObject.Properties.Name -contains 'summary') | Should Be $false
        }
    }

    It 'produces zero changes when only the summary object differs between snapshots' {
        $reference = New-SummaryComparisonTestInventory -Findings @((New-SummaryTestFinding -Severity 'Warning' -Code 'W1'))
        $current = New-SummaryComparisonTestInventory -Findings @((New-SummaryTestFinding -Severity 'Warning' -Code 'W1'))
        $reference | Add-Member -NotePropertyName summary -NotePropertyValue ([pscustomobject]@{ status = 'Healthy'; errorCount = 0; warningCount = 0; infoCount = 0; affectedSubsystems = @(); attention = @() }) -Force
        $current | Add-Member -NotePropertyName summary -NotePropertyValue ([pscustomobject]@{ status = 'Problems'; errorCount = 99; warningCount = 99; infoCount = 99; affectedSubsystems = @('Bogus'); attention = @(@{ fake = 'entry' }) }) -Force

        $result = Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null
        $result.summary.totalChanges | Should Be 0
    }

    It 'still reports authoritative finding drift even when a bogus summary is also present' {
        $reference = New-SummaryComparisonTestInventory -Findings @()
        $current = New-SummaryComparisonTestInventory -Findings @((New-SummaryTestFinding -Severity 'Warning' -Code 'NewOne' -AffectedComponent 'PATH'))
        $reference | Add-Member -NotePropertyName summary -NotePropertyValue ([pscustomobject]@{ status = 'Healthy'; errorCount = 0; warningCount = 0; infoCount = 0; affectedSubsystems = @(); attention = @() }) -Force
        $current | Add-Member -NotePropertyName summary -NotePropertyValue ([pscustomobject]@{ status = 'Healthy'; errorCount = 0; warningCount = 0; infoCount = 0; affectedSubsystems = @(); attention = @() }) -Force

        $result = Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null
        $result.summary.newFindings | Should Be 1
    }
}
