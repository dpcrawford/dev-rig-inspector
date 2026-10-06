function Assert-InventoryContract {
    param(
        [object] $Inventory,
        [Parameter(Mandatory)] [string] $Label
    )

    # 0.1 = historical (v0.3/v0.4) shape including now-removed raw tool-probe fields; 0.2 = current curated tools[] contract.
    $supportedSchemaVersions = @('0.1', '0.2')

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

    if ($Inventory.tools -isnot [System.Array]) {
        throw "The $Label inventory tools must be an array."
    }
    foreach ($tool in $Inventory.tools) {
        if ($null -eq $tool -or $tool -isnot [pscustomobject]) {
            throw "The $Label inventory contains a malformed tool."
        }
        foreach ($field in @('id', 'displayName', 'status', 'version')) {
            if (-not $tool.PSObject.Properties[$field]) {
                throw "The $Label inventory tool is missing '$field'."
            }
        }
    }
    if ($Inventory.diagnostics -isnot [pscustomobject] -or
        -not $Inventory.diagnostics.PSObject.Properties['findings'] -or
        $Inventory.diagnostics.findings -isnot [System.Array]) {
        throw "The $Label inventory diagnostics must be an object with a findings array."
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
