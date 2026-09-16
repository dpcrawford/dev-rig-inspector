function Assert-InventoryContract {
    param(
        [object] $Inventory,
        [Parameter(Mandatory)] [string] $Label
    )

    $supportedSchemaVersions = @('0.1')

    if ($null -eq $Inventory) {
        throw "The $Label inventory object was null."
    }

    if (-not $Inventory.PSObject.Properties['schemaVersion'] -or [string]::IsNullOrWhiteSpace([string] $Inventory.schemaVersion)) {
        throw "The $Label inventory does not contain a recognizable schemaVersion."
    }

    if ($supportedSchemaVersions -notcontains [string] $Inventory.schemaVersion) {
        throw "The $Label inventory has an unsupported schemaVersion '$($Inventory.schemaVersion)'."
    }

    if (-not $Inventory.PSObject.Properties['tools'] -or -not $Inventory.PSObject.Properties['diagnostics']) {
        throw "The $Label inventory does not match the expected Dev Rig Inspector structure."
    }
}

function ConvertTo-ValidatedInventorySnapshot {
    param(
        [object] $Inventory,
        [Parameter(Mandatory)] [string] $Label,
        # $null when the snapshot did not come from a file.
        $Path,
        [ValidateSet('File', 'Object')] [string] $SourceType = 'Object'
    )

    Assert-InventoryContract -Inventory $Inventory -Label $Label
    ConvertTo-ComparableInventory -Inventory $Inventory -Path $Path -SourceType $SourceType
}

function Read-InventorySnapshot {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Label
    )

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

    ConvertTo-ValidatedInventorySnapshot -Inventory $inventory -Label $Label -Path $Path -SourceType 'File'
}
