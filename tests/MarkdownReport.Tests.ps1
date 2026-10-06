$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

function global:New-MarkdownTestFinding {
    param(
        [string] $Code,
        [ValidateSet('Info', 'Warning', 'Error')] [string] $Severity = 'Warning',
        [string] $Category = 'Path',
        [string] $AffectedComponent = 'PATH',
        [string] $Title = 'Finding',
        [string] $Message = 'A finding occurred.',
        [string] $Recommendation = 'No action required.',
        [object[]] $Evidence = @()
    )
    [pscustomobject]@{
        code = $Code
        severity = $Severity
        category = $Category
        title = $Title
        message = $Message
        affectedComponent = $AffectedComponent
        evidence = @($Evidence)
        recommendation = $Recommendation
    }
}

function global:New-MarkdownTestInventory {
    param(
        [string] $Hostname = 'MD-TEST-HOST',
        [object[]] $Tools,
        [object[]] $Findings,
        [string] $SecretLookingRawValue
    )

    if (-not $Tools) {
        $Tools = @(
            [pscustomobject]@{ id = 'git'; displayName = 'Git'; status = 'Available'; version = '2.55.0' }
            [pscustomobject]@{ id = 'pipetool'; displayName = 'PipeTool'; status = 'Available'; version = '1.0|beta' }
        )
    }
    if (-not $Findings) {
        $Findings = @(
            (New-MarkdownTestFinding -Code 'PathEntryMissing' -Severity 'Warning' -AffectedComponent 'PATH' -Title 'PATH entry does not exist' -Message 'The PATH entry does not point to an existing directory: C:\Users\Test\AppData\Roaming\npm' -Recommendation 'Remove or correct the stale entry after confirming it is no longer required.' -Evidence @([pscustomobject]@{ raw = 'C:\Users\Test\AppData\Roaming\npm'; expanded = 'C:\Users\Test\AppData\Roaming\npm'; normalized = 'C:\Users\Test\AppData\Roaming\npm'; secret = $SecretLookingRawValue }))
            (New-MarkdownTestFinding -Code 'GitIdentityConfigured' -Severity 'Info' -AffectedComponent 'Git.Identity' -Title 'Git identity configured' -Message 'Both global Git identity fields are explicitly configured.' -Recommendation 'No action is required.')
        )
    }

    [pscustomobject]@{
        schemaVersion = '0.1'
        collectorVersion = '0.4.0'
        collectedAt = '2026-09-16T08:30:00Z'
        computer = [pscustomobject]@{
            hostname = $Hostname
            windows = [pscustomobject]@{ productName = 'Windows 11 Pro'; buildNumber = '26200' }
            cpu = [pscustomobject]@{ name = 'Test CPU' }
            physicalMemoryBytes = 34359738368
        }
        tools = @($Tools)
        diagnostics = [pscustomobject]@{
            collectorResults = @()
            findings = @($Findings)
            health = [pscustomobject]@{
                powerShell = [pscustomobject]@{
                    active = [pscustomobject]@{ edition = 'Core'; version = '7.6.6' }
                    windowsPowerShell = [pscustomobject]@{ present = $true; version = '5.1.22621.1' }
                    effectiveExecutionPolicy = [pscustomobject]@{ scope = 'CurrentUser'; policy = 'RemoteSigned' }
                    pester = @([pscustomobject]@{ version = '3.4.0' })
                }
                git = [pscustomobject]@{
                    git = [pscustomobject]@{
                        version = 'git version 2.55.0.windows.3'
                        identity = [pscustomobject]@{ name = [pscustomobject]@{ configured = $true }; email = [pscustomobject]@{ configured = $true } }
                        defaultBranch = [pscustomobject]@{ configured = $true; value = 'main' }
                        autocrlf = [pscustomobject]@{ configured = $true; value = 'true' }
                        credentialHelper = [pscustomobject]@{ configured = $true; types = @('manager-core'); rawCommand = $SecretLookingRawValue }
                    }
                    githubCli = [pscustomobject]@{
                        version = 'gh version 2.101.0 (2026-09-15)'
                        authentication = [pscustomobject]@{ authenticated = $true; checked = $true; rawOutput = $SecretLookingRawValue }
                    }
                }
                python = [pscustomobject]@{
                    selected = [pscustomobject]@{ path = 'C:\Program Files\Python314\python.exe'; version = '3.14.7' }
                    runtimes = @([pscustomobject]@{ path = 'C:\Program Files\Python314\python.exe'; version = '3.14.7' })
                    pyLauncher = [pscustomobject]@{ available = $true }
                    uv = [pscustomobject]@{ available = $true; version = '0.12.15' }
                    virtualEnvironment = [pscustomobject]@{ active = $false }
                    pip = [pscustomobject]@{ available = $true }
                }
                node = [pscustomobject]@{
                    node = [pscustomobject]@{ selected = [pscustomobject]@{ path = 'C:\Program Files\nodejs\node.exe'; version = '24.19.0' } }
                    npm = [pscustomobject]@{ runnable = $true; version = '11.17.0'; launcherVariants = @([pscustomobject]@{ name = 'npm.cmd' }); globalCommandPath = 'C:\Users\Test\AppData\Roaming\npm'; globalPathExists = $false }
                }
                virtualization = [pscustomobject]@{
                    firmwareVirtualization = 'Enabled'
                    readiness = [pscustomobject]@{ hypervisorState = 'Present'; wslInstalled = 'Installed'; wslFeatureState = 'Enabled'; virtualMachinePlatformState = 'Enabled'; wsl2Ready = 'Ready' }
                    wsl = [pscustomobject]@{ distributions = @([pscustomobject]@{ name = 'Ubuntu'; version = 2 }) }
                }
            }
        }
    }
}

