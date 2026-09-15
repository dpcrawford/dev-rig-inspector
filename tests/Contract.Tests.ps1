$modulePath = Join-Path $PSScriptRoot '..\src\DevRigInspector.psd1'
Import-Module $modulePath -Force

Describe 'Inspection contract' {
    It 'produces a versioned JSON document with all configured tools' {
        $json = Invoke-DevRigInspection -JsonOnly
        $inventory = $json | ConvertFrom-Json
        $inventory.schemaVersion | Should Be '0.1'
        $inventory.collectorVersion | Should Be '0.2.0'
        $inventory.tools.Count | Should Be 9
        $inventory.diagnostics.collectorResults.Count | Should Be 2
    }
}