$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

function global:New-TestInventoryJson {
    param(
        [string] $Hostname = 'TEST-HOST',
        [string] $CpuName = 'Test CPU',
        [long] $PhysicalMemoryBytes = 34359738368,
        [object[]] $Tools = @(),
        [object[]] $Findings = @()
    )

    [pscustomobject]@{
        schemaVersion = '0.1'
        collectorVersion = '0.4.0'
        collectedAt = [DateTime]::UtcNow.ToString('o')
        computer = [pscustomobject]@{
            hostname = $Hostname
            cpu = [pscustomobject]@{ name = $CpuName }
            physicalMemoryBytes = $PhysicalMemoryBytes
        }
        tools = @($Tools)
        diagnostics = [pscustomobject]@{
            collectorResults = @()
            findings = @($Findings)
            health = [pscustomobject]@{}
        }
    } | ConvertTo-Json -Depth 12
}

function global:New-TestTool {
    param([string] $Id, [string] $DisplayName, [string] $Status = 'Available', [string] $Version = '1.0.0')
    [pscustomobject]@{ id = $Id; displayName = $DisplayName; status = $Status; version = $Version }
}

function global:New-TestFinding {
    param(
        [string] $Code,
        [string] $Severity = 'Warning',
        [string] $Category = 'Path',
        [string] $AffectedComponent = 'PATH',
        [string] $NormalizedPath,
        [string] $Title = 'Finding',
        [string] $Message = 'A finding occurred.'
    )
    $evidence = if ($NormalizedPath) { @([pscustomobject]@{ raw = $NormalizedPath; expanded = $NormalizedPath; normalized = $NormalizedPath }) } else { @() }
    [pscustomobject]@{
        code = $Code
        severity = $Severity
        category = $Category
        affectedComponent = $AffectedComponent
        title = $Title
        message = $Message
        evidence = $evidence
        recommendation = 'No action required.'
    }
}

function global:New-TestSnapshotFile {
    param([string] $Json)
    $path = Join-Path $env:TEMP ('dev-rig-comparison-' + [guid]::NewGuid() + '.json')
    Set-Content -LiteralPath $path -Value $Json -Encoding utf8
    $path
}

Describe 'Get-FindingIdentity' {
    It 'keeps two same-code findings with different normalized targets distinct' {
        InModuleScope DevRigInspector {
            $first = New-TestFinding -Code 'PathEntryMissing' -NormalizedPath 'C:\Example\Missing'
            $second = New-TestFinding -Code 'PathEntryMissing' -NormalizedPath 'C:\Old\Missing'
            (Get-FindingIdentity -Finding $first) | Should Not Be (Get-FindingIdentity -Finding $second)
        }
    }

    It 'produces the same identity for identical evidence regardless of message text' {
        InModuleScope DevRigInspector {
            $a = New-TestFinding -Code 'PathEntryMissing' -NormalizedPath 'C:\Same\Path' -Message 'first wording'
            $b = New-TestFinding -Code 'PathEntryMissing' -NormalizedPath 'C:\Same\Path' -Message 'completely different wording'
            (Get-FindingIdentity -Finding $a) | Should Be (Get-FindingIdentity -Finding $b)
        }
    }

    It 'falls back to code plus affectedComponent when no discriminator rule applies' {
        InModuleScope DevRigInspector {
            $finding = New-TestFinding -Code 'GitIdentityMissing' -AffectedComponent 'Git.Identity'
            (Get-FindingIdentity -Finding $finding) | Should Be 'gitidentitymissing|git.identity'
        }
    }
}