Describe 'Inventory Markdown report' {
    It 'renders the expected title and machine metadata' {
        InModuleScope DevRigInspector {
            $inventory = New-MarkdownTestInventory
            $markdown = ConvertTo-InventoryMarkdown -Inventory $inventory
            $markdown | Should Match '# Dev Rig Inspector Report'
            $markdown | Should Match 'MD-TEST-HOST'
            $markdown | Should Match 'Windows 11 Pro, build 26200'
            $markdown | Should Match '0\.4\.0'
        }
    }

    It 'reports accurate warning, error, and informational counts' {
        InModuleScope DevRigInspector {
            $inventory = New-MarkdownTestInventory
            $markdown = ConvertTo-InventoryMarkdown -Inventory $inventory
            $markdown | Should Match '- Errors: 0'
            $markdown | Should Match '- Warnings: 1'
            $markdown | Should Match '- Informational findings: 1'
        }
    }

    It 'renders warning content in the Attention Required section' {
        InModuleScope DevRigInspector {
            $inventory = New-MarkdownTestInventory
            $markdown = ConvertTo-InventoryMarkdown -Inventory $inventory
            $markdown | Should Match '## Attention Required'
            $markdown | Should Match 'Warning: PATH entry does not exist'
            $markdown | Should Match 'Remove or correct the stale entry'
        }
    }

    It 'renders the development tools table' {
        InModuleScope DevRigInspector {
            $inventory = New-MarkdownTestInventory
            $markdown = ConvertTo-InventoryMarkdown -Inventory $inventory
            $markdown | Should Match '\| Tool \| Version \| Status \|'
            $markdown | Should Match '\| Git \|'
        }
    }

    It 'escapes a pipe character embedded in a tool version so the table row is not broken' {
        InModuleScope DevRigInspector {
            $inventory = New-MarkdownTestInventory
            $markdown = ConvertTo-InventoryMarkdown -Inventory $inventory
            $tableLine = ($markdown -split "`r?`n") | Where-Object { $_ -like '*PipeTool*' }
            $tableLine | Should Not BeNullOrEmpty
            # An unescaped pipe would split the row into an extra column; the literal pipe must be backslash-escaped.
            $tableLine | Should Not Match '(?<!\\)\|beta'
            $markdown | Should Match '1\.0\\\|beta'
        }
    }

    It 'renders health section headings' {
        InModuleScope DevRigInspector {
            $inventory = New-MarkdownTestInventory
            $markdown = ConvertTo-InventoryMarkdown -Inventory $inventory
            $markdown | Should Match '## PowerShell'
            $markdown | Should Match '## Git / GitHub'
            $markdown | Should Match '## Python'
            $markdown | Should Match '## Node / npm'
            $markdown | Should Match '## WSL / Virtualization'
            $markdown | Should Match '## Informational Findings'
        }
    }

    It 'does not leak secret-looking raw evidence fields that the renderer never reads' {
        InModuleScope DevRigInspector {
            $secret = 'ghp_FAKESECRETTOKEN1234567890'
            $inventory = New-MarkdownTestInventory -SecretLookingRawValue $secret
            $markdown = ConvertTo-InventoryMarkdown -Inventory $inventory
            $markdown | Should Not Match ([regex]::Escape($secret))
        }
    }

    It 'does not contain raw probe/command execution output fields' {
        InModuleScope DevRigInspector {
            $inventory = New-MarkdownTestInventory
            $markdown = ConvertTo-InventoryMarkdown -Inventory $inventory
            $markdown | Should Not Match 'standardOutput'
            $markdown | Should Not Match 'standardError'
            $markdown | Should Not Match 'exitCode'
        }
    }
}

