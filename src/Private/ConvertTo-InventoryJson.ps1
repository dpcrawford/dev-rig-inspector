function ConvertTo-InventoryJson {
    param([Parameter(Mandatory)] [object] $Inventory)

    $Inventory | ConvertTo-Json -Depth 12
}