Describe 'Compare-DevRigInspection' {
    AfterEach {
        Remove-Item -LiteralPath $script:refPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $script:curPath -Force -ErrorAction SilentlyContinue
    }

    It 'reports no changes for identical snapshots' {
        $json = New-TestInventoryJson -Tools @((New-TestTool -Id 'git' -DisplayName 'Git' -Version '2.55.0'))
        $script:refPath = New-TestSnapshotFile -Json $json
        $script:curPath = New-TestSnapshotFile -Json $json

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $result.summary.totalChanges | Should Be 0
    }

    It 'detects a tool version change' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Tools @((New-TestTool -Id 'git' -DisplayName 'Git' -Version '2.55.0')))
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Tools @((New-TestTool -Id 'git' -DisplayName 'Git' -Version '2.56.1')))

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $change = $result.changes.tools | Where-Object id -eq 'git'
        $change.kind | Should Be 'Changed'
        $change.fields.field | Should Be 'version'
        $change.fields.before | Should Be '2.55.0'
        $change.fields.after | Should Be '2.56.1'
    }

    It 'detects a tool status change' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Tools @((New-TestTool -Id 'uv' -DisplayName 'uv' -Status 'Available')))
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Tools @((New-TestTool -Id 'uv' -DisplayName 'uv' -Status 'Missing')))

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $change = $result.changes.tools | Where-Object id -eq 'uv'
        $change.fields.field | Should Be 'status'
    }

    It 'detects a tool being added' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Tools @())
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Tools @((New-TestTool -Id 'uv' -DisplayName 'uv' -Version '0.13.0')))

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $result.changes.tools[0].kind | Should Be 'Added'
        $result.summary.toolsAdded | Should Be 1
    }

    It 'detects a tool being removed' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Tools @((New-TestTool -Id 'uv' -DisplayName 'uv')))
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Tools @())

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $result.changes.tools[0].kind | Should Be 'Removed'
        $result.summary.toolsRemoved | Should Be 1
    }

    It 'detects a new finding appearing' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Findings @())
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Findings @((New-TestFinding -Code 'PathEntryMissing' -NormalizedPath 'C:\Example\Missing')))

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $result.changes.findings[0].kind | Should Be 'NewFinding'
        $result.summary.newFindings | Should Be 1
    }

    It 'detects a finding resolving' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Findings @((New-TestFinding -Code 'PathEntryMissing' -NormalizedPath 'C:\Old\Missing')))
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Findings @())

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $result.changes.findings[0].kind | Should Be 'ResolvedFinding'
        $result.summary.resolvedFindings | Should Be 1
    }

    It 'detects a finding severity change without treating it as resolved plus new' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Findings @((New-TestFinding -Code 'PythonAliasWinsResolution' -Severity 'Info' -AffectedComponent 'Python')))
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Findings @((New-TestFinding -Code 'PythonAliasWinsResolution' -Severity 'Warning' -AffectedComponent 'Python')))

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $result.changes.findings.Count | Should Be 1
        $result.changes.findings[0].kind | Should Be 'SeverityChanged'
        $result.changes.findings[0].severityBefore | Should Be 'Info'
        $result.changes.findings[0].severityAfter | Should Be 'Warning'
        $result.summary.newFindings | Should Be 0
        $result.summary.resolvedFindings | Should Be 0
    }

    It 'keeps two same-code PATH findings with different normalized targets distinct across snapshots' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Findings @((New-TestFinding -Code 'PathEntryMissing' -NormalizedPath 'C:\First\Missing')))
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Findings @(
            (New-TestFinding -Code 'PathEntryMissing' -NormalizedPath 'C:\First\Missing'),
            (New-TestFinding -Code 'PathEntryMissing' -NormalizedPath 'C:\Second\Missing')
        ))

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $result.changes.findings.Count | Should Be 1
        $result.changes.findings[0].kind | Should Be 'NewFinding'
    }

    It 'reports a likely-same machine when hostname matches' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Hostname 'SAME-HOST')
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Hostname 'SAME-HOST')

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $result.machineIdentity.state | Should Be 'LikelySame'
    }

    It 'reports a different machine when hostname and hardware evidence differ' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Hostname 'HOST-A' -CpuName 'CPU A' -PhysicalMemoryBytes 8589934592)
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Hostname 'HOST-B' -CpuName 'CPU B' -PhysicalMemoryBytes 68719476736)

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $result.machineIdentity.state | Should Be 'Different'
    }

    It 'never suppresses detected changes even when machine identity differs' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Hostname 'HOST-A' -CpuName 'CPU A' -PhysicalMemoryBytes 8589934592 -Tools @((New-TestTool -Id 'git' -Version '2.55.0')))
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson -Hostname 'HOST-B' -CpuName 'CPU B' -PhysicalMemoryBytes 68719476736 -Tools @((New-TestTool -Id 'git' -Version '2.56.1')))

        $result = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru 6>$null
        $result.machineIdentity.state | Should Be 'Different'
        $result.summary.toolsChanged | Should Be 1
    }

    It 'throws a clear error for a missing reference file' {
        $script:refPath = Join-Path $env:TEMP ('does-not-exist-' + [guid]::NewGuid() + '.json')
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson)
        $threw = $false
        try { Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath 6>$null } catch { $threw = $true }
        $threw | Should Be $true
    }

    It 'throws a clear error for malformed JSON' {
        $script:refPath = New-TestSnapshotFile -Json '{ this is not valid json'
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson)
        $threw = $false
        try { Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath 6>$null } catch { $threw = $true }
        $threw | Should Be $true
    }

    It 'throws a clear error for an unsupported schema version' {
        $unsupported = (New-TestInventoryJson | ConvertFrom-Json)
        $unsupported.schemaVersion = '9.9'
        $script:refPath = New-TestSnapshotFile -Json ($unsupported | ConvertTo-Json -Depth 12)
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson)
        $threw = $false
        try { Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath 6>$null } catch { $threw = $true }
        $threw | Should Be $true
    }

    It 'returns JSON only with -JsonOnly and no console text object' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson)
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson)
        $json = Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -JsonOnly
        $json.GetType().Name | Should Be 'String'
        $parsed = $json | ConvertFrom-Json
        $parsed.comparisonSchemaVersion | Should Be '0.1'
        $parsed.comparisonVersion | Should Be '0.5.0'
    }

    It 'rejects conflicting PassThru and JsonOnly modes' {
        $script:refPath = New-TestSnapshotFile -Json (New-TestInventoryJson)
        $script:curPath = New-TestSnapshotFile -Json (New-TestInventoryJson)
        $threw = $false
        try { Compare-DevRigInspection -ReferencePath $script:refPath -CurrentPath $script:curPath -PassThru -JsonOnly | Out-Null } catch { $threw = $true }
        $threw | Should Be $true
    }
}