function global:New-MarkdownComparisonTestInventory {
    param(
        [string] $Hostname = 'MD-COMPARE-HOST',
        [object[]] $Tools = @(),
        [object[]] $Findings = @(),
        [object] $Health
    )
    [pscustomobject]@{
        schemaVersion = '0.1'
        collectorVersion = '0.4.0'
        collectedAt = [DateTime]::UtcNow.ToString('o')
        computer = [pscustomobject]@{
            hostname = $Hostname
            cpu = [pscustomobject]@{ name = 'Test CPU' }
            physicalMemoryBytes = 34359738368
        }
        tools = @($Tools)
        diagnostics = [pscustomobject]@{
            collectorResults = @()
            findings = @($Findings)
            health = if ($Health) { $Health } else { [pscustomobject]@{} }
        }
    }
}

function global:New-MarkdownComparisonTestTool {
    param([string] $Id, [string] $DisplayName = $Id, [string] $Version = '1.0.0', [string] $Status = 'Available')
    [pscustomobject]@{ id = $Id; displayName = $DisplayName; status = $Status; version = $Version }
}

function global:New-MarkdownComparisonSnapshotFile {
    param([object] $Inventory)
    $path = Join-Path $env:TEMP ('dev-rig-md-fixture-' + [guid]::NewGuid() + '.json')
    ($Inventory | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $path -Encoding utf8
    $path
}

Describe 'Comparison Markdown report' {
    AfterEach {
        foreach ($path in @($script:tempFiles)) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
        $script:tempFiles = @()
    }

    It 'renders tool version changes, health changes, new findings, resolved findings, and severity changes, without listing unchanged fields' {
        $reference = New-MarkdownComparisonTestInventory -Tools @((New-MarkdownComparisonTestTool -Id 'git' -DisplayName 'Git' -Version '2.55.0'), (New-MarkdownComparisonTestTool -Id 'stable' -DisplayName 'StableTool' -Version '1.0.0')) -Findings @(
            (New-MarkdownTestFinding -Code 'OldFinding' -Severity 'Warning' -AffectedComponent 'PATH' -Title 'Old finding' -Message 'Old finding message.')
            (New-MarkdownTestFinding -Code 'InfoOne' -Severity 'Info' -AffectedComponent 'Python' -Title 'Info that resolves without change' -Message 'Resolution info message.')
        ) -Health ([pscustomobject]@{
            powerShell = [pscustomobject]@{}
            git = [pscustomobject]@{}
            python = [pscustomobject]@{ selected = [pscustomobject]@{ path = 'C:\Program Files\Python314\python.exe'; version = '3.14.7' } }
            node = [pscustomobject]@{}
            virtualization = [pscustomobject]@{}
        })
        $current = New-MarkdownComparisonTestInventory -Tools @((New-MarkdownComparisonTestTool -Id 'git' -DisplayName 'Git' -Version '2.56.1'), (New-MarkdownComparisonTestTool -Id 'stable' -DisplayName 'StableTool' -Version '1.0.0')) -Findings @(
            (New-MarkdownTestFinding -Code 'NewFinding' -Severity 'Warning' -AffectedComponent 'Python' -Title 'Python alias now wins resolution' -Message 'A different Python interpreter now wins command resolution.')
            (New-MarkdownTestFinding -Code 'InfoOne' -Severity 'Info' -AffectedComponent 'Python' -Title 'Info that resolves without change' -Message 'Resolution info message.')
        ) -Health ([pscustomobject]@{
            powerShell = [pscustomobject]@{}
            git = [pscustomobject]@{}
            python = [pscustomobject]@{ selected = [pscustomobject]@{ path = 'C:\Users\Test\AppData\Local\Microsoft\WindowsApps\python.exe'; version = '3.14.7' } }
            node = [pscustomobject]@{}
            virtualization = [pscustomobject]@{}
        })

        $reportPath = Join-Path $env:TEMP ('dev-rig-md-comparison-' + [guid]::NewGuid() + '.md')
        $script:tempFiles = @($reportPath)

        Compare-DevRigInspection -Reference $reference -Current $current -ReportPath $reportPath 6>$null | Out-Null
        $markdown = Get-Content -LiteralPath $reportPath -Raw

        $markdown | Should Match '# Dev Rig Inspector Comparison'
        $markdown | Should Match '## Tool Changes'
        $markdown | Should Match '### Git'
        $markdown | Should Match '2\.55\.0.*→.*2\.56\.1'
        $markdown | Should Match '## Health Changes'
        $markdown | Should Match 'Selected interpreter'
        $markdown | Should Match '## New Attention'
        $markdown | Should Match 'Python alias now wins resolution'
        $markdown | Should Match '## Resolved'
        $markdown | Should Match 'Old finding'
        $markdown | Should Not Match 'StableTool'
        $markdown | Should Not Match 'Info that resolves without change'
    }

    It 'renders in-memory and file source labels appropriately' {
        $reference = New-MarkdownComparisonTestInventory -Tools @((New-MarkdownComparisonTestTool -Id 'git' -Version '2.55.0'))
        $current = New-MarkdownComparisonTestInventory -Tools @((New-MarkdownComparisonTestTool -Id 'git' -Version '2.56.1'))
        $refPath = New-MarkdownComparisonSnapshotFile -Inventory $reference
        $reportPath = Join-Path $env:TEMP ('dev-rig-md-comparison-' + [guid]::NewGuid() + '.md')
        $script:tempFiles = @($refPath, $reportPath)

        Compare-DevRigInspection -ReferencePath $refPath -Current $current -ReportPath $reportPath 6>$null | Out-Null
        $markdown = Get-Content -LiteralPath $reportPath -Raw

        $markdown | Should Match ([regex]::Escape((Split-Path -Leaf $refPath)))
        $markdown | Should Match 'in-memory snapshot'
    }

    It 'rejects -JsonOnly combined with -ReportPath' {
        $reference = New-MarkdownComparisonTestInventory -Tools @((New-MarkdownComparisonTestTool -Id 'git' -Version '2.55.0'))
        $current = New-MarkdownComparisonTestInventory -Tools @((New-MarkdownComparisonTestTool -Id 'git' -Version '2.56.1'))
        $reportPath = Join-Path $env:TEMP ('dev-rig-md-comparison-' + [guid]::NewGuid() + '.md')
        $script:tempFiles = @($reportPath)

        $threw = $false
        try { Compare-DevRigInspection -Reference $reference -Current $current -JsonOnly -ReportPath $reportPath 6>$null } catch { $threw = $true }
        $threw | Should Be $true
        Test-Path $reportPath | Should Be $false
    }

    It 'returns the comparison object with -ReportPath and -PassThru' {
        $reference = New-MarkdownComparisonTestInventory -Tools @((New-MarkdownComparisonTestTool -Id 'git' -Version '2.55.0'))
        $current = New-MarkdownComparisonTestInventory -Tools @((New-MarkdownComparisonTestTool -Id 'git' -Version '2.56.1'))
        $reportPath = Join-Path $env:TEMP ('dev-rig-md-comparison-' + [guid]::NewGuid() + '.md')
        $script:tempFiles = @($reportPath)

        $result = Compare-DevRigInspection -Reference $reference -Current $current -ReportPath $reportPath -PassThru 6>$null
        $result.comparisonSchemaVersion | Should Be '0.1'
        Test-Path $reportPath | Should Be $true
    }
}

Describe 'Invoke-DevRigInspection Markdown CLI contract' {
    AfterEach {
        foreach ($path in @($script:tempFiles)) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
        $script:tempFiles = @()
    }

    It 'writes a Markdown report and returns nothing by default' {
        InModuleScope DevRigInspector {
            Mock Get-SystemInventory { New-CollectorResult -CollectorId 'System' -Status Available -Data ([pscustomobject]@{ hostname = 'MOCK-HOST'; windows = [pscustomobject]@{ productName = 'Windows 11 Pro'; buildNumber = '26200' }; cpu = [pscustomobject]@{ name = 'Mock CPU' }; logicalVolumes = @(); physicalMemoryBytes = 34359738368 }) }
            Mock Get-DevelopmentToolInventory { New-CollectorResult -CollectorId 'DevelopmentTools' -Status Available -Data @([pscustomobject]@{ id = 'git'; displayName = 'Git'; status = 'Available'; version = '2.55.0' }) }
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

            $reportPath = Join-Path $env:TEMP ('dev-rig-md-inventory-' + [guid]::NewGuid() + '.md')
            try {
                $result = Invoke-DevRigInspection -ReportPath $reportPath 6>$null
                $result | Should Be $null
                Test-Path $reportPath | Should Be $true
                (Get-Content -LiteralPath $reportPath -Raw) | Should Match '# Dev Rig Inspector Report'
            } finally {
                Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'writes a Markdown report and returns the inventory object with -PassThru' {
        InModuleScope DevRigInspector {
            Mock Get-SystemInventory { New-CollectorResult -CollectorId 'System' -Status Available -Data ([pscustomobject]@{ hostname = 'MOCK-HOST'; windows = [pscustomobject]@{}; cpu = [pscustomobject]@{}; logicalVolumes = @(); physicalMemoryBytes = 0 }) }
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

            $reportPath = Join-Path $env:TEMP ('dev-rig-md-inventory-' + [guid]::NewGuid() + '.md')
            try {
                $result = Invoke-DevRigInspection -ReportPath $reportPath -PassThru 6>$null
                $result.schemaVersion | Should Be '0.2'
                Test-Path $reportPath | Should Be $true
            } finally {
                Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'writes both JSON and Markdown when -OutputPath and -ReportPath are both supplied' {
        InModuleScope DevRigInspector {
            Mock Get-SystemInventory { New-CollectorResult -CollectorId 'System' -Status Available -Data ([pscustomobject]@{ hostname = 'MOCK-HOST'; windows = [pscustomobject]@{}; cpu = [pscustomobject]@{}; logicalVolumes = @(); physicalMemoryBytes = 0 }) }
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

            $jsonPath = Join-Path $env:TEMP ('dev-rig-json-' + [guid]::NewGuid() + '.json')
            $reportPath = Join-Path $env:TEMP ('dev-rig-md-inventory-' + [guid]::NewGuid() + '.md')
            try {
                Invoke-DevRigInspection -OutputPath $jsonPath -ReportPath $reportPath 6>$null
                Test-Path $jsonPath | Should Be $true
                Test-Path $reportPath | Should Be $true
            } finally {
                Remove-Item -LiteralPath $jsonPath, $reportPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'rejects -JsonOnly combined with -ReportPath' {
        InModuleScope DevRigInspector {
            $reportPath = Join-Path $env:TEMP ('dev-rig-md-inventory-' + [guid]::NewGuid() + '.md')
            $threw = $false
            try { Invoke-DevRigInspection -JsonOnly -ReportPath $reportPath 6>$null } catch { $threw = $true }
            $threw | Should Be $true
            Test-Path $reportPath | Should Be $false
        }
    }
}
