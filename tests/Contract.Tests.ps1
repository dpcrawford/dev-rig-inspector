$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

Describe 'Inspection contract' {
    It 'produces a versioned JSON document with all configured tools' {
        $json = Invoke-DevRigInspection -JsonOnly
        $inventory = $json | ConvertFrom-Json
        $inventory.schemaVersion | Should Be '0.1'
        $inventory.collectorVersion | Should Be '0.2.1'
        $inventory.tools.Count | Should Be 9
        $inventory.diagnostics.collectorResults.Count | Should Be 2
    }

    It 'returns no object from the default human-readable mode' {
        $result = Invoke-DevRigInspection
        $result | Should Be $null
    }

    It 'returns the inventory object only with PassThru' {
        $result = Invoke-DevRigInspection -PassThru
        $result.schemaVersion | Should Be '0.1'
        $result.collectorVersion | Should Be '0.2.1'
    }

    It 'writes JSON to OutputPath without returning the inventory object' {
        $outputPath = Join-Path $env:TEMP ('dev-rig-inspector-' + [guid]::NewGuid() + '.json')
        try {
            $result = Invoke-DevRigInspection -OutputPath $outputPath
            $result | Should Be $null
            $inventory = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
            $inventory.collectorVersion | Should Be '0.2.1'
        } finally {
            Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects conflicting PassThru and JsonOnly modes' {
        $threw = $false
        try {
            Invoke-DevRigInspection -PassThru -JsonOnly | Out-Null
        } catch {
            $threw = $true
        }
        $threw | Should Be $true
    }
}