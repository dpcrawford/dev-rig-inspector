$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

function global:New-Slice3TestInventory {
    param(
        [string] $Hostname = 'TEST-HOST',
        [string] $CpuName = 'Test CPU',
        [long] $PhysicalMemoryBytes = 34359738368,
        [object[]] $Tools = @(),
        [object[]] $Findings = @(),
        [string] $SchemaVersion = '0.1'
    )

    [pscustomobject]@{
        schemaVersion = $SchemaVersion
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
    }
}

function global:New-Slice3TestTool {
    param([string] $Id, [string] $DisplayName, [string] $Status = 'Available', [string] $Version = '1.0.0')
    [pscustomobject]@{ id = $Id; displayName = $DisplayName; status = $Status; version = $Version }
}

function global:New-Slice3SnapshotFile {
    param([object] $Inventory)
    $path = Join-Path $env:TEMP ('dev-rig-slice3-' + [guid]::NewGuid() + '.json')
    ($Inventory | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $path -Encoding utf8
    $path
}

Describe 'In-memory snapshot comparison (Slice 3)' {
    AfterEach {
        foreach ($path in @($script:tempFiles)) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
        $script:tempFiles = @()
    }

    Context 'Input combinations' {
        It 'compares path + path' {
            $reference = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.55.0'))
            $current = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.56.1'))
            $refPath = New-Slice3SnapshotFile -Inventory $reference
            $curPath = New-Slice3SnapshotFile -Inventory $current
            $script:tempFiles = @($refPath, $curPath)

            $result = Compare-DevRigInspection -ReferencePath $refPath -CurrentPath $curPath -PassThru 6>$null
            $result.changes.tools[0].fields.field | Should Be 'version'
        }

        It 'compares object + object' {
            $reference = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.55.0'))
            $current = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.56.1'))

            $result = Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null
            $result.changes.tools[0].fields.field | Should Be 'version'
        }

        It 'compares path + object' {
            $reference = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.55.0'))
            $current = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.56.1'))
            $refPath = New-Slice3SnapshotFile -Inventory $reference
            $script:tempFiles = @($refPath)

            $result = Compare-DevRigInspection -ReferencePath $refPath -Current $current -PassThru 6>$null
            $result.changes.tools[0].fields.field | Should Be 'version'
        }

        It 'compares object + path' {
            $reference = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.55.0'))
            $current = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.56.1'))
            $curPath = New-Slice3SnapshotFile -Inventory $current
            $script:tempFiles = @($curPath)

            $result = Compare-DevRigInspection -Reference $reference -CurrentPath $curPath -PassThru 6>$null
            $result.changes.tools[0].fields.field | Should Be 'version'
        }
    }

    Context 'Equivalence across input combinations' {
        It 'produces semantically identical changes and summary regardless of how snapshots were supplied' {
            $reference = New-Slice3TestInventory -Hostname 'EQUIV-HOST' -Tools @((New-Slice3TestTool -Id 'git' -Version '2.55.0'))
            $current = New-Slice3TestInventory -Hostname 'EQUIV-HOST' -Tools @((New-Slice3TestTool -Id 'git' -Version '2.56.1'))
            $refPath = New-Slice3SnapshotFile -Inventory $reference
            $curPath = New-Slice3SnapshotFile -Inventory $current
            $script:tempFiles = @($refPath, $curPath)

            $pathPath = Compare-DevRigInspection -ReferencePath $refPath -CurrentPath $curPath -PassThru 6>$null
            $objectObject = Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null
            $pathObject = Compare-DevRigInspection -ReferencePath $refPath -Current $current -PassThru 6>$null
            $objectPath = Compare-DevRigInspection -Reference $reference -CurrentPath $curPath -PassThru 6>$null

            $expectedChanges = $pathPath.changes | ConvertTo-Json -Depth 12
            $expectedSummary = $pathPath.summary | ConvertTo-Json -Depth 12

            foreach ($result in @($objectObject, $pathObject, $objectPath)) {
                ($result.changes | ConvertTo-Json -Depth 12) | Should Be $expectedChanges
                ($result.summary | ConvertTo-Json -Depth 12) | Should Be $expectedSummary
                $result.machineIdentity.state | Should Be $pathPath.machineIdentity.state
            }
        }
    }

    Context 'Source metadata' {
        It 'reports sourceType File and the actual path for file-backed snapshots' {
            $reference = New-Slice3TestInventory
            $refPath = New-Slice3SnapshotFile -Inventory $reference
            $curPath = New-Slice3SnapshotFile -Inventory $reference
            $script:tempFiles = @($refPath, $curPath)

            $result = Compare-DevRigInspection -ReferencePath $refPath -CurrentPath $curPath -PassThru 6>$null
            $result.reference.sourceType | Should Be 'File'
            $result.reference.path | Should Be $refPath
        }

        It 'reports sourceType Object and a null path for object-backed snapshots' {
            $reference = New-Slice3TestInventory
            $current = New-Slice3TestInventory

            $result = Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null
            $result.reference.sourceType | Should Be 'Object'
            $result.reference.path | Should Be $null
            $result.current.sourceType | Should Be 'Object'
            $result.current.path | Should Be $null
        }

        It 'reports mixed sourceType values for a path reference and an object current' {
            $reference = New-Slice3TestInventory
            $current = New-Slice3TestInventory
            $refPath = New-Slice3SnapshotFile -Inventory $reference
            $script:tempFiles = @($refPath)

            $result = Compare-DevRigInspection -ReferencePath $refPath -Current $current -PassThru 6>$null
            $result.reference.sourceType | Should Be 'File'
            $result.reference.path | Should Be $refPath
            $result.current.sourceType | Should Be 'Object'
            $result.current.path | Should Be $null
        }
    }

    Context 'Validation' {
        It 'rejects a null reference object' {
            $current = New-Slice3TestInventory
            $threw = $false
            try { Compare-DevRigInspection -Reference $null -Current $current 6>$null } catch { $threw = $true }
            $threw | Should Be $true
        }

        It 'rejects a null current object' {
            $reference = New-Slice3TestInventory
            $threw = $false
            try { Compare-DevRigInspection -Reference $reference -Current $null 6>$null } catch { $threw = $true }
            $threw | Should Be $true
        }

        It 'rejects a reference object missing schemaVersion' {
            $reference = New-Slice3TestInventory
            $reference.PSObject.Properties.Remove('schemaVersion')
            $current = New-Slice3TestInventory
            $threw = $false
            try { Compare-DevRigInspection -Reference $reference -Current $current 6>$null } catch { $threw = $true }
            $threw | Should Be $true
        }

        It 'rejects a current object with an unsupported schema version' {
            $reference = New-Slice3TestInventory
            $current = New-Slice3TestInventory -SchemaVersion '9.9'
            $threw = $false
            try { Compare-DevRigInspection -Reference $reference -Current $current 6>$null } catch { $threw = $true }
            $threw | Should Be $true
        }

        It 'rejects an object that does not match the expected inventory structure' {
            $reference = [pscustomobject]@{ schemaVersion = '0.1'; somethingElse = 'not an inventory' }
            $current = New-Slice3TestInventory
            $threw = $false
            try { Compare-DevRigInspection -Reference $reference -Current $current 6>$null } catch { $threw = $true }
            $threw | Should Be $true
        }
    }

    Context 'Safety' {
        It 'does not mutate the caller-supplied reference or current objects' {
            $reference = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.55.0'))
            $current = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.56.1'))
            $referenceBefore = $reference | ConvertTo-Json -Depth 12
            $currentBefore = $current | ConvertTo-Json -Depth 12

            Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null | Out-Null

            ($reference | ConvertTo-Json -Depth 12) | Should Be $referenceBefore
            ($current | ConvertTo-Json -Depth 12) | Should Be $currentBefore
        }

        It 'does not retain references that allow later mutation of caller data to alter an already-produced result' {
            $reference = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.55.0'))
            $current = New-Slice3TestInventory -Tools @((New-Slice3TestTool -Id 'git' -Version '2.55.0'))

            $result = Compare-DevRigInspection -Reference $reference -Current $current -PassThru 6>$null
            $result.summary.totalChanges | Should Be 0

            $current.tools[0].version = '9.9.9'

            $result.summary.totalChanges | Should Be 0
            @($result.changes.tools).Count | Should Be 0
        }
    }
}
