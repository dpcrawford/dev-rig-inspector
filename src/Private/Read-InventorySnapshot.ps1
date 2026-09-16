function Read-InventorySnapshot {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Label
    )

    $supportedSchemaVersions = @('0.1')

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "The $Label inventory file was not found: $Path"
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    } catch {
        throw "The $Label inventory file could not be read: $Path"
    }

    try {
        $inventory = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "The $Label inventory file does not contain valid JSON: $Path"
    }

    if (-not $inventory.PSObject.Properties['schemaVersion'] -or [string]::IsNullOrWhiteSpace([string] $inventory.schemaVersion)) {
        throw "The $Label inventory file does not contain a recognizable schemaVersion: $Path"
    }

    if ($supportedSchemaVersions -notcontains [string] $inventory.schemaVersion) {
        throw "The $Label inventory file has an unsupported schemaVersion '$($inventory.schemaVersion)': $Path"
    }

    if (-not $inventory.PSObject.Properties['tools'] -or -not $inventory.PSObject.Properties['diagnostics']) {
        throw "The $Label inventory file does not match the expected Dev Rig Inspector structure: $Path"
    }

    ConvertTo-ComparableInventory -Inventory $inventory -Path $Path
}
